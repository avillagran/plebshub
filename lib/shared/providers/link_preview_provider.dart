import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/link_preview_service.dart';
import '../models/link_preview.dart';

/// Provider for the LinkPreviewService singleton.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService.instance;
});

/// Provider for fetching a single link preview by URL.
///
/// This is a family provider that caches previews per URL.
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
final linkPreviewProvider = FutureProvider.family<LinkPreview?, String>((ref, url) async {
  final service = ref.watch(linkPreviewServiceProvider);
  return service.fetchPreview(url);
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
