import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

/// A bottom sheet for selecting media from various sources.
///
/// Provides options to:
/// - Choose from gallery (uses ImagePicker)
/// - Take a photo (uses ImagePicker camera)
/// - Choose a file (uses FilePicker)
/// - Select from uploaded media library
///
/// Example:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (context) => MediaPickerSheet(
///     onFileSelected: (bytes, fileName) {
///       // Handle selected file
///     },
///     onLibraryTap: () {
///       // Show media library
///     },
///   ),
/// );
/// ```
class MediaPickerSheet extends StatelessWidget {
  const MediaPickerSheet({
    super.key,
    required this.onFileSelected,
    this.onLibraryTap,
    this.allowedExtensions,
    this.maxFileSize,
  });

  /// Callback when a file is selected.
  /// Provides the file bytes and original file name.
  final void Function(Uint8List bytes, String fileName) onFileSelected;

  /// Optional callback to show the media library.
  /// If null, the "Select from uploaded" option is hidden.
  final VoidCallback? onLibraryTap;

  /// Optional list of allowed file extensions (without dot).
  /// Example: ['jpg', 'png', 'gif', 'webp']
  final List<String>? allowedExtensions;

  /// Maximum file size in bytes. Files larger than this will be rejected.
  final int? maxFileSize;

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
                'Add Media',
                style: AppTypography.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            // Options
            _MediaPickerOption(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              subtitle: 'Select an image or video from your gallery',
              onTap: () => _pickFromGallery(context),
            ),
            _MediaPickerOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take photo',
              subtitle: 'Capture a new photo with your camera',
              onTap: () => _takePhoto(context),
            ),
            _MediaPickerOption(
              icon: Icons.folder_outlined,
              title: 'Choose file',
              subtitle: 'Select any file from your device',
              onTap: () => _pickFile(context),
            ),
            if (onLibraryTap != null)
              _MediaPickerOption(
                icon: Icons.cloud_outlined,
                title: 'Select from uploaded',
                subtitle: 'Choose from your Blossom media library',
                onTap: () {
                  Navigator.of(context).pop();
                  onLibraryTap!();
                },
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

  /// Pick an image from the gallery using ImagePicker.
  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && context.mounted) {
        final bytes = await image.readAsBytes();
        final fileName = image.name;

        // Check file size
        if (maxFileSize != null && bytes.length > maxFileSize!) {
          if (context.mounted) {
            _showFileSizeError(context);
          }
          return;
        }

        Navigator.of(context).pop();
        onFileSelected(bytes, fileName);
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      if (context.mounted) {
        _showError(context, 'Failed to pick image from gallery');
      }
    }
  }

  /// Take a photo using the device camera.
  Future<void> _takePhoto(BuildContext context) async {
    final picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null && context.mounted) {
        final bytes = await photo.readAsBytes();
        final fileName = photo.name;

        // Check file size
        if (maxFileSize != null && bytes.length > maxFileSize!) {
          if (context.mounted) {
            _showFileSizeError(context);
          }
          return;
        }

        Navigator.of(context).pop();
        onFileSelected(bytes, fileName);
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (context.mounted) {
        _showError(context, 'Failed to capture photo');
      }
    }
  }

  /// Pick a file using FilePicker.
  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.bytes != null &&
          context.mounted) {
        final file = result.files.first;
        final bytes = file.bytes!;
        final fileName = file.name;

        // Check file size
        if (maxFileSize != null && bytes.length > maxFileSize!) {
          if (context.mounted) {
            _showFileSizeError(context);
          }
          return;
        }

        Navigator.of(context).pop();
        onFileSelected(bytes, fileName);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        _showError(context, 'Failed to pick file');
      }
    }
  }

  /// Show an error snackbar.
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// Show a file size error snackbar.
  void _showFileSizeError(BuildContext context) {
    final maxMB = (maxFileSize! / (1024 * 1024)).toStringAsFixed(1);
    _showError(context, 'File too large. Maximum size is $maxMB MB');
  }
}

/// A single option in the media picker sheet.
class _MediaPickerOption extends StatelessWidget {
  const _MediaPickerOption({
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

/// Helper function to show the media picker sheet.
///
/// Returns the selected file bytes and name, or null if cancelled.
Future<void> showMediaPickerSheet({
  required BuildContext context,
  required void Function(Uint8List bytes, String fileName) onFileSelected,
  VoidCallback? onLibraryTap,
  List<String>? allowedExtensions,
  int? maxFileSize,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => MediaPickerSheet(
      onFileSelected: onFileSelected,
      onLibraryTap: onLibraryTap,
      allowedExtensions: allowedExtensions,
      maxFileSize: maxFileSize,
    ),
  );
}
