import 'dart:convert';

import '../database/app_database.dart';
import '../database_service.dart';

/// Service for managing application cache with TTL support.
///
/// Provides a generic caching mechanism that:
/// - Persists to Drift database for survival across app restarts
/// - Supports TTL (time-to-live) for automatic expiration
/// - Enables stale-while-revalidate pattern for instant loading
/// - Includes cleanup methods to prevent storage bloat
///
/// Example:
/// ```dart
/// final cacheService = CacheService.instance;
///
/// // Store data with TTL
/// await cacheService.set('profile_abc', profileJson, CacheConfig.profilesTtl);
///
/// // Get cached data
/// final cached = await cacheService.get<Map<String, dynamic>>('profile_abc');
///
/// // Check if needs refresh
/// if (await cacheService.isStale('profile_abc')) {
///   // Fetch fresh data in background
/// }
/// ```
class CacheService {
  CacheService._();

  static final CacheService _instance = CacheService._();

  /// Singleton instance of CacheService.
  static CacheService get instance => _instance;

  bool _isInitialized = false;

  /// In-memory cache for quick access (avoids database reads for hot data).
  final Map<String, _MemoryCacheEntry> _memoryCache = {};

  /// Maximum number of items to keep in memory cache.
  static const int _maxMemoryCacheSize = 100;

  /// Check if the cache service is initialized.
  bool get isInitialized => _isInitialized;

  /// Get the shared database instance from DatabaseService.
  AppDatabase get _db => DatabaseService.instance.db;

