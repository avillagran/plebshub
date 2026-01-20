import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';
import 'package:zap_widgets/zap_widgets.dart';

import '../../../shared/shared.dart';
import '../models/post.dart';
import '../providers/reply_count_provider.dart';
import 'like_button.dart';
import 'repost_button.dart';

/// A card for displaying posts in a thread view with hierarchy indicators.
///
/// Shows connection lines and indentation based on reply depth.
class ThreadPostCard extends ConsumerWidget {
  const ThreadPostCard({
    super.key,
    required this.post,
    this.depth = 0,
    this.isMainPost = false,
    this.showConnectorAbove = false,
    this.showConnectorBelow = false,
    this.onTap,
    this.onReplyTap,
  });

  /// The post to display.
  final Post post;

  /// Depth level for indentation (0 = root, 1 = direct reply, etc.).
  final int depth;

  /// Whether this is the main/focused post in the thread.
  final bool isMainPost;

  /// Whether to show a connector line above this post.
  final bool showConnectorAbove;

  /// Whether to show a connector line below this post.
  final bool showConnectorBelow;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when reply button is tapped.
  final VoidCallback? onReplyTap;

  /// Maximum indentation depth (deeper replies flatten).
  static const int maxIndentDepth = 3;

  /// Width of each indentation level.
  static const double indentWidth = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveDepth = depth > maxIndentDepth ? maxIndentDepth : depth;
    final leftPadding = effectiveDepth * indentWidth;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isMainPost ? AppColors.surfaceVariant.withOpacity(0.3) : null,
          border: isMainPost
              ? Border(
                  left: BorderSide(
                    color: AppColors.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indentation and connector lines
            if (effectiveDepth > 0) _buildIndentArea(effectiveDepth),
            // Post content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: effectiveDepth > 0 ? 0 : 16,
                  right: 16,
                  top: 12,
                  bottom: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 8),
                    _buildContent(context),
                    const SizedBox(height: 8),
                    _buildActions(context, ref),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the indentation area with connector lines.
  Widget _buildIndentArea(int depth) {
    return SizedBox(
      width: depth * indentWidth,
      child: Row(
        children: List.generate(depth, (index) {
          final isLastLevel = index == depth - 1;
          return SizedBox(
            width: indentWidth,
            child: Center(
              child: Container(
                width: isLastLevel ? 2 : 1,
                color: isLastLevel
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.border.withOpacity(0.3),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Build the post header (avatar, name, time).
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _navigateToProfile(context),
          child: _buildAvatar(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.author.displayName,
                        style: isMainPost
                            ? AppTypography.titleMedium
                            : AppTypography.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (post.author.nip05 != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
                Text(
                  _formatPubkey(post.author.pubkey),
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
          ),
        ),
        Text(
          _formatTime(post.createdAt),
          style: AppTypography.labelSmall,
        ),
      ],
    );
  }

  /// Build the avatar widget.
  Widget _buildAvatar() {
    final size = isMainPost ? 44.0 : 36.0;

    if (post.author.picture != null && post.author.picture!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: post.author.picture!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(size),
          errorWidget: (context, url, error) => _buildAvatarPlaceholder(size),
        ),
      );
    }
    return _buildAvatarPlaceholder(size);
  }

  Widget _buildAvatarPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          post.author.displayName.isNotEmpty
              ? post.author.displayName[0].toUpperCase()
              : '?',
          style: isMainPost ? AppTypography.titleMedium : AppTypography.labelLarge,
        ),
      ),
    );
  }

  /// Build the post content.
  Widget _buildContent(BuildContext context) {
    return NostrContent(
      content: post.content,
      style: isMainPost ? AppTypography.bodyLarge : AppTypography.bodyMedium,
      onMentionTap: (mention) => _handleMentionTap(context, mention),
      onHashtagTap: (hashtag) {
        // TODO: Search for hashtag
      },
    );
  }

  /// Build the action buttons row.
  Widget _buildActions(BuildContext context, WidgetRef ref) {
    final replyCountState = ref.watch(replyCountProvider);
    final replyCount = replyCountState.getReplyCount(post.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Reply button
        InkWell(
          onTap: onReplyTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                if (replyCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$replyCount',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        RepostButton(
          eventId: post.id,
          authorPubkey: post.author.pubkey,
        ),
        LikeButton(
          eventId: post.id,
          authorPubkey: post.author.pubkey,
        ),
        ZapButton(
          recipientPubkey: post.author.pubkey,
          eventId: post.id,
        ),
      ],
    );
  }

  void _navigateToProfile(BuildContext context) {
    context.push('/profile/${post.author.pubkey}');
  }

  void _handleMentionTap(BuildContext context, MentionSegment mention) {
    if (mention.entityType == NostrEntityType.npub ||
        mention.entityType == NostrEntityType.nprofile) {
      final pubkeyFromBech32 = mention.pubkey ?? mention.bech32;
      context.push('/profile/$pubkeyFromBech32');
    } else if (mention.entityType == NostrEntityType.note ||
        mention.entityType == NostrEntityType.nevent) {
      // Navigate to thread view
      final eventId = mention.eventId ?? mention.bech32;
      context.push('/thread/$eventId');
    }
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

/// A compact version of ThreadPostCard for showing parent context.
class ParentContextCard extends StatelessWidget {
  const ParentContextCard({
    super.key,
    required this.post,
    this.onTap,
  });

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withOpacity(0.2),
          border: Border(
            left: BorderSide(
              color: AppColors.border,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.subdirectory_arrow_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.author.displayName,
                        style: AppTypography.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(post.createdAt),
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
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
    } else {
      return '${diff.inDays}d';
    }
  }
}
