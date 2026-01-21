import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/blossom/blossom_models.dart';
import '../providers/blossom_provider.dart';

/// A widget that shows upload progress for Blossom media uploads.
///
/// Displays a linear progress bar with percentage text and file name.
/// Only visible when the upload status is [UploadStatus.uploading].
///
/// Example:
/// ```dart
/// UploadProgressIndicator(
///   onCancel: () {
///     // Handle cancel
///   },
/// )
/// ```
class UploadProgressIndicator extends ConsumerWidget {
  const UploadProgressIndicator({
    super.key,
    this.onCancel,
  });

  /// Optional callback when the cancel button is pressed.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadStateAsync = ref.watch(uploadProgressProvider);

    return uploadStateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (uploadState) => _buildContent(context, uploadState),
    );
  }

  Widget _buildContent(BuildContext context, UploadProgress uploadState) {
    // Only show when uploading or processing
    if (!uploadState.isInProgress) {
      return const SizedBox.shrink();
    }

    final progress = uploadState.percentage / 100;
    final fileName = uploadState.fileName;
    final percentage = uploadState.percentage.toInt();
    final statusText = uploadState.status == UploadStatus.processing
        ? 'Processing...'
        : 'Uploading to Blossom server...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with file name and cancel button
          Row(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          // Percentage text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$percentage%',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Show error if any
          if (uploadState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              uploadState.error!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact version of the upload progress indicator for inline use.
class CompactUploadProgress extends ConsumerWidget {
  const CompactUploadProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadStateAsync = ref.watch(uploadProgressProvider);

    return uploadStateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (uploadState) {
        if (!uploadState.isInProgress) {
          return const SizedBox.shrink();
        }

        final progress = uploadState.percentage / 100;
        final percentage = uploadState.percentage.toInt();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage%',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A snackbar-style upload progress indicator that can be shown at the bottom.
class UploadProgressSnackbar extends ConsumerWidget {
  const UploadProgressSnackbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadStateAsync = ref.watch(uploadProgressProvider);

    return uploadStateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (uploadState) {
        // Show for in-progress, completed, and failed states
        if (uploadState.status == UploadStatus.pending) {
          return const SizedBox.shrink();
        }

        final isInProgress = uploadState.isInProgress;
        final isCompleted = uploadState.status == UploadStatus.completed;
        final isFailed = uploadState.status == UploadStatus.failed;

        IconData icon;
        Color iconColor;
        String statusText;

        if (isInProgress) {
          icon = Icons.cloud_upload_outlined;
          iconColor = AppColors.primary;
          statusText = uploadState.status == UploadStatus.processing
              ? 'Processing...'
              : '${uploadState.percentage.toInt()}%';
        } else if (isCompleted) {
          icon = Icons.check_circle_outlined;
          iconColor = AppColors.success;
          statusText = 'Uploaded';
        } else if (isFailed) {
          icon = Icons.error_outline;
          iconColor = AppColors.error;
          statusText = 'Failed';
        } else {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isInProgress)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: uploadState.percentage / 100,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                )
              else
                Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uploadState.fileName,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      statusText,
                      style: AppTypography.labelSmall.copyWith(
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