  /// Initialize the cache service.
  ///
  /// Uses the shared Drift database instance from DatabaseService.
  /// DatabaseService must be initialized before calling this method.
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized
    }

    _isInitialized = true;
  }

  /// Get a cached value by key.
  ///
  /// Returns the cached value if found and not expired (or [allowStale] is true),
  /// otherwise returns null.
  ///
  /// [key] - The cache key.
  /// [allowStale] - If true, returns stale data (for stale-while-revalidate pattern).
  /// [fromJson] - Optional converter for complex types.
  Future<T?> get<T>(
    String key, {
    bool allowStale = true,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    // Check memory cache first
    final memoryCached = _memoryCache[key];
    if (memoryCached != null) {
      if (!memoryCached.isExpired || allowStale) {
        return _deserialize<T>(memoryCached.data, fromJson);
      }
    }

    // Check Drift cache
    final entry = await _db.getCacheEntry(key);

    if (entry == null) {
      return null;
    }

    // Check if expired
    final isExpired = DateTime.now().millisecondsSinceEpoch > entry.expiresAt;
    if (isExpired && !allowStale) {
      return null;
    }

    // Update memory cache
    _addToMemoryCache(key, entry.data, entry.expiresAt);

    return _deserialize<T>(entry.data, fromJson);
  }

  /// Set a cached value with TTL.
  ///
  /// [key] - The cache key.
  /// [value] - The value to cache (must be JSON-serializable).
  /// [ttl] - Time-to-live duration.
  /// [toJson] - Optional converter for complex types.
  Future<void> set<T>(
    String key,
    T value,
    Duration ttl, {
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + ttl.inMilliseconds;
    final data = _serialize(value, toJson);

    // Update memory cache
    _addToMemoryCache(key, data, expiresAt);

    // Update Drift cache
    final entry = CacheEntryRow(
      key: key,
      data: data,
      cachedAt: now,
      expiresAt: expiresAt,
      dataType: T.toString(),
    );

    await _db.upsertCacheEntry(entry);
  }

  /// Check if a cache entry is stale (expired but still usable).
  ///
  /// Returns true if the entry exists and is expired.
  /// Returns false if the entry doesn't exist or is still fresh.
  Future<bool> isStale(String key) async {
    // Check memory cache first
    final memoryCached = _memoryCache[key];
    if (memoryCached != null) {
      return memoryCached.isExpired;
    }

    // Check Drift cache
    final entry = await _db.getCacheEntry(key);
    if (entry == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch > entry.expiresAt;
  }

  /// Check if a cache entry exists (regardless of freshness).
  Future<bool> exists(String key) async {
    if (_memoryCache.containsKey(key)) {
      return true;
    }

    final entry = await _db.getCacheEntry(key);
    return entry != null;
  }

  /// Remove a specific cache entry.
  Future<void> remove(String key) async {
    _memoryCache.remove(key);

    await _db.deleteCacheEntry(key);
  }

  /// Remove all cache entries matching a prefix.
  ///
  /// Useful for clearing all entries of a specific type.
  /// Example: clearByPrefix('profile_') clears all profile caches.
  Future<int> removeByPrefix(String prefix) async {
    // Clear from memory cache
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));

    // Clear from Drift
    final count = await _db.deleteCacheEntriesByPrefix(prefix) ?? 0;

    return count;
  }

  /// Clear all cached data.
  Future<void> clear() async {
    _memoryCache.clear();

    await _db.clearCache();
  }

  /// Clear cache entries older than the specified duration.
  ///
  /// Returns the number of entries cleared.
  /// Should be called on app startup to prevent storage bloat.
  Future<int> clearOlderThan(Duration duration) async {
    final cutoff = DateTime.now().subtract(duration).millisecondsSinceEpoch;

    // Clear from memory cache
    _memoryCache.removeWhere((_, entry) => entry.cachedAt < cutoff);

    // Clear from Drift
    final count = await _db.deleteCacheEntriesOlderThan(cutoff) ?? 0;

    return count;
  }

  /// Clear all expired cache entries.
  ///
  /// Returns the number of entries cleared.
  Future<int> clearExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Clear from memory cache
    _memoryCache.removeWhere((_, entry) => entry.expiresAt < now);

    // Clear from Drift
    final count = await _db.deleteExpiredCacheEntries() ?? 0;

    return count;
  }

  /// Get cache statistics for debugging.
  Future<Map<String, dynamic>> getStats() async {
    final allEntries = await _db.getAllCacheEntries();
    if (allEntries == null) {
      return {
        'total': 0,
        'fresh': 0,
        'expired': 0,
        'memoryCache': _memoryCache.length,
      };
    }
    final now = DateTime.now().millisecondsSinceEpoch;

    final total = allEntries.length;
    final expired = allEntries.where((e) => e.expiresAt < now).length;
    final fresh = total - expired;

    return {
      'total': total,
      'fresh': fresh,
      'expired': expired,
      'memoryCache': _memoryCache.length,
    };
  }

  /// Serialize a value to JSON string.
  String _serialize<T>(T value, Map<String, dynamic> Function(T)? toJson) {
    if (value is String) {
      return value;
    }
    if (toJson != null) {
      return jsonEncode(toJson(value));
    }
    return jsonEncode(value);
  }

  /// Deserialize a JSON string to the expected type.
  T? _deserialize<T>(String data, T Function(Map<String, dynamic>)? fromJson) {
    if (T == String) {
      return data as T;
    }

    try {
      final decoded = jsonDecode(data);

      if (fromJson != null && decoded is Map<String, dynamic>) {
        return fromJson(decoded);
      }

      return decoded as T;
    } catch (e) {
      return null;
    }
  }

  /// Add an entry to the memory cache with LRU eviction.
  void _addToMemoryCache(String key, String data, int expiresAt) {
    // Simple LRU: remove oldest if at capacity
    if (_memoryCache.length >= _maxMemoryCacheSize && !_memoryCache.containsKey(key)) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }

    _memoryCache[key] = _MemoryCacheEntry(
      data: data,
      cachedAt: DateTime.now().millisecondsSinceEpoch,
      expiresAt: expiresAt,
    );
  }

  /// Close the cache service.
  ///
  /// Clears the memory cache and resets the initialized state.
  /// Note: Does not close the database - DatabaseService manages that.
  Future<void> close() async {
    _memoryCache.clear();
    _isInitialized = false;
  }

  /// Dispose of resources.
  Future<void> dispose() => close();
}

/// In-memory cache entry for quick access.
class _MemoryCacheEntry {
  _MemoryCacheEntry({
    required this.data,
    required this.cachedAt,
    required this.expiresAt,
  });

  final String data;
  final int cachedAt;
  final int expiresAt;

  bool get isExpired {
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }
}
