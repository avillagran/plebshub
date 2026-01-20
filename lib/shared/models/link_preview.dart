import 'package:equatable/equatable.dart';

/// A model representing OpenGraph metadata for a URL link preview.
///
/// Contains extracted metadata from a webpage's OpenGraph tags,
/// including the title, description, image, and site information.
///
/// Example:
/// ```dart
/// final preview = LinkPreview(
///   url: 'https://example.com/article',
///   title: 'Example Article',
///   description: 'This is an example article...',
///   imageUrl: 'https://example.com/image.jpg',
///   siteName: 'Example Site',
///   favicon: 'https://example.com/favicon.ico',
/// );
/// ```
class LinkPreview extends Equatable {
  /// Creates a new LinkPreview instance.
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.favicon,
  });

  /// The original URL this preview was fetched from.
  final String url;

  /// The page title from og:title or <title> tag.
  final String? title;

  /// The page description from og:description or meta description.
  final String? description;

  /// The preview image URL from og:image.
  final String? imageUrl;

  /// The site name from og:site_name.
  final String? siteName;

  /// The favicon URL.
  final String? favicon;

  /// Creates a LinkPreview from a JSON map.
  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      siteName: json['siteName'] as String?,
      favicon: json['favicon'] as String?,
    );
  }

  /// Converts this LinkPreview to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'siteName': siteName,
      'favicon': favicon,
    };
  }

  /// Returns the domain name from the URL.
  ///
  /// Example: 'https://www.example.com/path' -> 'example.com'
  String get domain {
    try {
      final uri = Uri.parse(url);
      var host = uri.host;
      // Remove 'www.' prefix if present
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host;
    } catch (_) {
      return url;
    }
  }

  /// Whether this preview has useful content to display.
  ///
  /// Returns true if the preview has at least a title or description.
  bool get hasContent => title != null || description != null;

  /// Whether this preview has an image to display.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  List<Object?> get props => [url, title, description, imageUrl, siteName, favicon];

  @override
  String toString() {
    return 'LinkPreview(url: $url, title: $title, siteName: $siteName)';
  }
}
