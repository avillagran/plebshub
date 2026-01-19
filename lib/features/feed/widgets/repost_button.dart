import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../providers/repost_provider.dart';

/// A button for reposting/boosting a post.
///
/// Shows a repeat icon that toggles color when user has reposted.
/// Displays the repost count next to the icon.
/// Uses optimistic UI updates for immediate feedback.
///
/// Example:
/// ```dart
/// RepostButton(
///   eventId: post.id,
///   authorPubkey: post.author.pubkey,
/// )
/// ```
class RepostButton extends ConsumerWidget {
  const RepostButton({
    super.key,
    required this.eventId,
    required this.authorPubkey,
  });

  /// The ID of the event/post to repost
  final String eventId;

  /// The public key of the event author (for NIP-18 'p' tag)
  final String authorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostState = ref.watch(repostProvider);
    final hasReposted = repostState.hasUserReposted(eventId);
    final count = repostState.getRepostCount(eventId);
    final isPending = repostState.pendingReposts.contains(eventId);

    return InkWell(
      onTap: () {
        ref.read(repostProvider.notifier).toggleRepost(
              eventId: eventId,
              authorPubkey: authorPubkey,
            );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated repeat icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                Icons.repeat,
                key: ValueKey(hasReposted),
                size: 20,
                color: hasReposted
                    ? Colors.green
                    : isPending
                        ? Colors.green.withValues(alpha: 0.5)
                        : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            // Repost count
            Text(
              _formatCount(count),
              style: AppTypography.labelMedium.copyWith(
                color: hasReposted ? Colors.green : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format count for display.
  ///
  /// Shows abbreviated numbers for large counts:
  /// - < 1000: show as-is (e.g., "42")
  /// - >= 1000: show as K (e.g., "1.2K")
  /// - >= 1000000: show as M (e.g., "1.5M")
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0)}K';
    } else {
      final m = count / 1000000;
      return '${m.toStringAsFixed(m < 10 ? 1 : 0)}M';
    }
  }
}
