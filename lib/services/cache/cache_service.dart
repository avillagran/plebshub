import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_entry.dart';

/// Service for managing application cache with TTL support.
///
/// Provides a generic caching mechanism that:
/// - Persists to Isar database for survival across app restarts
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

  Isar? _isar;

  /// In-memory cache for quick access (avoids Isar reads for hot data).
  final Map<String, _MemoryCacheEntry> _memoryCache = {};

  /// Maximum number of items to keep in memory cache.
  static const int _maxMemoryCacheSize = 100;

  /// Check if the cache service is initialized.
  bool get isInitialized => _isar != null;

  /// Initialize the cache service.
  ///
  /// Opens a separate Isar instance for cache data. This is separate from
  /// the main database to allow independent lifecycle management.
  Future<void> initialize() async {
    if (_isar != null) {
      return; // Already initialized
    }

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [CacheEntrySchema],
      directory: dir.path,
      name: 'plebshub_cache',
    );
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

    // Check Isar cache
    final entry = await _isar?.cacheEntrys.where().keyEqualTo(key).findFirst();

    if (entry == null) {
      return null;
    }

    // Check if expired
    if (entry.isExpired && !allowStale) {
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

    // Update Isar cache
    final entry = CacheEntry(
      key: key,
      data: data,
      cachedAt: now,
      expiresAt: expiresAt,
      dataType: T.toString(),
    );

    await _isar?.writeTxn(() async {
      await _isar?.cacheEntrys.put(entry);
    });
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

    // Check Isar cache
    final entry = await _isar?.cacheEntrys.where().keyEqualTo(key).findFirst();
    return entry?.isStale ?? false;
  }

  /// Check if a cache entry exists (regardless of freshness).
  Future<bool> exists(String key) async {
    if (_memoryCache.containsKey(key)) {
      return true;
    }

    final entry = await _isar?.cacheEntrys.where().keyEqualTo(key).findFirst();
    return entry != null;
  }

  /// Remove a specific cache entry.
  Future<void> remove(String key) async {
    _memoryCache.remove(key);

    await _isar?.writeTxn(() async {
      await _isar?.cacheEntrys.where().keyEqualTo(key).deleteAll();
    });
  }

  /// Remove all cache entries matching a prefix.
  ///
  /// Useful for clearing all entries of a specific type.
  /// Example: clearByPrefix('profile_') clears all profile caches.
  Future<int> removeByPrefix(String prefix) async {
    // Clear from memory cache
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));

    // Clear from Isar
    var count = 0;
    await _isar?.writeTxn(() async {
      final entries = await _isar?.cacheEntrys
          .filter()
          .keyStartsWith(prefix)
          .findAll();
      if (entries != null) {
        count = entries.length;
        await _isar?.cacheEntrys.deleteAll(entries.map((e) => e.isarId).toList());
      }
    });

    return count;
  }

  /// Clear all cached data.
  Future<void> clear() async {
    _memoryCache.clear();

    await _isar?.writeTxn(() async {
      await _isar?.cacheEntrys.clear();
    });
  }

  /// Clear cache entries older than the specified duration.
  ///
  /// Returns the number of entries cleared.
  /// Should be called on app startup to prevent storage bloat.
  Future<int> clearOlderThan(Duration duration) async {
    final cutoff = DateTime.now().subtract(duration).millisecondsSinceEpoch;

    // Clear from memory cache
    _memoryCache.removeWhere((_, entry) => entry.cachedAt < cutoff);

    // Clear from Isar
    var count = 0;
    await _isar?.writeTxn(() async {
      final entries = await _isar?.cacheEntrys
          .filter()
          .cachedAtLessThan(cutoff)
          .findAll();
      if (entries != null) {
        count = entries.length;
        await _isar?.cacheEntrys.deleteAll(entries.map((e) => e.isarId).toList());
      }
    });

    return count;
  }

  /// Clear all expired cache entries.
  ///
  /// Returns the number of entries cleared.
  Future<int> clearExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Clear from memory cache
    _memoryCache.removeWhere((_, entry) => entry.expiresAt < now);

    // Clear from Isar
    var count = 0;
    await _isar?.writeTxn(() async {
      final entries = await _isar?.cacheEntrys
          .filter()
          .expiresAtLessThan(now)
          .findAll();
      if (entries != null) {
        count = entries.length;
        await _isar?.cacheEntrys.deleteAll(entries.map((e) => e.isarId).toList());
      }
    });

    return count;
  }

  /// Get cache statistics for debugging.
  Future<Map<String, dynamic>> getStats() async {
    final allEntries = await _isar?.cacheEntrys.where().findAll();
    final now = DateTime.now().millisecondsSinceEpoch;

    final total = allEntries?.length ?? 0;
    final expired = allEntries?.where((e) => e.expiresAt < now).length ?? 0;
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

  /// Close the cache database.
  Future<void> close() async {
    _memoryCache.clear();
    await _isar?.close();
    _isar = null;
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
