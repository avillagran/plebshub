import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/shared.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/channel_message.dart';

/// A widget that displays a single message in a channel chat.
///
/// Shows:
/// - Author avatar and name
/// - Message content using NostrContent widget
/// - Timestamp
/// - Reply indicator (if replying to another message)
class ChannelMessageBubble extends ConsumerWidget {
  const ChannelMessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.isOwnMessage = false,
  });

  /// The message to display.
  final ChannelMessage message;

  /// Callback when the reply button is tapped.
  final VoidCallback? onReply;

  /// Whether this message was sent by the current user.
  final bool isOwnMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(message.authorPubkey));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: profileAsync.when(
              data: (profile) => _buildAvatar(profile.picture, profile.nameForDisplay),
              loading: () => _buildAvatarPlaceholder(),
              error: (_, __) => _buildAvatarPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: name and time
                Row(
                  children: [
                    // Author name
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _navigateToProfile(context),
                        child: profileAsync.when(
                          data: (profile) => Text(
                            profile.nameForDisplay,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isOwnMessage
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          loading: () => Text(
                            _truncatePubkey(message.authorPubkey),
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          error: (_, __) => Text(
                            _truncatePubkey(message.authorPubkey),
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Timestamp
                    Text(
                      _formatTime(message.createdAt),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // Reply indicator
                if (message.isReply) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Replying to a message',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 4),

                // Message content
                NostrContent(
                  content: message.content,
                  style: AppTypography.bodyMedium,
                  onMentionTap: (mention) => _handleMentionTap(context, mention),
                ),

                // Reply button
                if (onReply != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onReply,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? pictureUrl, String displayName) {
    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      return ClipOval(
        child: SmartImage(
          imageUrl: pictureUrl,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(displayName),
          errorWidget: (context, url, error) =>
              _buildAvatarPlaceholder(displayName),
        ),
      );
    }
    return _buildAvatarPlaceholder(displayName);
  }

  Widget _buildAvatarPlaceholder([String? displayName]) {
    final initial = displayName?.isNotEmpty == true
        ? displayName![0].toUpperCase()
        : message.authorPubkey.isNotEmpty
            ? message.authorPubkey[0].toUpperCase()
            : '?';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.titleMedium.copyWith(fontSize: 14),
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    context.push('/profile/${message.authorPubkey}');
  }

  void _handleMentionTap(BuildContext context, MentionSegment mention) {
    if (mention.entityType == NostrEntityType.npub ||
        mention.entityType == NostrEntityType.nprofile) {
      final pubkey = mention.pubkey ?? mention.bech32;
      context.push('/profile/$pubkey');
    } else if (mention.entityType == NostrEntityType.note ||
        mention.entityType == NostrEntityType.nevent) {
      final eventId = mention.eventId ?? mention.bech32;
      context.push('/thread/$eventId');
    }
  }

  String _truncatePubkey(String pubkey) {
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
      // Show time for older messages
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
