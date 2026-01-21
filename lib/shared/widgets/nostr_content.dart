import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'embeddable_video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/nostr_content_parser.dart';
import 'youtube_player_widget.dart';

/// Callback signature for mention taps.
typedef OnMentionTap = void Function(MentionSegment mention);

/// Callback signature for legacy mention taps (NIP-08/NIP-27).
typedef OnLegacyMentionTap = void Function(int index);

/// Callback signature for hashtag taps.
typedef OnHashtagTap = void Function(String hashtag);

/// Callback signature for cashtag taps.
typedef OnCashtagTap = void Function(String symbol);

/// Callback signature for URL taps.
typedef OnUrlTap = void Function(String url);

/// Callback signature for image taps.
typedef OnImageTap = void Function(String imageUrl, List<String> allImages, int index);

/// A widget that renders Nostr content with rich formatting.
///
/// Automatically detects and renders:
/// - URLs as clickable links
/// - Markdown links [text](url)
/// - Images as inline previews
/// - Video URLs as links (with play icon)
/// - User mentions (npub, nprofile)
/// - Legacy mentions (#[0], #[1]) for NIP-08/NIP-27
/// - Note references (note, nevent)
/// - Hashtags (#nostr)
/// - Cashtags ($BTC, $USD)
/// - Lightning invoices
/// - Inline code (`code`)
/// - Code blocks (```code```)
/// - Custom emojis (:emoji:) via NIP-30
///
/// Example:
/// ```dart
/// NostrContent(
///   content: 'Hello nostr:npub1... Check out #nostr https://example.com',
///   onMentionTap: (mention) => navigateToProfile(mention.bech32),
///   onHashtagTap: (tag) => searchHashtag(tag),
///   emojiTags: {'custom': 'https://example.com/emoji.png'},
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
    this.cashtagStyle,
    this.codeStyle,
    this.codeBlockStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onMentionTap,
    this.onLegacyMentionTap,
    this.onHashtagTap,
    this.onCashtagTap,
    this.onUrlTap,
    this.onImageTap,
    this.showImages = true,
    this.showImagePreviews = true,
    this.maxImageHeight = 300,
    this.imageSpacing = 8,
    this.emojiTags = const {},
    this.customEmojiSize = 20,
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

  /// Style for cashtags ($BTC, $USD).
  final TextStyle? cashtagStyle;

  /// Style for inline code.
  final TextStyle? codeStyle;

  /// Style for code blocks.
  final TextStyle? codeBlockStyle;

  /// Maximum number of lines for the text content.
  final int? maxLines;

  /// How to handle text overflow.
  final TextOverflow overflow;

  /// Callback when a mention is tapped.
  final OnMentionTap? onMentionTap;

  /// Callback when a legacy mention (#[0]) is tapped.
  final OnLegacyMentionTap? onLegacyMentionTap;

  /// Callback when a hashtag is tapped.
  final OnHashtagTap? onHashtagTap;

  /// Callback when a cashtag is tapped.
  final OnCashtagTap? onCashtagTap;

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

  /// Map of emoji shortcodes to image URLs for NIP-30 custom emojis.
  /// Keys should NOT include colons (e.g., {'smiley': 'https://...'}).
  final Map<String, String> emojiTags;

  /// Size for custom emoji images.
  final double customEmojiSize;

  @override
  State<NostrContent> createState() => _NostrContentState();
}

class _NostrContentState extends State<NostrContent> {
  late NostrContentParser _parser;
  late List<ContentSegment> _segments;
  late List<ImageSegment> _images;
  late List<CodeBlockSegment> _codeBlocks;
  late List<YouTubeSegment> _youtubeVideos;
  late List<VideoSegment> _videos;

  @override
  void initState() {
    super.initState();
    _parser = NostrContentParser(emojiTags: widget.emojiTags);
    _parseContent();
  }

