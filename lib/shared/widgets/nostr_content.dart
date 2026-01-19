import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/nostr_content_parser.dart';

/// Callback signature for mention taps.
typedef OnMentionTap = void Function(MentionSegment mention);

/// Callback signature for hashtag taps.
typedef OnHashtagTap = void Function(String hashtag);

/// Callback signature for URL taps.
typedef OnUrlTap = void Function(String url);

/// Callback signature for image taps.
typedef OnImageTap = void Function(String imageUrl, List<String> allImages, int index);

/// A widget that renders Nostr content with rich formatting.
///
/// Automatically detects and renders:
/// - URLs as clickable links
/// - Images as inline previews
/// - Video URLs as links (with play icon)
/// - User mentions (npub, nprofile)
/// - Note references (note, nevent)
/// - Hashtags
/// - Lightning invoices
///
/// Example:
/// ```dart
/// NostrContent(
///   content: 'Hello nostr:npub1... Check out #nostr https://example.com',
///   onMentionTap: (mention) => navigateToProfile(mention.bech32),
///   onHashtagTap: (tag) => searchHashtag(tag),
/// )
/// ```
class NostrContent extends StatefulWidget {
  /// Creates a NostrContent widget.
  const NostrContent({
    super.key,
    required this.content,
    this.style,
    this.linkStyle,
    this.mentionStyle,
    this.hashtagStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onMentionTap,
    this.onHashtagTap,
    this.onUrlTap,
    this.onImageTap,
    this.showImages = true,
    this.showImagePreviews = true,
    this.maxImageHeight = 300,
    this.imageSpacing = 8,
  });

  /// The raw Nostr content to render.
  final String content;

  /// Base text style.
  final TextStyle? style;

  /// Style for URLs.
  final TextStyle? linkStyle;

  /// Style for mentions.
  final TextStyle? mentionStyle;

  /// Style for hashtags.
  final TextStyle? hashtagStyle;

  /// Maximum number of lines for the text content.
  final int? maxLines;

  /// How to handle text overflow.
  final TextOverflow overflow;

  /// Callback when a mention is tapped.
  final OnMentionTap? onMentionTap;

  /// Callback when a hashtag is tapped.
  final OnHashtagTap? onHashtagTap;

  /// Callback when a URL is tapped.
  final OnUrlTap? onUrlTap;

  /// Callback when an image is tapped.
  final OnImageTap? onImageTap;

  /// Whether to show images.
  final bool showImages;

  /// Whether to show image previews inline.
  final bool showImagePreviews;

  /// Maximum height for image previews.
  final double maxImageHeight;

  /// Spacing between images.
  final double imageSpacing;

  @override
  State<NostrContent> createState() => _NostrContentState();
}

