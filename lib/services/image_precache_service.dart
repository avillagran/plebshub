import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// A singleton service for preloading images before they become visible.
///
/// This service manages image preloading for feed items that are near the
/// viewport but not yet visible, improving perceived scroll performance.
///
/// Features:
/// - Tracks which URLs have been precached to avoid duplicate requests
/// - Limits concurrent precache operations to avoid overwhelming the network
/// - Uses CachedNetworkImage's cache system for efficient storage
///
/// Example usage:
/// ```dart
/// // In a ListView.builder
/// itemBuilder: (context, index) {
///   // Precache images for next 5 items
///   final nextUrls = getImageUrlsForRange(index + 1, index + 5);
///   ImagePrecacheService.instance.precacheImages(nextUrls, context);
///   return PostCard(post: posts[index]);
/// }
/// ```
class ImagePrecacheService {
  ImagePrecacheService._();

  /// The singleton instance.
  static final ImagePrecacheService instance = ImagePrecacheService._();

  /// Set of URLs that have already been precached or are in the queue.
  final Set<String> _precachedUrls = {};

  /// Queue of URLs waiting to be precached.
  final Queue<String> _pendingUrls = Queue();

  /// Number of currently active precache operations.
  int _activeLoads = 0;

  /// Maximum number of concurrent precache operations.
  static const int _maxConcurrent = 3;

  /// Precache a list of image URLs.
  ///
  /// URLs that have already been precached or are in the queue will be skipped.
  /// Precaching happens asynchronously in the background with limited concurrency.
  ///
  /// [urls] - The image URLs to precache.
  /// [context] - A BuildContext needed for Flutter's precacheImage function.
  void precacheImages(List<String> urls, BuildContext context) {
    if (!context.mounted) return;

    for (final url in urls) {
      if (url.isEmpty) continue;
      if (_precachedUrls.contains(url)) continue;

      // Mark as pending to avoid adding duplicates
      _precachedUrls.add(url);
      _pendingUrls.add(url);
    }

    _processQueue(context);
  }

  /// Process the pending URL queue.
  ///
  /// Starts precaching for URLs in the queue up to the concurrent limit.
  void _processQueue(BuildContext context) {
    if (!context.mounted) return;

    while (_activeLoads < _maxConcurrent && _pendingUrls.isNotEmpty) {
      final url = _pendingUrls.removeFirst();
      _startPrecache(url, context);
    }
  }

  /// Start precaching a single URL.
  void _startPrecache(String url, BuildContext context) {
    if (!context.mounted) return;

    _activeLoads++;

    precacheImage(
      CachedNetworkImageProvider(url),
      context,
    ).then((_) {
      _activeLoads--;
      if (context.mounted) {
        _processQueue(context);
      }
    }).catchError((Object error) {
      // Silently handle errors - precaching is best-effort
      // The URL stays in _precachedUrls to avoid retrying failed URLs
      _activeLoads--;
      if (context.mounted) {
        _processQueue(context);
      }
    });
  }

  /// Clear all cached state.
  ///
  /// This resets the service but does not clear the underlying image cache.
  /// Use this if you want to allow re-precaching of previously loaded images.
  void clear() {
    _precachedUrls.clear();
    _pendingUrls.clear();
    _activeLoads = 0;
  }

  /// Check if a URL has been precached or is pending.
  bool isPrecached(String url) => _precachedUrls.contains(url);

  /// Get the number of URLs that have been processed.
  int get precachedCount => _precachedUrls.length;

  /// Get the number of URLs pending in the queue.
  int get pendingCount => _pendingUrls.length;

  /// Get the number of active precache operations.
  int get activeCount => _activeLoads;
}
