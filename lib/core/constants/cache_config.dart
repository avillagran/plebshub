/// Configuration constants for caching.
///
/// Defines TTL (time-to-live) durations for different types of cached data.
/// These values are optimized for a Twitter-like instant loading experience
/// with background refresh.
///
/// TTL Strategy:
/// - Posts: 1 hour (frequent updates expected)
/// - Profiles: 6 hours (metadata changes rarely)
/// - Channels: 6 hours (similar to profiles)
/// - Following list: 30 minutes (more dynamic social data)
/// - Max cache age: 24 hours (cleanup threshold)
///
/// Images are handled by CachedNetworkImage with 7 days default.
class CacheConfig {
  CacheConfig._();

  /// TTL for cached posts (feed items).
  ///
  /// Posts use a stale-while-revalidate pattern where cached content
  /// is shown immediately while fresh content is fetched in background.
  static const Duration postsTtl = Duration(hours: 1);

  /// TTL for cached user profiles (kind:0 metadata).
  ///
  /// Profile metadata changes infrequently, so a longer TTL is acceptable.
  static const Duration profilesTtl = Duration(hours: 6);

  /// TTL for cached channels list and metadata.
  ///
  /// Channel information is relatively stable.
  static const Duration channelsTtl = Duration(hours: 6);

  /// TTL for cached following list (kind:3 contact list).
  ///
  /// Follow lists are more dynamic than profiles but less so than posts.
  static const Duration followingTtl = Duration(minutes: 30);

  /// Maximum age for any cached data.
  ///
  /// Entries older than this will be cleaned up on app startup
  /// to prevent storage bloat.
  static const Duration maxCacheAge = Duration(hours: 24);

  /// TTL for cached link previews.
  ///
  /// Link preview metadata changes infrequently, so a longer TTL is acceptable.
  static const Duration linkPreviewsTtl = Duration(hours: 6);

  /// Cache key prefixes for different data types.
  static const String feedKeyPrefix = 'feed_';
  static const String profileKeyPrefix = 'profile_';
  static const String channelKeyPrefix = 'channel_';
  static const String channelListKey = 'channel_list';
  static const String followingKeyPrefix = 'following_';
  static const String linkPreviewKeyPrefix = 'link_preview_';
}
