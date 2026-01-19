import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'package:zap_widgets/zap_widgets.dart';

/// A card displaying a single post/note.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.authorName,
    required this.authorPubkey,
    required this.content,
    required this.createdAt,
    this.eventId,
    this.onTap,
  });

  /// The author's display name.
  final String authorName;

  /// The author's Nostr public key.
  final String authorPubkey;

  /// The post content.
  final String content;

  /// When the post was created.
  final DateTime createdAt;

  /// The event ID (for replies, zaps, etc.).
  final String? eventId;

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
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
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
                      authorName,
                      style: AppTypography.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatPubkey(authorPubkey),
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ),
              // Time
              Text(
                _formatTime(createdAt),
                style: AppTypography.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(
            content,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Actions: Reply, Repost, Like, Zap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '0',
                onTap: () {
                  // TODO: Open reply
                },
              ),
              _ActionButton(
                icon: Icons.repeat,
                label: '0',
                onTap: () {
                  // TODO: Repost
                },
              ),
              _ActionButton(
                icon: Icons.favorite_border,
                label: '0',
                onTap: () {
                  // TODO: Like
                },
              ),
              ZapButton(
                recipientPubkey: authorPubkey,
                eventId: eventId,
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
