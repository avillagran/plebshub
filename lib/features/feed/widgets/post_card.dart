import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'package:zap_widgets/zap_widgets.dart';

import '../models/post.dart';

/// A card displaying a single post/note.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  /// The post to display.
  final Post post;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, name, pubkey, time
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    post.author.displayName.isNotEmpty
                        ? post.author.displayName[0].toUpperCase()
                        : '?',
                    style: AppTypography.titleLarge,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and pubkey
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName,
                      style: AppTypography.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatPubkey(post.author.pubkey),
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ),
              // Time
              Text(
                _formatTime(post.createdAt),
                style: AppTypography.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(
            post.content,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Actions: Reply, Repost, Like, Zap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${post.reactionsCount}',
                onTap: () {
                  // TODO: Open reply
                },
              ),
              _ActionButton(
                icon: Icons.repeat,
                label: '${post.repostsCount}',
                onTap: () {
                  // TODO: Repost
                },
              ),
              _ActionButton(
                icon: Icons.favorite_border,
                label: '${post.reactionsCount}',
                onTap: () {
                  // TODO: Like
                },
              ),
              ZapButton(
                recipientPubkey: post.author.pubkey,
                eventId: post.id,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
