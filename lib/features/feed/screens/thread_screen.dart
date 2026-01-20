import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../models/post.dart';
import '../providers/thread_provider.dart';
import '../widgets/reply_composer.dart';
import '../widgets/thread_post_card.dart';

/// Screen for displaying a single post with its thread (replies).
///
/// Shows:
/// - Parent context (if the post is a reply)
/// - The main post (expanded)
/// - All replies in a threaded view
/// - Reply composer at the bottom
///
/// If [initialPost] is provided, the post will be displayed immediately
/// while replies load asynchronously.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({
    super.key,
    required this.eventId,
    this.initialPost,
  });

  /// The event ID to display.
  final String eventId;

  /// Optional initial post data to display immediately.
  final Post? initialPost;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  String? _replyingToId;
  String? _replyingToAuthorPubkey;
  String? _replyingToDisplayName;

  @override
  Widget build(BuildContext context) {
    // Use the new provider that supports initial post data
    final params = ThreadInitParams(
      eventId: widget.eventId,
      initialPost: widget.initialPost,
    );
    final threadState = ref.watch(threadProviderWithPost(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(threadState, params),
    );
  }

  Widget _buildBody(ThreadState state, ThreadInitParams params) {
    return switch (state) {
      ThreadStateInitial() => const Center(
          child: Text('Initializing...'),
        ),
      ThreadStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ThreadStateError(:final message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(threadProvider(widget.eventId).notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ThreadStateLoaded(
        :final rootPost,
        :final parentChain,
        :final flattenedReplies,
        :final isLoadingReplies,
      ) =>
        Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(threadProviderWithPost(params).notifier)
                    .refresh(),
                child: CustomScrollView(
                  slivers: [
                    // Parent context header (if exists)
                    if (parentChain.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 12,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.subdirectory_arrow_right,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Parent post',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Parent posts - show full content inline
                    if (parentChain.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = parentChain[index];
                            return Column(
                              children: [
                                ThreadPostCard(
                                  post: post,
                                  showConnectorBelow: true,
                                  onTap: () => context.push(
                                    '/thread/${post.id}',
                                    extra: post,
                                  ),
                                  onReplyTap: () {
                                    setState(() {
                                      _replyingToId = post.id;
                                      _replyingToAuthorPubkey = post.author.pubkey;
                                      _replyingToDisplayName = post.author.displayName;
                                    });
                                  },
                                ),
                                if (index < parentChain.length - 1)
                                  Divider(
                                    height: 1,
                                    color: AppColors.border.withOpacity(0.5),
                                  ),
                              ],
                            );
                          },
                          childCount: parentChain.length,
                        ),
                      ),
                    // Divider between parent and main post
                    if (parentChain.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Divider(
                          height: 1,
                          color: AppColors.border,
                        ),
                      ),
                    // Main post
                    SliverToBoxAdapter(
                      child: ThreadPostCard(
                        post: rootPost,
                        isMainPost: true,
                        onReplyTap: () {
                          setState(() {
                            _replyingToId = rootPost.id;
                            _replyingToAuthorPubkey = rootPost.author.pubkey;
                            _replyingToDisplayName = rootPost.author.displayName;
                          });
                        },
                      ),
                    ),
                    // Divider
                    SliverToBoxAdapter(
                      child: Divider(
                        height: 1,
                        color: AppColors.border,
                      ),
                    ),
                    // Replies section
                    if (isLoadingReplies)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading replies...',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // Replies header
                      if (flattenedReplies.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              '${flattenedReplies.length} ${flattenedReplies.length == 1 ? 'Reply' : 'Replies'}',
                              style: AppTypography.titleSmall,
                            ),
                          ),
                        ),
                      // No replies message
                      if (flattenedReplies.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No replies yet',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to reply!',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final reply = flattenedReplies[index];
                            return Column(
                              children: [
                                ThreadPostCard(
                                  post: reply.post,
                                  depth: reply.depth,
                                  onTap: () => context.push(
                                    '/thread/${reply.post.id}',
                                    extra: reply.post,
                                  ),
                                  onReplyTap: () {
                                    setState(() {
                                      _replyingToId = reply.post.id;
                                      _replyingToAuthorPubkey =
                                          reply.post.author.pubkey;
                                      _replyingToDisplayName =
                                          reply.post.author.displayName;
                                    });
                                  },
                                ),
                                if (index < flattenedReplies.length - 1)
                                  Divider(
                                    height: 1,
                                    indent: reply.depth *
                                        ThreadPostCard.indentWidth,
                                    color: AppColors.border.withOpacity(0.5),
                                  ),
                              ],
                            );
                          },
                          childCount: flattenedReplies.length,
                          ),
                        ),
                    ],
                    // Bottom padding for reply composer
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
              ),
            ),
            // Reply composer
            ReplyComposer(
              threadEventId: widget.eventId,
              replyToId: _replyingToId ?? rootPost.id,
              replyToAuthorPubkey:
                  _replyingToAuthorPubkey ?? rootPost.author.pubkey,
              replyToDisplayName:
                  _replyingToDisplayName ?? rootPost.author.displayName,
              onReplyPublished: () {
                // Reset to replying to root
                setState(() {
                  _replyingToId = null;
                  _replyingToAuthorPubkey = null;
                  _replyingToDisplayName = null;
                });
              },
            ),
          ],
        ),
    };
  }
}