  @override
  void didUpdateWidget(NostrContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.emojiTags != widget.emojiTags) {
      _parser = NostrContentParser(emojiTags: widget.emojiTags);
      _parseContent();
    }
  }

  void _parseContent() {
    _segments = _parser.parse(widget.content);
    _images = _segments.whereType<ImageSegment>().toList();
    _codeBlocks = _segments.whereType<CodeBlockSegment>().toList();
    _youtubeVideos = _segments.whereType<YouTubeSegment>().toList();
    _videos = _segments.whereType<VideoSegment>().toList();
  }

  @override
  Widget build(BuildContext context) {
    // Separate text content from images, code blocks, and videos for better layout
    final hasImages = widget.showImages && _images.isNotEmpty;
    final hasCodeBlocks = _codeBlocks.isNotEmpty;
    final hasYouTubeVideos = _youtubeVideos.isNotEmpty;
    final hasVideos = _videos.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text content (RichText) - code blocks rendered separately below
        _buildTextContent(),

        // Code blocks (rendered as separate widgets for better formatting)
        if (hasCodeBlocks) ...[
          for (final codeBlock in _codeBlocks) ...[
            SizedBox(height: widget.imageSpacing),
            _buildCodeBlockWidget(codeBlock),
          ],
        ],

        // YouTube videos
        if (hasYouTubeVideos) ...[
          for (final youtube in _youtubeVideos) ...[
            SizedBox(height: widget.imageSpacing),
            YouTubePlayerWidget(url: youtube.url),
          ],
        ],

        // Generic videos (mp4, webm, etc.) using PlebsPlayer
        if (hasVideos) ...[
          for (final video in _videos) ...[
            SizedBox(height: widget.imageSpacing),
            EmbeddableVideoPlayer(
              url: video.url,
              showControls: true,
            ),
          ],
        ],

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

    final cashtagStyle = widget.cashtagStyle ??
        baseStyle.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w500,
        );

    final codeStyle = widget.codeStyle ??
        baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
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

        case MarkdownLinkSegment():
          spans.add(_buildLinkSpan(segment.url, segment.text, linkStyle));

        case ImageSegment():
          // Show as link in text flow (image preview shown separately)
          if (!widget.showImagePreviews) {
            spans.add(_buildLinkSpan(segment.url, '[image]', linkStyle));
          }
          // When showing previews, we hide image URLs from text

        case VideoSegment():
          // Videos are rendered separately as widgets, don't show in text
          break;

        case MentionSegment():
          spans.add(_buildMentionSpan(segment, mentionStyle));

        case LegacyMentionSegment():
          spans.add(_buildLegacyMentionSpan(segment, mentionStyle));

        case HashtagSegment():
          spans.add(_buildHashtagSpan(segment, hashtagStyle));

        case CashtagSegment():
          spans.add(_buildCashtagSpan(segment, cashtagStyle));

        case InlineCodeSegment():
          spans.add(_buildInlineCodeSpan(segment, codeStyle));

        case CodeBlockSegment():
          // Code blocks are rendered separately as widgets, show placeholder in text
          spans.add(TextSpan(text: '[code]', style: linkStyle));

        case CustomEmojiSegment():
          spans.add(_buildCustomEmojiSpan(segment, baseStyle));

        case LightningSegment():
          spans.add(_buildLightningSpan(segment, linkStyle));

        case YouTubeSegment():
          // YouTube videos are rendered separately as widgets, show placeholder in text
          // Don't show anything in text since the player is shown separately
          break;
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

  InlineSpan _buildCashtagSpan(CashtagSegment cashtag, TextStyle style) {
    return TextSpan(
      text: '\$${cashtag.symbol}',
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _handleCashtagTap(cashtag.symbol),
    );
  }

  InlineSpan _buildLegacyMentionSpan(LegacyMentionSegment mention, TextStyle style) {
    return TextSpan(
      text: '#[${mention.index}]',
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _handleLegacyMentionTap(mention.index),
    );
  }

  InlineSpan _buildInlineCodeSpan(InlineCodeSegment code, TextStyle style) {
    return TextSpan(
      text: code.code,
      style: style,
    );
  }

  InlineSpan _buildCustomEmojiSpan(CustomEmojiSegment emoji, TextStyle baseStyle) {
    // If we have an image URL, render as an inline image widget
    if (emoji.imageUrl != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: CachedNetworkImage(
          imageUrl: emoji.imageUrl!,
          width: widget.customEmojiSize,
          height: widget.customEmojiSize,
          fit: BoxFit.contain,
          placeholder: (context, url) => SizedBox(
            width: widget.customEmojiSize,
            height: widget.customEmojiSize,
            child: const CircularProgressIndicator(strokeWidth: 1),
          ),
          errorWidget: (context, url, error) => Text(
            ':${emoji.name}:',
            style: baseStyle,
          ),
        ),
      );
    }

    // Fallback: show the shortcode as text
    return TextSpan(
      text: ':${emoji.name}:',
      style: baseStyle,
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

  Widget _buildCodeBlockWidget(CodeBlockSegment codeBlock) {
    final codeBlockStyle = widget.codeBlockStyle ??
        const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.textSecondary,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (codeBlock.language != null && codeBlock.language!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                codeBlock.language!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SelectableText(
            codeBlock.code,
            style: codeBlockStyle,
          ),
        ],
      ),
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

  void _handleCashtagTap(String symbol) {
    if (widget.onCashtagTap != null) {
      widget.onCashtagTap!(symbol);
    }
    // Default: do nothing if no handler provided
  }

  void _handleLegacyMentionTap(int index) {
    if (widget.onLegacyMentionTap != null) {
      widget.onLegacyMentionTap!(index);
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
