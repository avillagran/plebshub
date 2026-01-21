import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/blossom/blossom_models.dart';
import '../providers/blossom_provider.dart';
import '../widgets/media_library_grid.dart';

/// Full screen for managing the user's Blossom media library.
///
/// Features:
/// - Grid view of all uploaded media
/// - Pull-to-refresh to reload
/// - Floating action button to upload new media
/// - Selection mode for multi-select deletion
/// - Empty state with upload prompt
/// - Loading and error states
///
/// Example:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => const MediaLibraryScreen(),
///   ),
/// );
/// ```
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedBlobs = {};

  @override
  void initState() {
    super.initState();
    // Load library on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mediaLibraryProvider.notifier).loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(mediaLibraryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _selectionMode
              ? '${_selectedBlobs.length} selected'
              : 'Media Library',
          style: AppTypography.headlineSmall,
        ),
        leading: _selectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            // Select all / deselect all
            IconButton(
              icon: Icon(
                _isAllSelected ? Icons.deselect : Icons.select_all,
                color: AppColors.textPrimary,
              ),
              onPressed: _toggleSelectAll,
              tooltip: _isAllSelected ? 'Deselect all' : 'Select all',
            ),
            // Delete selected
            if (_selectedBlobs.isNotEmpty)
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: _confirmDeleteSelected,
                tooltip: 'Delete selected',
              ),
          ] else ...[
            // Enter selection mode
            IconButton(
              icon: Icon(Icons.checklist, color: AppColors.textPrimary),
              onPressed: _enterSelectionMode,
              tooltip: 'Select items',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: libraryState.when(
          initial: () => _buildLoadingState(),
          loading: () => _buildLoadingState(),
          loaded: (blobs, isUploading) {
            if (blobs.isEmpty) {
              return _buildEmptyState();
            }
            return MediaLibraryGrid(
              onSelect: _onBlobTap,
              onDelete: _selectionMode ? null : _onBlobDelete,
              selectionMode: _selectionMode,
              selectedBlobs: _selectedBlobs,
            );
          },
          error: (message) => _buildErrorState(message),
        ),
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _showUploadOptions,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  /// Whether all blobs are selected.
  bool get _isAllSelected {
    final state = ref.read(mediaLibraryProvider);
    if (state is MediaLibraryStateLoaded) {
      return state.blobs.isNotEmpty &&
          _selectedBlobs.length == state.blobs.length;
    }
    return false;
  }

  /// Handle pull-to-refresh.
  Future<void> _onRefresh() async {
    await ref.read(mediaLibraryProvider.notifier).refresh();
  }

  /// Enter selection mode.
  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedBlobs.clear();
    });
  }

  /// Exit selection mode.
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedBlobs.clear();
    });
  }

  /// Toggle select all / deselect all.
  void _toggleSelectAll() {
    final state = ref.read(mediaLibraryProvider);
    if (state is MediaLibraryStateLoaded) {
      setState(() {
        if (_isAllSelected) {
          _selectedBlobs.clear();
        } else {
          _selectedBlobs.clear();
          for (final blob in state.blobs) {
            _selectedBlobs.add(blob.sha256);
          }
        }
      });
    }
  }

  /// Handle blob tap (select in selection mode, or preview otherwise).
  void _onBlobTap(BlossomBlob blob) {
    if (_selectionMode) {
      setState(() {
        if (_selectedBlobs.contains(blob.sha256)) {
          _selectedBlobs.remove(blob.sha256);
        } else {
          _selectedBlobs.add(blob.sha256);
        }
      });
    } else {
      // TODO: Show full-screen preview
      _showBlobPreview(blob);
    }
  }

  /// Handle single blob deletion.
  void _onBlobDelete(BlossomBlob blob) {
    ref.read(mediaLibraryProvider.notifier).deleteBlob(blob.sha256);
  }

  /// Show confirmation dialog for deleting selected blobs.
  Future<void> _confirmDeleteSelected() async {
    final count = _selectedBlobs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete $count item${count == 1 ? '' : 's'}?',
          style: AppTypography.headlineSmall,
        ),
        content: Text(
          'Are you sure you want to delete the selected media? This action cannot be undone.',
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

    if (confirmed == true) {
      await _deleteSelectedBlobs();
    }
  }

  /// Delete all selected blobs.
  Future<void> _deleteSelectedBlobs() async {
    final notifier = ref.read(mediaLibraryProvider.notifier);
    final toDelete = List<String>.from(_selectedBlobs);

    for (final sha256 in toDelete) {
      await notifier.deleteBlob(sha256);
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${toDelete.length} item${toDelete.length == 1 ? '' : 's'}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    }
  }

  /// Show upload options bottom sheet.
  void _showUploadOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UploadOptionsSheet(
        onFileSelected: _uploadFile,
      ),
    );
  }

  /// Upload a file.
  Future<void> _uploadFile(File file) async {
    debugPrint('[MediaLibrary] Starting upload: ${file.path}');

    // Show uploading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Uploading...')),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        duration: const Duration(seconds: 30),
      ),
    );

    final blob = await ref.read(mediaLibraryProvider.notifier).uploadFile(file);
    debugPrint('[MediaLibrary] Upload result: ${blob?.sha256 ?? 'failed'}');

    // Clear the uploading snackbar
    ScaffoldMessenger.of(context).clearSnackBars();

    if (mounted) {
      if (blob != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Upload successful'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Upload failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  /// Show blob preview (placeholder for future full implementation).
  void _showBlobPreview(BlossomBlob blob) {
    // For now, show a simple dialog with blob info
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Media Details',
          style: AppTypography.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (blob.mimeType.startsWith('image/'))
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  blob.url,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: AppColors.surfaceVariant,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textTertiary,
                      size: 48,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Type', value: blob.mimeType),
            _DetailRow(label: 'Size', value: _formatFileSize(blob.size)),
            _DetailRow(
              label: 'Uploaded',
              value: _formatDate(blob.uploadedAt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Format file size for display.
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Format date for display.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 80,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 24),
              Text(
                'No media uploaded yet',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your uploaded images and files will appear here.\nTap the upload button to get started.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showUploadOptions,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload Media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A detail row for the blob preview dialog.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with upload options.
class _UploadOptionsSheet extends StatelessWidget {
  const _UploadOptionsSheet({
    required this.onFileSelected,
  });

  final void Function(File file) onFileSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Upload Media',
                style: AppTypography.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            // Options
            _UploadOption(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              subtitle: 'Select an image from your gallery',
              onTap: () => _pickFromGallery(context),
            ),
            _UploadOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take photo',
              subtitle: 'Capture a new photo with your camera',
              onTap: () => _takePhoto(context),
            ),
            _UploadOption(
              icon: Icons.folder_outlined,
              title: 'Choose file',
              subtitle: 'Select any file from your device',
              onTap: () => _pickFile(context),
            ),
            const SizedBox(height: 16),
            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && context.mounted) {
        Navigator.of(context).pop();
        onFileSelected(File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      if (context.mounted) {
        _showError(context, 'Failed to pick image from gallery');
      }
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    final picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null && context.mounted) {
        Navigator.of(context).pop();
        onFileSelected(File(photo.path));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (context.mounted) {
        _showError(context, 'Failed to capture photo');
      }
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null &&
          context.mounted) {
        Navigator.of(context).pop();
        onFileSelected(File(result.files.first.path!));
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        _showError(context, 'Failed to pick file');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }
}

/// A single option in the upload sheet.
class _UploadOption extends StatelessWidget {
  const _UploadOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
