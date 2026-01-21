import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/link_preview_service.dart';
import '../models/link_preview.dart';

/// Provider for the LinkPreviewService singleton.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService.instance;
});

/// Provider for the in-memory link preview cache.
///
/// This cache sits above the Drift cache to provide synchronous access
/// to already-fetched previews, eliminating loading states on re-renders.
final linkPreviewCacheProvider =
    StateNotifierProvider<LinkPreviewCacheNotifier, Map<String, LinkPreview?>>(
  (ref) => LinkPreviewCacheNotifier(),
);

/// State notifier that maintains an in-memory cache of link previews.
///
/// This prevents re-fetching and loading states when widgets rebuild.
/// The underlying service still uses Drift for persistence across app restarts.
class LinkPreviewCacheNotifier extends StateNotifier<Map<String, LinkPreview?>> {
  LinkPreviewCacheNotifier() : super({});

  /// Maximum number of entries to keep in memory.
  static const int _maxCacheSize = 200;

  /// Check if a URL is already in the in-memory cache.
  bool contains(String url) => state.containsKey(url);

  /// Get a preview from the in-memory cache.
  LinkPreview? get(String url) => state[url];

  /// Add or update a preview in the cache.
  void set(String url, LinkPreview? preview) {
    // Simple LRU eviction: remove oldest entries if at capacity
    if (state.length >= _maxCacheSize && !state.containsKey(url)) {
      final newState = Map<String, LinkPreview?>.from(state);
      // Remove first 20% of entries (oldest due to insertion order)
      final keysToRemove = newState.keys.take((_maxCacheSize * 0.2).toInt()).toList();
      for (final key in keysToRemove) {
        newState.remove(key);
      }
      newState[url] = preview;
      state = newState;
    } else {
      state = {...state, url: preview};
    }
  }

  /// Clear a specific URL from the cache.
  void remove(String url) {
    if (state.containsKey(url)) {
      state = Map.from(state)..remove(url);
    }
  }

  /// Clear all cached previews.
  void clear() {
    state = {};
  }
}

/// Provider for fetching a single link preview by URL.
///
/// Uses a two-tier caching strategy:
/// 1. In-memory cache (synchronous, survives widget rebuilds)
/// 2. Drift cache (persistent, survives app restarts)
///
/// This eliminates loading states when scrolling through a feed,
/// as previously viewed previews are served from memory instantly.
///
/// Example:
/// ```dart
/// final previewAsync = ref.watch(linkPreviewProvider(url));
///
/// previewAsync.when(
///   data: (preview) {
///     if (preview != null) {
///       return LinkPreviewCard(preview: preview);
///     }
///     return SizedBox.shrink(); // No preview available
///   },
///   loading: () => LinkPreviewLoadingSkeleton(),
///   error: (e, st) => SizedBox.shrink(), // Silently fail
/// );
/// ```
final linkPreviewProvider =
    FutureProvider.family<LinkPreview?, String>((ref, url) async {
  final cache = ref.watch(linkPreviewCacheProvider.notifier);

  // Check in-memory cache first (synchronous, no loading state)
  if (cache.contains(url)) {
    return cache.get(url);
  }

  // Fetch from service (which checks Drift cache, then network)
  final service = ref.watch(linkPreviewServiceProvider);
  final preview = await service.fetchPreview(url);

  // Store in in-memory cache for future renders
  cache.set(url, preview);

  return preview;
});

/// Provider for fetching multiple link previews at once.
///
/// Useful for prefetching previews for a list of URLs.
///
/// Example:
/// ```dart
/// final previewsAsync = ref.watch(batchLinkPreviewsProvider(urls));
///
/// previewsAsync.when(
///   data: (previews) {
///     return Column(
///       children: urls.map((url) {
///         final preview = previews[url];
///         if (preview != null) {
///           return LinkPreviewCard(preview: preview);
///         }
///         return SizedBox.shrink();
///       }).toList(),
///     );
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => SizedBox.shrink(),
/// );
/// ```
final batchLinkPreviewsProvider =
    FutureProvider.family<Map<String, LinkPreview>, List<String>>((ref, urls) async {
  final service = ref.watch(linkPreviewServiceProvider);
  return service.fetchPreviews(urls);
});

/// Provider to check if a URL should show a link preview.
///
/// Returns false for image/video URLs that are already rendered as media.
final shouldShowLinkPreviewProvider = Provider.family<bool, String>((ref, url) {
  // Image extensions
  const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico'};

  // Video extensions
  const videoExtensions = {'.mp4', '.webm', '.mov', '.avi', '.mkv', '.m4v'};

  try {
    final uri = Uri.parse(url.toLowerCase());
    final path = uri.path;

    for (final ext in imageExtensions) {
      if (path.endsWith(ext)) {
        return false;
      }
    }

    for (final ext in videoExtensions) {
      if (path.endsWith(ext)) {
        return false;
      }
    }

    return true;
  } catch (_) {
    return false;
  }
});
