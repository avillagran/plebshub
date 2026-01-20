import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../shared/models/link_preview.dart';
import 'cache/cache_service.dart';

/// Service for fetching and caching link previews.
///
/// Extracts OpenGraph metadata from URLs for display in link preview cards.
/// Implements caching with 6-hour TTL to avoid repeated network requests.
///
/// Features:
/// - Extracts og:title, og:description, og:image, og:site_name
/// - Falls back to <title> and meta description if OG tags missing
/// - Caches results for 6 hours
/// - Times out after 5 seconds
/// - Skips image/video URLs (already handled by NostrContent)
///
/// Example:
/// ```dart
/// final service = LinkPreviewService.instance;
/// final preview = await service.fetchPreview('https://example.com/article');
/// if (preview != null) {
///   // print('Title: ${preview.title}');
///   // print('Image: ${preview.imageUrl}');
/// }
/// ```
class LinkPreviewService {
  LinkPreviewService._();

  static final LinkPreviewService _instance = LinkPreviewService._();

  /// Singleton instance.
  static LinkPreviewService get instance => _instance;

  /// HTTP client for making requests.
  final http.Client _httpClient = http.Client();

  /// Cache service for persisting previews.
  final CacheService _cacheService = CacheService.instance;

  /// TTL for link preview cache (6 hours).
  static const Duration _cacheTtl = Duration(hours: 6);

  /// Request timeout duration.
  static const Duration _timeout = Duration(seconds: 5);

  /// Cache key prefix for link previews.
  static const String _cacheKeyPrefix = 'link_preview_';

