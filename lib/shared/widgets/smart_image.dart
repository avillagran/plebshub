import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A smart image widget that handles both network URLs and data URIs (base64).
///
/// CachedNetworkImage cannot handle data URIs, which causes "No host specified"
/// errors. This widget detects data URIs and uses Image.memory instead.
///
/// Example:
/// ```dart
/// SmartImage(
///   imageUrl: profile.picture, // Can be URL or data:image/png;base64,...
///   width: 40,
///   height: 40,
///   fit: BoxFit.cover,
///   placeholder: (context, url) => CircularProgressIndicator(),
///   errorWidget: (context, url, error) => Icon(Icons.error),
/// )
/// ```
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  /// The image URL (can be a network URL or a data URI).
  final String imageUrl;

  /// Optional width constraint.
  final double? width;

  /// Optional height constraint.
  final double? height;

  /// How the image should fit within its bounds.
  final BoxFit? fit;

  /// Widget to display while loading (for network images).
  final Widget Function(BuildContext, String)? placeholder;

  /// Widget to display on error.
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  @override
  Widget build(BuildContext context) {
    // Check if this is a data URI (base64 encoded image)
    if (isDataUri(imageUrl)) {
      return _buildDataUriImage(context);
    }

    // Validate that the URL is a proper HTTP/HTTPS URL
    // This prevents pubkeys or other invalid strings from being passed to CachedNetworkImage
    if (!isValidNetworkUrl(imageUrl)) {
      return _buildError(context, 'Invalid image URL');
    }

    // Use CachedNetworkImage for regular URLs
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Build an image from a data URI (base64 encoded).
  Widget _buildDataUriImage(BuildContext context) {
    try {
      // Extract base64 data after the comma
      // Format: data:image/png;base64,iVBORw0KGgo...
      final commaIndex = imageUrl.indexOf(',');
      if (commaIndex == -1) {
        return _buildError(context, 'Invalid data URI format');
      }

      final base64Data = imageUrl.substring(commaIndex + 1);
      final bytes = base64Decode(base64Data);

      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget?.call(context, imageUrl, error) ??
              const Icon(Icons.broken_image);
        },
      );
    } catch (e) {
      return _buildError(context, e);
    }
  }

  /// Build error widget.
  Widget _buildError(BuildContext context, dynamic error) {
    return errorWidget?.call(context, imageUrl, error) ??
        const Icon(Icons.broken_image);
  }

  /// Check if a URL is a data URI (base64 encoded image).
  static bool isDataUri(String url) {
    return url.startsWith('data:image/');
  }

  /// Check if a URL is a valid network URL (http:// or https://).
  ///
  /// This prevents invalid strings (like pubkeys) from being passed to
  /// CachedNetworkImage, which would cause "No host specified" errors.
  static bool isValidNetworkUrl(String url) {
    // Must start with http:// or https://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }

    // Try to parse the URL and verify it has a valid host
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
