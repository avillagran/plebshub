import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/blossom/blossom_models.dart';

/// Cache of URLs that have failed to load (to avoid repeated requests).
final Set<String> _failedUrlCache = {};

/// A widget to display a media blob thumbnail.
///
/// Shows an image preview using CachedNetworkImage for image types,
/// or displays a file type icon for non-image files.
/// Also shows the file size and provides tap/delete callbacks.
///
/// Example:
/// ```dart
/// MediaThumbnail(
///   blob: myBlob,
///   onTap: () {
///     // Handle tap - e.g., open full view
///   },
///   onDelete: () {
///     // Handle delete
///   },
/// )
/// ```
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    super.key,
    required this.blob,
    this.onTap,
    this.onDelete,
    this.size = 100,
    this.borderRadius = 8,
    this.showFileSize = true,
    this.showDeleteButton = false,
    this.isSelected = false,
  });

  /// The blob to display.
  final BlossomBlob blob;

  /// Callback when the thumbnail is tapped.
  final VoidCallback? onTap;

  /// Callback when the delete button is tapped.
  /// If null, the delete button is hidden.
  final VoidCallback? onDelete;

  /// Size of the thumbnail (width and height).
  final double size;

  /// Border radius of the thumbnail.
  final double borderRadius;

  /// Whether to show the file size overlay.
  final bool showFileSize;

  /// Whether to show the delete button.
  final bool showDeleteButton;

  /// Whether this thumbnail is selected.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Content (image or icon)
              _buildContent(),
              // File size overlay
              if (showFileSize)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildFileSizeOverlay(),
                ),
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              // Delete button
              if (showDeleteButton && onDelete != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildDeleteButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if this blob is an image based on MIME type.
  bool get _isImage => blob.mimeType.startsWith('image/');

  /// Check if this blob is a video based on MIME type.
  bool get _isVideo => blob.mimeType.startsWith('video/');

  /// Check if this blob is audio based on MIME type.
  bool get _isAudio => blob.mimeType.startsWith('audio/');

/// Build placeholder widget while loading.
  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  /// Build error widget when image fails to load.
  Widget _buildErrorWidget() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              '404',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get file extension from MIME type or URL.
  String? get _extension {
    // Try to get from mime type
    final parts = blob.mimeType.split('/');
    if (parts.length == 2) {
      return parts[1].split('+').first;
    }

    // Try to get from URL
    final uri = Uri.tryParse(blob.url);
    if (uri != null) {
      final path = uri.path;
      final dotIndex = path.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < path.length - 1) {
        return path.substring(dotIndex + 1);
      }
    }

    return null;
  }

  /// Build the main content (image or icon).
  Widget _buildContent() {
    if (_isImage) {
      // Check if URL already failed - show error immediately
      if (_failedUrlCache.contains(blob.url)) {
        return _buildErrorWidget();
      }

      // Use FutureBuilder to verify URL exists before loading
      return _ValidatedNetworkImage(
        url: blob.url,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(),
        errorWidget: _buildErrorWidget(),
        onError: () => _failedUrlCache.add(blob.url),
      );
    }

    // Non-image file - show icon
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(),
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _extension?.toUpperCase() ?? 'FILE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the file size overlay at the bottom.
  Widget _buildFileSizeOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Text(
        _formatFileSize(blob.size),
        style: AppTypography.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build the delete button.
  Widget _buildDeleteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close,
            color: Colors.white,
            size: 14,
          ),
        ),
      ),
    );
  }

  /// Get the appropriate icon for the file type.
  IconData _getFileIcon() {
    final mimeType = blob.mimeType.toLowerCase();

    if (_isVideo) {
      return Icons.videocam_outlined;
    } else if (_isAudio) {
      return Icons.audiotrack_outlined;
    } else if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf_outlined;
    } else if (mimeType.contains('text') || mimeType.contains('document')) {
      return Icons.description_outlined;
    } else if (mimeType.contains('zip') ||
        mimeType.contains('archive') ||
        mimeType.contains('compressed')) {
      return Icons.archive_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  /// Format file size to human-readable string.
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      return '$gb GB';
    }
  }
}

/// Network image that validates URL exists before attempting to load.
///
/// This prevents Flutter's Image Resource Service from throwing uncatchable
/// exceptions for 404 or invalid image URLs.
class _ValidatedNetworkImage extends StatefulWidget {
  const _ValidatedNetworkImage({
    required this.url,
    required this.placeholder,
    required this.errorWidget,
    this.fit,
    this.onError,
  });

  final String url;
  final BoxFit? fit;
  final Widget placeholder;
  final Widget errorWidget;
  final VoidCallback? onError;

  @override
  State<_ValidatedNetworkImage> createState() => _ValidatedNetworkImageState();
}

class _ValidatedNetworkImageState extends State<_ValidatedNetworkImage> {
  late Future<bool> _validationFuture;

  @override
  void initState() {
    super.initState();
    _validationFuture = _validateUrl();
  }

  /// Validates URL with a HEAD request to check if image exists.
  Future<bool> _validateUrl() async {
    try {
      final response = await http.head(
        Uri.parse(widget.url),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _validationFuture,
      builder: (context, snapshot) {
        // Still loading - show placeholder
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder;
        }

        // Failed or invalid - show error
        if (snapshot.hasError || snapshot.data != true) {
          widget.onError?.call();
          return widget.errorWidget;
        }

        // Valid - show image
        return Image.network(
          widget.url,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            widget.onError?.call();
            return widget.errorWidget;
          },
        );
      },
    );
  }
}

/// A row of media thumbnails with optional add button.
class MediaThumbnailRow extends StatelessWidget {
  const MediaThumbnailRow({
    super.key,
    required this.blobs,
    this.onTap,
    this.onDelete,
    this.onAddTap,
    this.thumbnailSize = 80,
    this.spacing = 8,
    this.maxVisible = 4,
  });

  /// List of blobs to display.
  final List<BlossomBlob> blobs;

  /// Callback when a thumbnail is tapped.
  final void Function(BlossomBlob blob)? onTap;

  /// Callback when delete is tapped on a thumbnail.
  final void Function(BlossomBlob blob)? onDelete;

  /// Callback when the add button is tapped.
  final VoidCallback? onAddTap;

  /// Size of each thumbnail.
  final double thumbnailSize;

  /// Spacing between thumbnails.
  final double spacing;

  /// Maximum number of visible thumbnails before showing +N.
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visibleBlobs = blobs.take(maxVisible).toList();
    final remainingCount = blobs.length - maxVisible;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Visible thumbnails
          for (int i = 0; i < visibleBlobs.length; i++) ...[
            MediaThumbnail(
              blob: visibleBlobs[i],
              size: thumbnailSize,
              onTap: onTap != null ? () => onTap!(visibleBlobs[i]) : null,
              onDelete:
                  onDelete != null ? () => onDelete!(visibleBlobs[i]) : null,
              showDeleteButton: onDelete != null,
            ),
            if (i < visibleBlobs.length - 1 ||
                remainingCount > 0 ||
                onAddTap != null)
              SizedBox(width: spacing),
          ],
          // Remaining count indicator
          if (remainingCount > 0) ...[
            Container(
              width: thumbnailSize,
              height: thumbnailSize,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            if (onAddTap != null) SizedBox(width: spacing),
          ],
          // Add button
          if (onAddTap != null)
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: thumbnailSize,
                height: thumbnailSize,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
