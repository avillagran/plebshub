import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/link_preview.dart';
import '../providers/link_preview_provider.dart';

/// A card widget that displays a link preview with OpenGraph metadata.
///
/// Shows:
/// - Thumbnail image (if available)
/// - Title
/// - Description (truncated)
/// - Domain name
///
/// Layout:
/// ```
/// +------------------------------+
/// | [Image    ] Title            |
/// | [Thumbnail] Description...   |
/// |             domain.com       |
/// +------------------------------+
/// ```
///
/// Example:
/// ```dart
/// LinkPreviewCard(
///   preview: LinkPreview(
///     url: 'https://example.com/article',
///     title: 'Example Article',
///     description: 'This is an example...',
///     imageUrl: 'https://example.com/image.jpg',
///   ),
///   onTap: () => launchUrl(Uri.parse(url)),
/// )
/// ```
class LinkPreviewCard extends StatelessWidget {
  /// Creates a LinkPreviewCard widget.
  const LinkPreviewCard({
    super.key,
    required this.preview,
    this.onTap,
  });

  /// The link preview data to display.
  final LinkPreview preview;

  /// Optional tap callback. If not provided, opens the URL.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => _launchUrl(preview.url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Layout with image on left if available
    if (preview.hasImage) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            SizedBox(
              width: 100,
              child: _buildThumbnail(),
            ),
            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildTextContent(),
              ),
            ),
          ],
        ),
      );
    }

    // No image - full width text
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _buildTextContent(),
    );
  }

  Widget _buildThumbnail() {
    return CachedNetworkImage(
      imageUrl: preview.imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 200,
      memCacheHeight: 200,
      placeholder: (context, url) => Container(
        color: AppColors.surface,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.surface,
        child: const Icon(
          Icons.link,
          color: AppColors.textTertiary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        if (preview.title != null) ...[
          Text(
            preview.title!,
            style: AppTypography.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],

        // Description
        if (preview.description != null) ...[
          Text(
            preview.description!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
        ],

        // Domain with link icon
        Row(
          children: [
            Icon(
              Icons.link,
              size: 12,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                preview.domain,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// A loading skeleton for link preview cards.
///
/// Shows an animated shimmer effect while the preview is being fetched.
class LinkPreviewCardSkeleton extends StatelessWidget {
  const LinkPreviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail skeleton
            Container(
              width: 100,
              height: 80,
              color: AppColors.surface,
            ),
            // Text skeleton
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSkeletonLine(width: double.infinity),
                    const SizedBox(height: 8),
                    _buildSkeletonLine(width: 150),
                    const SizedBox(height: 8),
                    _buildSkeletonLine(width: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLine({required double width}) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// A consumer widget that fetches and displays a link preview.
///
/// Automatically handles loading and error states.
///
/// Example:
/// ```dart
/// LinkPreviewWidget(url: 'https://example.com/article')
/// ```
class LinkPreviewWidget extends ConsumerWidget {
  const LinkPreviewWidget({
    super.key,
    required this.url,
    this.onTap,
  });

  /// The URL to show a preview for.
  final String url;

  /// Optional tap callback. If not provided, opens the URL.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if we should show a preview for this URL
    final shouldShow = ref.watch(shouldShowLinkPreviewProvider(url));
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final previewAsync = ref.watch(linkPreviewProvider(url));

    return previewAsync.when(
      data: (preview) {
        if (preview == null || !preview.hasContent) {
          return const SizedBox.shrink();
        }
        return LinkPreviewCard(
          preview: preview,
          onTap: onTap,
        );
      },
      loading: () => const LinkPreviewCardSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
