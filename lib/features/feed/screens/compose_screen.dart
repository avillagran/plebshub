import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/blossom/blossom_models.dart';
import '../../../services/ndk_service.dart';
import '../../../shared/widgets/link_preview_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../media/providers/blossom_provider.dart';
import '../../media/widgets/media_picker_sheet.dart';
import '../../media/widgets/media_thumbnail.dart';
import '../../media/widgets/upload_progress_indicator.dart';

/// Regex pattern for matching URLs in text.
final _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

/// Screen for composing and publishing a new text note (kind:1).
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _textController = TextEditingController();
  final _ndkService = NdkService.instance;
  bool _isPublishing = false;
  bool _isUploading = false;

  /// List of attached media blobs.
  final List<BlossomBlob> _attachedMedia = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Shows the media picker bottom sheet.
  void _showMediaPicker() {
    showMediaPickerSheet(
      context: context,
      onFileSelected: _handleFileSelected,
      onLibraryTap: _showMediaLibrary,
      maxFileSize: 100 * 1024 * 1024, // 100 MB
    );
  }

  /// Handles file selection from the media picker.
  Future<void> _handleFileSelected(Uint8List bytes, String fileName) async {
    // Get auth state
    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      _showSnackBar('You must be logged in to upload media', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final blossomService = ref.read(blossomServiceProvider);
      final serverUrl = await ref.read(blossomServerProvider.future);

      final result = await blossomService.uploadFile(
        fileBytes: bytes,
        fileName: fileName,
        privateKey: authState.keypair.privateKey!,
        serverUrl: serverUrl,
      );

      if (result.isSuccess && result.dataOrNull != null) {
        if (mounted) {
          setState(() {
            _attachedMedia.add(result.dataOrNull!);
            _isUploading = false;
          });
          _showSnackBar('Media uploaded successfully!');
        }
      } else {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          _showSnackBar(
            result.errorOrNull ?? 'Failed to upload media',
            isError: true,
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showSnackBar('Error uploading: $e', isError: true);
      }
    }
  }

  /// Shows a dialog to select from existing media library.
  void _showMediaLibrary() {
    // Load the library first
    ref.read(mediaLibraryProvider.notifier).loadLibrary();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select from Library',
                      style: AppTypography.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Media library content
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final libraryState = ref.watch(mediaLibraryProvider);

                    return libraryState.when(
                      initial: () => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              size: 64,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading media library...',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      loaded: (blobs, isUploading) {
                        if (blobs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 64,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No media uploaded yet',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: blobs.length,
                          itemBuilder: (context, index) {
                            final blob = blobs[index];
                            final isAlreadyAttached = _attachedMedia
                                .any((m) => m.sha256 == blob.sha256);

                            return MediaThumbnail(
                              blob: blob,
                              isSelected: isAlreadyAttached,
                              showFileSize: true,
                              onTap: () {
                                if (!isAlreadyAttached) {
                                  setState(() {
                                    _attachedMedia.add(blob);
                                  });
                                  Navigator.of(context).pop();
                                  _showSnackBar('Media attached');
                                } else {
                                  _showSnackBar(
                                    'Media already attached',
                                    isError: true,
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                      error: (message) => Center(
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
                              message,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(mediaLibraryProvider.notifier)
                                    .loadLibrary();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Removes attached media at the given index.
  void _removeAttachedMedia(BlossomBlob blob) {
    setState(() {
      _attachedMedia.removeWhere((m) => m.sha256 == blob.sha256);
    });
  }

  Future<void> _publishNote() async {
    var content = _textController.text.trim();

    // Validate content (either text or media required)
    if (content.isEmpty && _attachedMedia.isEmpty) {
      _showSnackBar('Please enter some content or attach media', isError: true);
      return;
    }

    // Append media URLs to content
    if (_attachedMedia.isNotEmpty) {
      final buffer = StringBuffer(content);
      for (final media in _attachedMedia) {
        if (buffer.isNotEmpty) {
          buffer.write('\n');
        }
        buffer.write(media.url);
      }
      content = buffer.toString();
    }

    // Get auth state
    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      _showSnackBar('You must be logged in to post', isError: true);
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      // Publish the note
      final publishedEvent = await _ndkService.publishTextNote(
        content: content,
        privateKey: authState.keypair.privateKey!,
        tags: [["client", "PlebsHub"]],
      );

      if (publishedEvent != null) {
        // Success
        if (mounted) {
          _showSnackBar('Note published successfully!');
          // Navigate back to feed
          context.pop();
        }
      } else {
        // Failed to publish
        if (mounted) {
          _showSnackBar('Failed to publish note', isError: true);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final characterCount = _textController.text.length;

    // Check if user is authenticated
    if (authState is! AuthStateAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compose'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'You must be logged in to post',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose'),
        actions: [
          if (_isPublishing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _publishNote,
              child: Text(
                'Post',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncateNpub(authState.npub),
                        style: AppTypography.labelLarge,
                      ),
                      Text(
                        'Posting to global feed',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Text input
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}), // Update character count
                enabled: !_isPublishing && !_isUploading,
              ),
            ),
            // Link preview (only show if there's a URL and no attached media)
            if (_attachedMedia.isEmpty) ...[
              Builder(
                builder: (context) {
                  final firstUrl = _extractFirstUrl(_textController.text);
                  if (firstUrl == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: LinkPreviewWidget(url: firstUrl),
                  );
                },
              ),
            ],
            // Upload progress indicator
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: UploadProgressIndicator(
                  onCancel: () {
                    // Note: Actual upload cancellation would require service support
                    setState(() {
                      _isUploading = false;
                    });
                  },
                ),
              ),
            // Attached media thumbnails
            if (_attachedMedia.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: MediaThumbnailRow(
                  blobs: _attachedMedia,
                  onDelete: _removeAttachedMedia,
                  onAddTap: _isUploading ? null : _showMediaPicker,
                  thumbnailSize: 80,
                ),
              ),
            // Bottom row: character counter and attach button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Attach media button
                Row(
                  children: [
                    IconButton(
                      onPressed:
                          _isPublishing || _isUploading ? null : _showMediaPicker,
                      icon: Icon(
                        Icons.attach_file,
                        color: _isPublishing || _isUploading
                            ? AppColors.textTertiary
                            : AppColors.primary,
                      ),
                      tooltip: 'Attach media',
                    ),
                    if (_attachedMedia.isNotEmpty)
                      Text(
                        '${_attachedMedia.length} attached',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                // Character counter
                if (characterCount > 0)
                  Text(
                    '$characterCount characters',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Truncate npub for display.
  String _truncateNpub(String npub) {
    if (npub.length <= 16) {
      return npub;
    }
    return '${npub.substring(0, 12)}...${npub.substring(npub.length - 4)}';
  }

  /// Extracts the first URL from the text, or returns null if none found.
  String? _extractFirstUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }
}