class _NostrContentState extends State<NostrContent> {
  static const _parser = NostrContentParser();
  late List<ContentSegment> _segments;
  late List<ImageSegment> _images;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  @override
  void didUpdateWidget(NostrContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _parseContent();
    }
  }

  void _parseContent() {
    _segments = _parser.parse(widget.content);
    _images = _segments.whereType<ImageSegment>().toList();
  }

  @override
  Widget build(BuildContext context) {
    // Separate text content from images for better layout
    final hasImages = widget.showImages && _images.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text content (RichText)
        _buildTextContent(),

        // Images
        if (hasImages && widget.showImagePreviews) ...[
          SizedBox(height: widget.imageSpacing),
          _buildImageGallery(),
        ],
      ],
    );
  }

  Widget _buildTextContent() {
    final baseStyle = widget.style ?? AppTypography.bodyMedium;

    final linkStyle = widget.linkStyle ??
        baseStyle.copyWith(
          color: AppColors.info,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.info,
        );

    final mentionStyle = widget.mentionStyle ??
        baseStyle.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        );

    final hashtagStyle = widget.hashtagStyle ??
        baseStyle.copyWith(
          color: AppColors.primary,
        );

    final spans = <InlineSpan>[];

    for (final segment in _segments) {
      switch (segment) {
        case TextSegment():
          spans.add(TextSpan(text: segment.text, style: baseStyle));

        case NewlineSegment():
          spans.add(TextSpan(text: '\n' * segment.count, style: baseStyle));

        case UrlSegment():
          spans.add(_buildLinkSpan(segment.url, segment.url, linkStyle));

        case ImageSegment():
          // Show as link in text flow (image preview shown separately)
          if (!widget.showImagePreviews) {
            spans.add(_buildLinkSpan(segment.url, '[image]', linkStyle));
          }
          // When showing previews, we hide image URLs from text

        case VideoSegment():
          spans.add(_buildLinkSpan(segment.url, '[video]', linkStyle));

        case MentionSegment():
          spans.add(_buildMentionSpan(segment, mentionStyle));

        case HashtagSegment():
          spans.add(_buildHashtagSpan(segment, hashtagStyle));

        case LightningSegment():
          spans.add(_buildLightningSpan(segment, linkStyle));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  InlineSpan _buildLinkSpan(String url, String displayText, TextStyle style) {
    return TextSpan(
      text: displayText,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _handleUrlTap(url),
    );
  }

  InlineSpan _buildMentionSpan(MentionSegment mention, TextStyle style) {
    // Determine display based on entity type
    final String prefix;
    switch (mention.entityType) {
      case NostrEntityType.npub:
      case NostrEntityType.nprofile:
        prefix = '@';
      case NostrEntityType.note:
      case NostrEntityType.nevent:
      case NostrEntityType.naddr:
        prefix = '';
    }

    return TextSpan(
      text: '$prefix${mention.shortDisplay}',
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _handleMentionTap(mention),
    );
  }

  InlineSpan _buildHashtagSpan(HashtagSegment hashtag, TextStyle style) {
    return TextSpan(
      text: '#${hashtag.tag}',
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _handleHashtagTap(hashtag.tag),
    );
  }

  InlineSpan _buildLightningSpan(LightningSegment lightning, TextStyle style) {
    // Show shortened invoice with lightning icon
    final shortInvoice = lightning.invoice.length > 20
        ? '${lightning.invoice.substring(0, 16)}...'
        : lightning.invoice;

    return TextSpan(
      text: shortInvoice,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _handleLightningTap(lightning.invoice),
    );
  }

  Widget _buildImageGallery() {
    if (_images.isEmpty) return const SizedBox.shrink();

    if (_images.length == 1) {
      return _buildSingleImage(_images.first, 0);
    }

    // Multiple images - show in a horizontal scroll or grid
    return SizedBox(
      height: widget.maxImageHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (_, __) => SizedBox(width: widget.imageSpacing),
        itemBuilder: (context, index) => _buildSingleImage(_images[index], index),
      ),
    );
  }

  Widget _buildSingleImage(ImageSegment image, int index) {
    return GestureDetector(
      onTap: () => _handleImageTap(image.url, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.maxImageHeight,
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: CachedNetworkImage(
            imageUrl: image.url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              width: 200,
              color: AppColors.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 100,
              width: 200,
              color: AppColors.surfaceVariant,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: AppColors.textTertiary),
                  SizedBox(height: 4),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleUrlTap(String url) {
    if (widget.onUrlTap != null) {
      widget.onUrlTap!(url);
    } else {
      _launchUrl(url);
    }
  }

  void _handleMentionTap(MentionSegment mention) {
    if (widget.onMentionTap != null) {
      widget.onMentionTap!(mention);
    }
    // Default: do nothing if no handler provided
  }

  void _handleHashtagTap(String hashtag) {
    if (widget.onHashtagTap != null) {
      widget.onHashtagTap!(hashtag);
    }
    // Default: do nothing if no handler provided
  }

  void _handleLightningTap(String invoice) {
    // Open lightning: URI
    final uri = 'lightning:$invoice';
    _launchUrl(uri);
  }

  void _handleImageTap(String imageUrl, int index) {
    if (widget.onImageTap != null) {
      widget.onImageTap!(
        imageUrl,
        _images.map((i) => i.url).toList(),
        index,
      );
    }
    // Default: could open full-screen viewer
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// A preview mode for NostrContent that shows limited content.
class NostrContentPreview extends StatelessWidget {
  /// Creates a preview-mode NostrContent widget.
  const NostrContentPreview({
    super.key,
    required this.content,
    this.maxLines = 3,
    this.style,
    this.onMentionTap,
    this.onHashtagTap,
    this.onUrlTap,
  });

  /// The raw Nostr content.
  final String content;

  /// Maximum lines to show.
  final int maxLines;

  /// Text style.
  final TextStyle? style;

  /// Callback when a mention is tapped.
  final OnMentionTap? onMentionTap;

  /// Callback when a hashtag is tapped.
  final OnHashtagTap? onHashtagTap;

  /// Callback when a URL is tapped.
  final OnUrlTap? onUrlTap;

  @override
  Widget build(BuildContext context) {
    return NostrContent(
      content: content,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      showImages: false, // No images in preview
      showImagePreviews: false,
      onMentionTap: onMentionTap,
      onHashtagTap: onHashtagTap,
      onUrlTap: onUrlTap,
    );
  }
}
