import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/image_precache_service.dart';
import '../../../shared/shared.dart';
import '../../profile/models/profile.dart';
import '../models/post.dart';
import '../providers/explore_feed_provider.dart';
import '../providers/reaction_provider.dart';
import '../providers/reply_count_provider.dart';
import '../providers/repost_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/search_bar.dart';

/// The explore screen showing global feed and search functionality.
///
/// Features:
/// - Search bar with filter chips at the top
/// - Search results when searching
/// - Global feed when not searching
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
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

    // Load global explore feed on initialization
    Future.microtask(() async {
      await ref.read(exploreFeedProvider.notifier).loadGlobalFeed();
      if (!mounted) return;
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
    final feedState = ref.read(exploreFeedProvider);
    if (feedState is! ExploreFeedStateLoaded) return;
    if (feedState.isLoadingMore || !feedState.hasMore) return;

    final previousCount = feedState.posts.length;
    await ref.read(exploreFeedProvider.notifier).loadMore();

    // Check if widget is still mounted after async operation
    if (!mounted) return;

    // Fetch reactions for newly loaded posts
    final newState = ref.read(exploreFeedProvider);
    if (newState is ExploreFeedStateLoaded &&
        newState.posts.length > previousCount) {
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
    final feedState = ref.read(exploreFeedProvider);
    if (feedState is ExploreFeedStateLoaded) {
      final eventIds = feedState.posts.map((p) => p.id).toList();
      if (eventIds.isNotEmpty) {
        ref.read(reactionProvider.notifier).fetchReactions(eventIds);
        ref.read(repostProvider.notifier).fetchReposts(eventIds);
        ref.read(replyCountProvider.notifier).fetchReplyCounts(eventIds);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(exploreFeedProvider.notifier).refresh();
    if (!mounted) return;
    _fetchReactionsForLoadedPosts();
  }

  /// Precache images for nearby posts.
  void _precacheNearbyImages(
      BuildContext context, int currentIndex, List<Post> posts) {
    final imageUrls = <String>[];

    final endIndex = (currentIndex + _precacheAhead).clamp(0, posts.length);
    for (var i = currentIndex + 1; i <= endIndex && i < posts.length; i++) {
      final post = posts[i];
      final images = _contentParser.extractImages(post.content);
      imageUrls.addAll(images);
    }

    if (imageUrls.isNotEmpty) {
      _imagePrecacheService.precacheImages(imageUrls, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return ResponsiveContent(
      child: Column(
        children: [
          // Search bar at the top
          const ExploreSearchBar(),

          // Content area: either search results or global feed
          Expanded(
            child: _buildContent(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SearchState searchState) {
    // Show search results if search is active
    if (searchState is SearchStateLoading) {
      return _buildSearchLoading(searchState);
    }

    if (searchState is SearchStateLoaded) {
      return _buildSearchResults(searchState);
    }

    if (searchState is SearchStateError) {
      return _buildSearchError(searchState);
    }

    // Default: show global feed
    return _buildExploreFeed();
  }

  Widget _buildSearchLoading(SearchStateLoading state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Searching for "${state.query}"...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(SearchStateLoaded state) {
    final hasPosts = state.posts.isNotEmpty;
    final hasUsers = state.users.isNotEmpty;

    if (!hasPosts && !hasUsers) {
      return _buildEmptySearchResults(state.query);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(searchProvider.notifier).search(state.query);
      },
      child: ListView(
        controller: _scrollController,
        children: [
          // Users section (if any)
          if (hasUsers) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Users',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...state.users.map((user) => _UserSearchResult(user: user)),
            const Divider(),
          ],

          // Posts section (if any)
          if (hasPosts) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Posts',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...state.posts.asMap().entries.map((entry) {
              final index = entry.key;
              final post = entry.value;
              _precacheNearbyImages(context, index, state.posts);
              return PostCard(
                post: post,
                showDivider: index < state.posts.length - 1,
              );
            }),
          ],

          // Show "more results available" hint
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'More results may be available. Try refining your search.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchResults(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No posts or users match "$query"',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Try searching for something else or check the spelling.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchError(SearchStateError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(searchProvider.notifier).search(state.query);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreFeed() {
    final feedState = ref.watch(exploreFeedProvider);

    return switch (feedState) {
      ExploreFeedStateInitial() => const Center(
          child: Text('Pull to refresh'),
        ),
      ExploreFeedStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ExploreFeedStateError(:final message) => Center(
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
                  ref.read(exploreFeedProvider.notifier).loadGlobalFeed();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ExploreFeedStateLoaded(
        :final posts,
        :final isLoadingMore,
        :final hasMore,
      ) =>
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: posts.isEmpty
              ? ListView(
                  controller: _scrollController,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
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
                  padding: EdgeInsets.zero,
                  itemCount:
                      posts.length + (isLoadingMore ? 1 : (hasMore ? 1 : 0)),
                  itemBuilder: (context, index) {
                    if (index >= posts.length) {
                      return _buildLoadMoreIndicator(isLoadingMore, hasMore);
                    }

                    _precacheNearbyImages(context, index, posts);

                    final post = posts[index];
                    return PostCard(
                      post: post,
                      showDivider:
                          index < posts.length - 1 || isLoadingMore || hasMore,
                    );
                  },
                ),
        ),
    };
  }

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
      return const SizedBox(height: 48);
    }

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

/// A widget displaying a user search result.
class _UserSearchResult extends StatelessWidget {
  const _UserSearchResult({required this.user});

  final Profile user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: Text(
        user.nameForDisplay,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.nip05 != null)
            Text(
              user.nip05!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          if (user.about != null && user.about!.isNotEmpty)
            Text(
              user.about!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      onTap: () => context.push('/profile/${user.pubkey}'),
    );
  }

  Widget _buildAvatar() {
    if (user.picture != null && user.picture!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: user.picture!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(),
          errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
        ),
      );
    }
    return _buildAvatarPlaceholder();
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          user.nameForDisplay.isNotEmpty
              ? user.nameForDisplay[0].toUpperCase()
              : '?',
          style: AppTypography.titleLarge.copyWith(fontSize: 18),
        ),
      ),
    );
  }
}