  /// Known image extensions to skip.
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.svg',
    '.bmp',
    '.ico',
  };

  /// Known video extensions to skip.
  static const Set<String> _videoExtensions = {
    '.mp4',
    '.webm',
    '.mov',
    '.avi',
    '.mkv',
    '.m4v',
  };

  /// Fetches link preview metadata for a URL.
  ///
  /// Returns null if:
  /// - URL is an image or video (already handled by NostrContent)
  /// - Request fails or times out
  /// - No useful metadata found
  ///
  /// Results are cached for 6 hours.
  Future<LinkPreview?> fetchPreview(String url) async {
    // Skip image/video URLs
    if (_isMediaUrl(url)) {
      return null;
    }

    // Check cache first
    final cacheKey = '$_cacheKeyPrefix${_urlToCacheKey(url)}';
    final cached = await _cacheService.get<Map<String, dynamic>>(
      cacheKey,
      allowStale: true,
    );

    if (cached != null) {
      return LinkPreview.fromJson(cached);
    }

    // Fetch from network
    try {
      final preview = await _fetchFromNetwork(url);

      if (preview != null) {
        // Cache the result
        await _cacheService.set(
          cacheKey,
          preview.toJson(),
          _cacheTtl,
        );
      }

      return preview;
    } catch (e) {
      return null;
    }
  }

  /// Fetches previews for multiple URLs in parallel.
  ///
  /// Returns a map of URL -> LinkPreview for successful fetches.
  /// URLs that fail or return null are not included in the result.
  Future<Map<String, LinkPreview>> fetchPreviews(List<String> urls) async {
    final results = <String, LinkPreview>{};

    // Filter out duplicates and media URLs
    final uniqueUrls = urls.toSet().where((url) => !_isMediaUrl(url)).toList();

    if (uniqueUrls.isEmpty) {
      return results;
    }

    // Fetch in parallel with limited concurrency
    final futures = uniqueUrls.map((url) async {
      final preview = await fetchPreview(url);
      if (preview != null) {
        return MapEntry(url, preview);
      }
      return null;
    });

    final entries = await Future.wait(futures);

    for (final entry in entries) {
      if (entry != null) {
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  /// Checks if a URL is a direct media link.
  bool _isMediaUrl(String url) {
    try {
      final uri = Uri.parse(url.toLowerCase());
      final path = uri.path;

      for (final ext in _imageExtensions) {
        if (path.endsWith(ext)) {
          return true;
        }
      }

      for (final ext in _videoExtensions) {
        if (path.endsWith(ext)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches and parses metadata from a URL.
  Future<LinkPreview?> _fetchFromNetwork(String url) async {
    try {
      final uri = Uri.parse(url);

      final response = await _httpClient
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (compatible; PlebsHub/1.0; +https://plebshub.app)',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      // Check content type is HTML
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/html') && !contentType.contains('application/xhtml')) {
        return null;
      }

      return _parseHtml(url, response.body);
    } catch (e) {
      return null;
    }
  }

  /// Parses HTML to extract OpenGraph and fallback metadata.
  LinkPreview? _parseHtml(String url, String html) {
    try {
      final document = html_parser.parse(html);

      // Extract OpenGraph tags
      String? ogTitle = _getMetaContent(document, 'property', 'og:title');
      String? ogDescription = _getMetaContent(document, 'property', 'og:description');
      String? ogImage = _getMetaContent(document, 'property', 'og:image');
      String? ogSiteName = _getMetaContent(document, 'property', 'og:site_name');

      // Fallback to standard meta tags
      final title = ogTitle ?? document.querySelector('title')?.text.trim();
      final description = ogDescription ??
          _getMetaContent(document, 'name', 'description') ??
          _getMetaContent(document, 'property', 'description');

      // Try Twitter card as fallback for image
      final twitterImage = _getMetaContent(document, 'name', 'twitter:image') ??
          _getMetaContent(document, 'property', 'twitter:image');
      final imageUrl = ogImage ?? twitterImage;

      // Try to get favicon
      String? favicon;
      final faviconLink = document.querySelector('link[rel="icon"]') ??
          document.querySelector('link[rel="shortcut icon"]');
      if (faviconLink != null) {
        favicon = faviconLink.attributes['href'];
        // Make relative URLs absolute
        if (favicon != null && !favicon.startsWith('http')) {
          final uri = Uri.parse(url);
          if (favicon.startsWith('//')) {
            favicon = '${uri.scheme}:$favicon';
          } else if (favicon.startsWith('/')) {
            favicon = '${uri.scheme}://${uri.host}$favicon';
          } else {
            favicon = '${uri.scheme}://${uri.host}/$favicon';
          }
        }
      }

      // If no useful content, return null
      if (title == null && description == null) {
        return null;
      }

      // Make relative image URLs absolute
      String? absoluteImageUrl = imageUrl;
      if (absoluteImageUrl != null && !absoluteImageUrl.startsWith('http')) {
        final uri = Uri.parse(url);
        if (absoluteImageUrl.startsWith('//')) {
          absoluteImageUrl = '${uri.scheme}:$absoluteImageUrl';
        } else if (absoluteImageUrl.startsWith('/')) {
          absoluteImageUrl = '${uri.scheme}://${uri.host}$absoluteImageUrl';
        } else {
          absoluteImageUrl = '${uri.scheme}://${uri.host}/$absoluteImageUrl';
        }
      }

      return LinkPreview(
        url: url,
        title: title,
        description: _truncateDescription(description),
        imageUrl: absoluteImageUrl,
        siteName: ogSiteName,
        favicon: favicon,
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets meta tag content by attribute and value.
  String? _getMetaContent(html_dom.Document document, String attribute, String value) {
    final element = document.querySelector('meta[$attribute="$value"]');
    final content = element?.attributes['content'];
    return content?.trim().isNotEmpty == true ? content!.trim() : null;
  }

  /// Truncates description to a reasonable length.
  String? _truncateDescription(String? description) {
    if (description == null || description.isEmpty) {
      return null;
    }

    const maxLength = 200;
    if (description.length <= maxLength) {
      return description;
    }

    // Truncate at word boundary
    final truncated = description.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > maxLength - 50) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  /// Converts a URL to a cache-safe key.
  String _urlToCacheKey(String url) {
    // Use a simple hash-like approach
    return url.hashCode.toRadixString(16);
  }

  /// Clears cached preview for a specific URL.
  Future<void> clearFromCache(String url) async {
    final cacheKey = '$_cacheKeyPrefix${_urlToCacheKey(url)}';
    await _cacheService.remove(cacheKey);
  }

  /// Clears all cached link previews.
  Future<int> clearAllCached() async {
    return await _cacheService.removeByPrefix(_cacheKeyPrefix);
  }

  /// Dispose of resources.
  void dispose() {
    _httpClient.close();
  }
}
