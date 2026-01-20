import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../../services/image_precache_service.dart';
import '../../../shared/utils/nostr_content_parser.dart';
import '../models/post.dart';
import '../providers/feed_provider.dart';
import '../providers/reaction_provider.dart';
import '../providers/reply_count_provider.dart';
import '../providers/repost_provider.dart';
import '../widgets/post_card.dart';

/// The main feed screen showing the user's timeline.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Threshold for triggering load more (80% scroll position).
  static const double _loadMoreThreshold = 0.8;

  /// Number of items ahead to precache images for.
  static const int _precacheAhead = 5;

  /// Parser for extracting images from post content.
  static const _contentParser = NostrContentParser();

  /// Image precache service instance.
  final _imagePrecacheService = ImagePrecacheService.instance;

  @override
  void initState() {
    super.initState();

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Load appropriate feed based on auth state
    Future.microtask(() async {
      await _loadFeedForCurrentUser();
      _fetchReactionsForLoadedPosts();
    });
  }

  /// Load the appropriate feed based on authentication state.
  ///
  /// Uses cache-first strategy for instant display:
  /// 1. Loads cached posts immediately
  /// 2. Fetches new posts in background
  /// 3. Shows "X nuevos" button when new posts arrive
  Future<void> _loadFeedForCurrentUser() async {
    final authState = ref.read(authProvider);
    if (authState is AuthStateAuthenticated) {
      // Load following feed for authenticated users
      await ref.read(feedProvider.notifier).loadFollowingFeed(
            userPubkey: authState.keypair.publicKey,
          );
    } else {
      // Load global feed with cache-first strategy
      await ref.read(feedProvider.notifier).loadFeedCacheFirst();
    }
    if (!mounted) return;
  }

  /// Show new posts and scroll to top.
  void _showNewPostsAndScrollToTop() {
    ref.read(feedProvider.notifier).showNewPosts();
    // Scroll to top with animation
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    // Fetch reactions for the newly shown posts
    _fetchReactionsForLoadedPosts();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll events to trigger pagination.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Load more when scrolled past threshold
    if (currentScroll >= maxScroll * _loadMoreThreshold) {
      _loadMorePosts();
    }
  }

  /// Load more posts and fetch their reactions.
  Future<void> _loadMorePosts() async {
    final feedState = ref.read(feedProvider);
    if (feedState is! FeedStateLoaded) return;
    if (feedState.isLoadingMore || !feedState.hasMore) return;

    final previousCount = feedState.posts.length;
    await ref.read(feedProvider.notifier).loadMore();

    // Check if widget is still mounted after async operation
    if (!mounted) return;

    // Fetch reactions for newly loaded posts
    final newState = ref.read(feedProvider);
    if (newState is FeedStateLoaded && newState.posts.length > previousCount) {
      final newPosts = newState.posts.sublist(previousCount);
      final eventIds = newPosts.map((p) => p.id).toList();
      if (eventIds.isNotEmpty) {
        ref.read(reactionProvider.notifier).fetchReactions(eventIds);
        ref.read(repostProvider.notifier).fetchReposts(eventIds);
        ref.read(replyCountProvider.notifier).fetchReplyCounts(eventIds);
      }
    }
  }

  /// Fetch reactions and reposts for all loaded posts.
  void _fetchReactionsForLoadedPosts() {
    final feedState = ref.read(feedProvider);
    if (feedState is FeedStateLoaded) {
      final eventIds = feedState.posts.map((p) => p.id).toList();
      if (eventIds.isNotEmpty) {
        ref.read(reactionProvider.notifier).fetchReactions(eventIds);
        ref.read(repostProvider.notifier).fetchReposts(eventIds);
        ref.read(replyCountProvider.notifier).fetchReplyCounts(eventIds);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(feedProvider.notifier).refresh();
    if (!mounted) return;
    _fetchReactionsForLoadedPosts();
  }

  /// Precache images for nearby posts.
  ///
  /// When building item at index N, this precaches images for items N+1 to N+5.
  /// Images are extracted from post content using [NostrContentParser].
  void _precacheNearbyImages(BuildContext context, int currentIndex, List<Post> posts) {
    final imageUrls = <String>[];

    // Collect image URLs from the next several posts
    final endIndex = (currentIndex + _precacheAhead).clamp(0, posts.length);
    for (var i = currentIndex + 1; i <= endIndex && i < posts.length; i++) {
      final post = posts[i];
      final images = _contentParser.extractImages(post.content);
      imageUrls.addAll(images);
    }

    // Precache the collected images
    if (imageUrls.isNotEmpty) {
      _imagePrecacheService.precacheImages(imageUrls, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    // Listen to auth state changes and reload feed
    ref.listen<AuthState>(authProvider, (previous, next) {
      // When user logs in or logs out, reload the appropriate feed
      if ((previous is! AuthStateAuthenticated && next is AuthStateAuthenticated) ||
          (previous is AuthStateAuthenticated && next is! AuthStateAuthenticated)) {
        Future.microtask(() async {
          if (!mounted) return;
          if (next is AuthStateAuthenticated) {
            // User logged in - load following feed
            await ref.read(feedProvider.notifier).loadFollowingFeed(
                  userPubkey: next.keypair.publicKey,
                );
          } else {
            // User logged out - clear user and load global feed
            ref.read(feedProvider.notifier).clearCurrentUser();
            await ref.read(feedProvider.notifier).loadGlobalFeed();
          }
          if (!mounted) return;
          _fetchReactionsForLoadedPosts();
        });
      }
    });

    // Content is wrapped by MainShell which provides navigation
    return _buildBody(feedState);
  }

  Widget _buildBody(FeedState state) {
    return switch (state) {
      FeedStateInitial() => const Center(
          child: Text('Pull to refresh'),
        ),
      FeedStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      FeedStateError(:final message) => Center(
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
                'Error loading feed',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFeedForCurrentUser,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      FeedStateLoaded(
        :final posts,
        :final isLoadingMore,
        :final hasMore,
        :final newPostsCount,
      ) =>
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: posts.isEmpty
              ? ListView(
                  // Use ListView for empty state to enable pull-to-refresh
                  controller: _scrollController,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Text(
                          'No posts found.\nPull to refresh.',
                          style: AppTypography.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scrollController,
                  // No padding - PostCard handles its own padding
                  padding: EdgeInsets.zero,
                  // Add 1 for new posts button + 1 for loading indicator when loading more
                  itemCount: posts.length +
                      (newPostsCount > 0 ? 1 : 0) +
                      (isLoadingMore ? 1 : (hasMore ? 1 : 0)),
                  itemBuilder: (context, index) {
                    // Show "X nuevos" button at the top when there are new posts
                    if (newPostsCount > 0 && index == 0) {
                      return _buildNewPostsButton(newPostsCount);
                    }

                    // Adjust index if we showed the new posts button
                    final postIndex = newPostsCount > 0 ? index - 1 : index;

                    // Show loading indicator at the bottom
                    if (postIndex >= posts.length) {
                      return _buildLoadMoreIndicator(isLoadingMore, hasMore);
                    }

                    // Precache images for nearby posts
                    _precacheNearbyImages(context, postIndex, posts);

                    final post = posts[postIndex];
                    // PostCard directly, no wrapper - seamless X/Twitter style
                    return PostCard(
                      post: post,
                      // Hide divider on last item before load indicator
                      showDivider: postIndex < posts.length - 1 || isLoadingMore || hasMore,
                    );
                  },
                ),
        ),
    };
  }

  /// Build the loading indicator at the bottom of the list.
  Widget _buildLoadMoreIndicator(bool isLoadingMore, bool hasMore) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (hasMore) {
      // Spacer to indicate more content can be loaded
      return const SizedBox(height: 48);
    }

    // No more posts available
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No more posts',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Build the "X nuevos" button shown when new posts are available.
  Widget _buildNewPostsButton(int count) {
    return GestureDetector(
      onTap: _showNewPostsAndScrollToTop,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),
        child: Center(
          child: Text(
            '$count nuevos',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
