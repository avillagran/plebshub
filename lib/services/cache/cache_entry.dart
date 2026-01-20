import 'package:isar/isar.dart';

part 'cache_entry.g.dart';

/// Isar collection for storing cached data with TTL support.
///
/// This collection stores serialized data with metadata for TTL-based
/// cache invalidation. Supports the stale-while-revalidate pattern.
@collection
class CacheEntry {
  CacheEntry({
    required this.key,
    required this.data,
    required this.cachedAt,
    required this.expiresAt,
    this.dataType,
  });

  /// Isar's internal auto-increment ID.
  Id get isarId => fastHash(key);

  /// Unique cache key.
  ///
  /// Examples: "feed_global", "profile_abc123", "channel_xyz789"
  @Index(unique: true)
  late String key;

  /// Serialized data (JSON string).
  late String data;

  /// When this entry was cached (Unix timestamp in milliseconds).
  @Index()
  late int cachedAt;

  /// When this entry expires (Unix timestamp in milliseconds).
  @Index()
  late int expiresAt;

  /// Optional type identifier for the cached data.
  ///
  /// Helps with debugging and allows type-specific cache operations.
  String? dataType;

  /// Check if this cache entry has expired.
  bool get isExpired {
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }

  /// Check if this entry is stale (expired but still usable for stale-while-revalidate).
  bool get isStale => isExpired;

  /// Get the cached timestamp as DateTime.
  DateTime get cachedAtDateTime {
    return DateTime.fromMillisecondsSinceEpoch(cachedAt);
  }

  /// Get the expiry timestamp as DateTime.
  DateTime get expiresAtDateTime {
    return DateTime.fromMillisecondsSinceEpoch(expiresAt);
  }

  /// Age of this cache entry in milliseconds.
  @ignore
  int get ageMs {
    return DateTime.now().millisecondsSinceEpoch - cachedAt;
  }

  /// Generate a fast hash for the key to use as Isar ID.
  ///
  /// Uses FNV-1a hash algorithm.
  static Id fastHash(String string) {
    var hash = 0xcbf29ce484222325;

    var i = 0;
    while (i < string.length) {
      final codeUnit = string.codeUnitAt(i++);
      hash ^= codeUnit >> 8;
      hash *= 0x100000001b3;
      hash ^= codeUnit & 0xFF;
      hash *= 0x100000001b3;
    }

    return hash;
  }
}
