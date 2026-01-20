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

/// A card displaying a single post/note in X/Twitter style.
///
/// Uses a flat, seamless design with thin dividers between posts.
/// Avatar on left, content on right in a row layout.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.showReplyIndicator = true,
    this.showDivider = true,
  });

  /// The post to display.
  final Post post;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Whether to show the reply indicator if this is a reply.
  final bool showReplyIndicator;

  /// Whether to show the bottom divider.
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => _navigateToThread(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: Avatar
                  GestureDetector(
                    onTap: () => _navigateToProfile(context, post.author.pubkey),
                    child: _buildAvatar(),
                  ),
                  const SizedBox(width: 12),
                  // Right column: Header, content, actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply indicator (if this is a reply)
                        if (showReplyIndicator && post.replyToId != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Replying to a post',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Header: Name, username, time in one line
                        _buildHeader(context),
                        const SizedBox(height: 4),
                        // Content
                        NostrContent(
                          content: post.content,
                          style: AppTypography.bodyMedium,
                          onMentionTap: (mention) =>
                              _handleMentionTap(context, mention),
                          onHashtagTap: (hashtag) {
                            // TODO: Search for hashtag
                          },
                        ),
                        const SizedBox(height: 8),
                        // Link previews
                        _buildLinkPreviews(),
                        const SizedBox(height: 12),
                        // Actions row
                        _buildActionsRow(context, ref),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Thin divider between posts
            if (showDivider)
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  /// Build the header row: Name @username · time
  Widget _buildHeader(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToProfile(context, post.author.pubkey),
      child: Row(
        children: [
          // Display name
          Flexible(
            child: Text(
              post.author.displayName,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Verification badge
          if (post.author.nip05 != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.verified,
              size: 14,
              color: AppColors.success,
            ),
          ],
          const SizedBox(width: 4),
          // Username (pubkey)
          Flexible(
            child: Text(
              '@${_formatPubkey(post.author.pubkey)}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Separator dot
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '·',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Time
          Text(
            _formatTime(post.createdAt),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the actions row (Reply, Repost, Like, Zap) spread evenly.
  Widget _buildActionsRow(BuildContext context, WidgetRef ref) {
    final replyCountState = ref.watch(replyCountProvider);
    final replyCount = replyCountState.getReplyCount(post.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Reply
        _CompactActionButton(
          icon: Icons.chat_bubble_outline,
          count: replyCount,
          onTap: () => _navigateToThread(context),
        ),
        // Repost
        RepostButton(
          eventId: post.id,
          authorPubkey: post.author.pubkey,
        ),
        // Like
        LikeButton(
          eventId: post.id,
          authorPubkey: post.author.pubkey,
        ),
        // Zap
        ZapButton(
          recipientPubkey: post.author.pubkey,
          eventId: post.id,
        ),
      ],
    );
  }

  /// Build the avatar widget with profile picture support.
  Widget _buildAvatar() {
    if (post.author.picture != null && post.author.picture!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: post.author.picture!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(),
          errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
        ),
      );
    }
    return _buildAvatarPlaceholder();
  }

  /// Build avatar placeholder with initial letter.
  Widget _buildAvatarPlaceholder() {
    return Container(
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
          style: AppTypography.titleLarge.copyWith(fontSize: 16),
        ),
      ),
    );
  }

  /// Navigate to a user's profile.
  void _navigateToProfile(BuildContext context, String pubkey) {
    context.push('/profile/$pubkey');
  }

  /// Navigate to the thread view for this post.
  void _navigateToThread(BuildContext context) {
    context.push('/thread/${post.id}', extra: post);
  }

  /// Handle mention tap - navigate to profile or note.
  void _handleMentionTap(BuildContext context, MentionSegment mention) {
    if (mention.entityType == NostrEntityType.npub ||
        mention.entityType == NostrEntityType.nprofile) {
      final pubkeyFromBech32 = mention.pubkey ?? mention.bech32;
      context.push('/profile/$pubkeyFromBech32');
    } else if (mention.entityType == NostrEntityType.note ||
        mention.entityType == NostrEntityType.nevent) {
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

  /// Build link preview cards for URLs in the post content.
  Widget _buildLinkPreviews() {
    // Parse content to extract URL segments
    const parser = NostrContentParser();
    final segments = parser.parse(post.content);

    // Extract URLs that are not images or videos
    final urlSegments = segments.whereType<UrlSegment>().toList();

    // Limit to max 2 link previews to avoid clutter
    final previewUrls = urlSegments.take(2).map((s) => s.url).toList();

    if (previewUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final url in previewUrls) ...[
          LinkPreviewWidget(url: url),
          if (url != previewUrls.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// A compact action button for the X-style action row.
class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
