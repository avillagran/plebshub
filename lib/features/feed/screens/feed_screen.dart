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

    // Load global feed on initialization
    Future.microtask(() async {
      await ref.read(feedProvider.notifier).loadGlobalFeed();
      _fetchReactionsForLoadedPosts();
    });
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
      // When user logs in or logs out, reload the feed
      if ((previous is! AuthStateAuthenticated && next is AuthStateAuthenticated) ||
          (previous is AuthStateAuthenticated && next is! AuthStateAuthenticated)) {
        Future.microtask(() async {
          await ref.read(feedProvider.notifier).loadGlobalFeed();
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
                onPressed: () {
                  ref.read(feedProvider.notifier).loadGlobalFeed();
                },
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
                  // Add 1 for loading indicator when loading more
                  itemCount: posts.length + (isLoadingMore ? 1 : (hasMore ? 1 : 0)),
                  itemBuilder: (context, index) {
                    // Show loading indicator at the bottom
                    if (index >= posts.length) {
                      return _buildLoadMoreIndicator(isLoadingMore, hasMore);
                    }

                    // Precache images for nearby posts
                    _precacheNearbyImages(context, index, posts);

                    final post = posts[index];
                    // PostCard directly, no wrapper - seamless X/Twitter style
                    return PostCard(
                      post: post,
                      // Hide divider on last item before load indicator
                      showDivider: index < posts.length - 1 || isLoadingMore || hasMore,
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
}
