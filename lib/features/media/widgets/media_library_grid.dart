import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/blossom/blossom_models.dart';
import '../providers/blossom_provider.dart';
import 'media_thumbnail.dart';

/// A grid view of the user's uploaded media from Blossom.
///
/// Shows loading, error, and empty states appropriately.
/// Uses mediaLibraryProvider to fetch and display the user's uploaded blobs.
///
/// Example:
/// ```dart
/// MediaLibraryGrid(
///   onSelect: (blob) {
///     // Handle blob selection
///     Navigator.of(context).pop(blob);
///   },
///   onDelete: (blob) {
///     // Handle blob deletion
///     ref.read(mediaLibraryProvider.notifier).deleteBlob(blob.sha256);
///   },
/// )
/// ```
class MediaLibraryGrid extends ConsumerStatefulWidget {
  const MediaLibraryGrid({
    super.key,
    this.onSelect,
    this.onDelete,
    this.crossAxisCount = 3,
    this.spacing = 8,
    this.padding = const EdgeInsets.all(16),
    this.selectionMode = false,
    this.selectedBlobs = const {},
  });

  /// Callback when a blob is selected.
  final void Function(BlossomBlob blob)? onSelect;

  /// Callback when a blob should be deleted.
  final void Function(BlossomBlob blob)? onDelete;

  /// Number of columns in the grid.
  final int crossAxisCount;

  /// Spacing between grid items.
  final double spacing;

  /// Padding around the grid.
  final EdgeInsets padding;

  /// Whether the grid is in selection mode (shows checkmarks).
  final bool selectionMode;

  /// Set of selected blob SHA256 hashes (used in selection mode).
  final Set<String> selectedBlobs;

  @override
  ConsumerState<MediaLibraryGrid> createState() => _MediaLibraryGridState();
}

class _MediaLibraryGridState extends ConsumerState<MediaLibraryGrid> {
  @override
  void initState() {
    super.initState();
    // Fetch library on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mediaLibraryProvider.notifier).loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(mediaLibraryProvider);

    return libraryState.when(
      initial: () => _buildLoadingState(),
      loading: () => _buildLoadingState(),
      loaded: (blobs, isUploading) {
        if (blobs.isEmpty) {
          return _buildEmptyState();
        }
        return _buildGrid(blobs, isUploading);
      },
      error: (message) => _buildErrorState(message),
    );
  }

  /// Build the loading state.
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your media...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the error state.
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load media',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(mediaLibraryProvider.notifier).loadLibrary();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the empty state.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No media uploaded',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your uploaded media will appear here.\nStart by uploading an image or file.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build the grid of thumbnails.
  Widget _buildGrid(List<BlossomBlob> blobs, bool isUploading) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(mediaLibraryProvider.notifier).refresh();
      },
      color: AppColors.primary,
      child: Stack(
        children: [
          GridView.builder(
            padding: widget.padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              crossAxisSpacing: widget.spacing,
              mainAxisSpacing: widget.spacing,
            ),
            itemCount: blobs.length,
            itemBuilder: (context, index) {
              final blob = blobs[index];
              final isSelected = widget.selectedBlobs.contains(blob.sha256);

              return MediaThumbnail(
                blob: blob,
                onTap:
                    widget.onSelect != null ? () => widget.onSelect!(blob) : null,
                onDelete:
                    widget.onDelete != null ? () => _confirmDelete(blob) : null,
                showDeleteButton: widget.onDelete != null && !widget.selectionMode,
                isSelected: widget.selectionMode && isSelected,
              );
            },
          ),
          // Show uploading indicator
          if (isUploading)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Uploading...',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show a confirmation dialog before deleting.
  Future<void> _confirmDelete(BlossomBlob blob) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Media',
          style: AppTypography.headlineSmall,
        ),
        content: Text(
          'Are you sure you want to delete this media? This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      widget.onDelete!(blob);
    }
  }
}

/// A full-screen dialog for selecting media from the library.
///
/// Example:
/// ```dart
/// final blob = await showMediaLibraryDialog(context: context);
/// if (blob != null) {
///   // Use selected blob
/// }
/// ```
class MediaLibraryDialog extends ConsumerWidget {
  const MediaLibraryDialog({
    super.key,
    this.title = 'Select Media',
    this.allowDelete = false,
  });

  /// Title of the dialog.
  final String title;

  /// Whether to allow deleting media from within the dialog.
  final bool allowDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: AppTypography.headlineSmall,
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: MediaLibraryGrid(
        onSelect: (blob) => Navigator.of(context).pop(blob),
        onDelete: allowDelete
            ? (blob) {
                ref.read(mediaLibraryProvider.notifier).deleteBlob(blob.sha256);
              }
            : null,
      ),
    );
  }
}

/// Helper function to show the media library dialog.
///
/// Returns the selected [BlossomBlob] or null if cancelled.
Future<BlossomBlob?> showMediaLibraryDialog({
  required BuildContext context,
  String title = 'Select Media',
  bool allowDelete = false,
}) {
  return Navigator.of(context).push<BlossomBlob>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => MediaLibraryDialog(
        title: title,
        allowDelete: allowDelete,
      ),
    ),
  );
}
