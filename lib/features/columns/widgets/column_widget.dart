import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/image_precache_service.dart';
import '../../../services/key_service.dart';
import '../../../services/profile_service.dart';
import '../../../shared/shared.dart' hide ColumnConfig;
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../channels/models/channel.dart';
import '../../channels/models/channel_message.dart';
import '../../channels/providers/channel_provider.dart';
import '../../channels/widgets/channel_message_bubble.dart';
import '../../feed/models/post.dart';
import '../../feed/providers/explore_feed_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../../feed/providers/reaction_provider.dart';
import '../../feed/providers/reply_count_provider.dart';
import '../../feed/providers/repost_provider.dart';
import '../../feed/widgets/post_card.dart';
import '../../notifications/models/notification_item.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../profile/models/profile.dart';
import '../models/column_config.dart';

/// A widget that renders a column with content based on its configuration.
///
/// Each column displays:
/// - A header with an icon, title, and options menu
/// - Scrollable content based on the column type
///
/// Structure:
/// ```
/// +---------------------+
/// | [Icon] Title    [:] |  <- Header with menu
/// +---------------------+
/// |                     |
/// |   Content based     |  <- Scrollable content
/// |   on column type    |
/// |                     |
/// +---------------------+
/// ```
///
/// Supported content types:
/// - `home` -> Following feed using FeedProvider
/// - `explore` -> Global feed using ExploreFeedProvider
/// - `channel` -> Channel chat messages
/// - Others -> Coming soon placeholder
class ColumnWidget extends ConsumerWidget {
  /// Creates a column widget.
  const ColumnWidget({
    super.key,
    required this.config,
    this.onRemove,
    this.onSettings,
  });

  /// The configuration for this column.
  final ColumnConfig config;

  /// Callback when the user requests to remove this column.
  final VoidCallback? onRemove;

  /// Callback when the user requests to open column settings.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: theme.shadowColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          _ColumnHeader(
            config: config,
            onRemove: onRemove,
            onSettings: onSettings,
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.3),
          ),

          // Content
          Expanded(
            child: _buildContent(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (config.type) {
      case ColumnType.home:
        return _HomeFeedContent(config: config);
      case ColumnType.explore:
        return _ExploreFeedContent(config: config);
      case ColumnType.channel:
        return _ChannelContent(config: config);
      case ColumnType.user:
        return _UserFeedContent(config: config);
      case ColumnType.hashtag:
        return _ComingSoonPlaceholder(config: config);
      case ColumnType.notifications:
        return _NotificationsContent(config: config);
      case ColumnType.messages:
      case ColumnType.search:
        return _ComingSoonPlaceholder(config: config);
    }
  }
}

/// Header widget for a column with icon, title, and menu.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.config,
    this.onRemove,
    this.onSettings,
  });

  final ColumnConfig config;
  final VoidCallback? onRemove;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          // Icon
          Icon(
            config.icon,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              config.displayTitle,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Menu button
          PopupMenuButton<_ColumnMenuAction>(
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: AppColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            onSelected: (action) {
              switch (action) {
                case _ColumnMenuAction.settings:
                  onSettings?.call();
                case _ColumnMenuAction.remove:
                  onRemove?.call();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ColumnMenuAction.settings,
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ColumnMenuAction.remove,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remove',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Menu actions available for a column.
enum _ColumnMenuAction {
  settings,
  remove,
}

/// Content widget for the home feed column.
class _HomeFeedContent extends ConsumerStatefulWidget {
  const _HomeFeedContent({required this.config});

  final ColumnConfig config;

  @override
  ConsumerState<_HomeFeedContent> createState() => _HomeFeedContentState();
}

class _HomeFeedContentState extends ConsumerState<_HomeFeedContent> {
  final ScrollController _scrollController = ScrollController();
  static const double _loadMoreThreshold = 0.8;
  static const int _precacheAhead = 5;
  static const _contentParser = NostrContentParser();
  final _imagePrecacheService = ImagePrecacheService.instance;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadFeed());
  }

  @override
  void dispose() {
    _mounted = false;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (!_mounted) return;
    final authState = ref.read(authProvider);
    if (authState is AuthStateAuthenticated) {
      await ref.read(feedProvider.notifier).loadFollowingFeed(
            userPubkey: authState.keypair.publicKey,
          );
    } else {
      await ref.read(feedProvider.notifier).loadFeedCacheFirst();
    }
    if (!_mounted) return;
    _fetchReactions();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll * _loadMoreThreshold) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_mounted) return;
    final feedState = ref.read(feedProvider);
    if (feedState is! FeedStateLoaded) return;
    if (feedState.isLoadingMore || !feedState.hasMore) return;

    final previousCount = feedState.posts.length;
    await ref.read(feedProvider.notifier).loadMore();

    if (!_mounted) return;

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

  void _fetchReactions() {
    if (!_mounted) return;
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
    if (!_mounted) return;
    _fetchReactions();
  }

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

  void _showNewPostsAndScrollToTop() {
    ref.read(feedProvider.notifier).showNewPosts();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _fetchReactions();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return _buildFeedBody(feedState);
  }

  Widget _buildFeedBody(FeedState state) {
    return switch (state) {
      FeedStateInitial() => const Center(
          child: Text('Pull to refresh'),
        ),
      FeedStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      FeedStateError(:final message) => _buildErrorState(message),
      FeedStateLoaded(
        :final posts,
        :final isLoadingMore,
        :final hasMore,
        :final newPostsCount,
      ) =>
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: posts.isEmpty
              ? _buildEmptyState()
              : _buildPostsList(posts, isLoadingMore, hasMore, newPostsCount),
        ),
    };
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading feed',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Text(
              'No posts found.\nPull to refresh.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsList(
    List<Post> posts,
    bool isLoadingMore,
    bool hasMore,
    int newPostsCount,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
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
        return PostCard(
          post: post,
          showDivider: postIndex < posts.length - 1 || isLoadingMore || hasMore,
        );
      },
    );
  }

  Widget _buildNewPostsButton(int count) {
    return GestureDetector(
      onTap: _showNewPostsAndScrollToTop,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(bool isLoadingMore, bool hasMore) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasMore) {
      return const SizedBox(height: 40);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No more posts',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Content widget for the explore feed column.
class _ExploreFeedContent extends ConsumerStatefulWidget {
  const _ExploreFeedContent({required this.config});

  final ColumnConfig config;

  @override
  ConsumerState<_ExploreFeedContent> createState() =>
      _ExploreFeedContentState();
}

class _ExploreFeedContentState extends ConsumerState<_ExploreFeedContent> {
  final ScrollController _scrollController = ScrollController();
  static const double _loadMoreThreshold = 0.8;
  static const int _precacheAhead = 5;
  static const _contentParser = NostrContentParser();
  final _imagePrecacheService = ImagePrecacheService.instance;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadFeed());
  }

  @override
  void dispose() {
    _mounted = false;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (!_mounted) return;
    await ref.read(exploreFeedProvider.notifier).loadGlobalFeed();
    if (!_mounted) return;
    _fetchReactions();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll * _loadMoreThreshold) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_mounted) return;
    final feedState = ref.read(exploreFeedProvider);
    if (feedState is! ExploreFeedStateLoaded) return;
    if (feedState.isLoadingMore || !feedState.hasMore) return;

    final previousCount = feedState.posts.length;
    await ref.read(exploreFeedProvider.notifier).loadMore();

    if (!_mounted) return;

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

  void _fetchReactions() {
    if (!_mounted) return;
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
    if (!_mounted) return;
    _fetchReactions();
  }

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

  void _showNewPostsAndScrollToTop() {
    ref.read(exploreFeedProvider.notifier).showNewPosts();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _fetchReactions();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(exploreFeedProvider);

    return _buildFeedBody(feedState);
  }

  Widget _buildFeedBody(ExploreFeedState state) {
    return switch (state) {
      ExploreFeedStateInitial() => const Center(
          child: Text('Pull to refresh'),
        ),
      ExploreFeedStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ExploreFeedStateError(:final message) => _buildErrorState(message),
      ExploreFeedStateLoaded(
        :final posts,
        :final isLoadingMore,
        :final hasMore,
        :final newPostsCount,
      ) =>
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: posts.isEmpty
              ? _buildEmptyState()
              : _buildPostsList(posts, isLoadingMore, hasMore, newPostsCount),
        ),
    };
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading feed',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Text(
              'No posts found.\nPull to refresh.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsList(
    List<Post> posts,
    bool isLoadingMore,
    bool hasMore,
    int newPostsCount,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
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

        _precacheNearbyImages(context, postIndex, posts);

        final post = posts[postIndex];
        return PostCard(
          post: post,
          showDivider: postIndex < posts.length - 1 || isLoadingMore || hasMore,
        );
      },
    );
  }

  Widget _buildNewPostsButton(int count) {
    return GestureDetector(
      onTap: _showNewPostsAndScrollToTop,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(bool isLoadingMore, bool hasMore) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasMore) {
      return const SizedBox(height: 40);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No more posts',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Content widget for a user feed column.
///
/// Displays posts from a specific user with their profile header at the top.
/// Uses cache-first pattern for efficient loading.
class _UserFeedContent extends ConsumerStatefulWidget {
  const _UserFeedContent({required this.config});

  final ColumnConfig config;

  @override
  ConsumerState<_UserFeedContent> createState() => _UserFeedContentState();
}

class _UserFeedContentState extends ConsumerState<_UserFeedContent> {
  final ScrollController _scrollController = ScrollController();
  static const double _loadMoreThreshold = 0.8;
  static const int _precacheAhead = 5;
  static const _contentParser = NostrContentParser();
  final _imagePrecacheService = ImagePrecacheService.instance;
  final _profileService = ProfileService.instance;
  final _keyService = KeyService();
  bool _mounted = true;

  // State
  Profile? _profile;
  List<Post> _posts = [];
  List<Post> _pendingNewPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  /// Resolved hex pubkey (from npub or hex input)
  String? _resolvedPubkey;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadUserFeed());
  }

  @override
  void dispose() {
    _mounted = false;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Resolve the pubkey from the config (handles both npub and hex formats).
  String? _resolvePubkey() {
    final userPubkey = widget.config.userPubkey;
    if (userPubkey == null || userPubkey.isEmpty) return null;

    // If it's an npub, convert to hex
    if (userPubkey.startsWith('npub1')) {
      try {
        return _keyService.npubToPublicKey(userPubkey);
      } catch (e) {
        debugPrint('Invalid npub: $e');
        return null;
      }
    }

    // Assume it's already a hex pubkey
    if (userPubkey.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(userPubkey)) {
      return userPubkey.toLowerCase();
    }

    return null;
  }

  Future<void> _loadUserFeed() async {
    if (!_mounted) return;

    _resolvedPubkey = _resolvePubkey();
    if (_resolvedPubkey == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid user pubkey or npub';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch profile and posts in parallel
      final results = await Future.wait([
        _profileService.fetchProfile(_resolvedPubkey!),
        _profileService.fetchUserPosts(_resolvedPubkey!, limit: 30),
      ]);

      if (!_mounted) return;

      final profile = results[0] as Profile;
      final postEvents = results[1] as List<Nip01Event>;

      // Convert events to posts
      final posts = postEvents.map((event) => _convertToPost(event, profile)).toList();

      setState(() {
        _profile = profile;
        _posts = posts;
        _isLoading = false;
        _hasMore = posts.length >= 30;
      });

      // Fetch reactions for loaded posts
      _fetchReactions(posts);
    } catch (e) {
      debugPrint('Error loading user feed: $e');
      if (!_mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load user feed: ${e.toString()}';
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll * _loadMoreThreshold) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_mounted || _isLoadingMore || !_hasMore || _resolvedPubkey == null || _profile == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get the timestamp of the last post for pagination
      final lastPost = _posts.isNotEmpty ? _posts.last : null;
      final until = lastPost?.createdAt;

      final postEvents = await _profileService.fetchUserPosts(
        _resolvedPubkey!,
        limit: 30,
        until: until,
      );

      if (!_mounted) return;

      // Filter out posts we already have
      final existingIds = _posts.map((p) => p.id).toSet();
      final newPostEvents = postEvents.where((e) => !existingIds.contains(e.id)).toList();

      if (newPostEvents.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      final newPosts = newPostEvents.map((event) => _convertToPost(event, _profile!)).toList();

      setState(() {
        _posts = [..._posts, ...newPosts];
        _isLoadingMore = false;
        _hasMore = newPosts.length >= 30;
      });

      // Fetch reactions for new posts
      _fetchReactions(newPosts);
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      if (!_mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _fetchReactions(List<Post> posts) {
    if (posts.isEmpty) return;

    final eventIds = posts.map((p) => p.id).toList();
    ref.read(reactionProvider.notifier).fetchReactions(eventIds);
    ref.read(repostProvider.notifier).fetchReposts(eventIds);
    ref.read(replyCountProvider.notifier).fetchReplyCounts(eventIds);
  }

  Future<void> _handleRefresh() async {
    if (_resolvedPubkey == null) return;

    // Clear profile cache to get fresh data
    await _profileService.clearFromCache(_resolvedPubkey!);
    await _loadUserFeed();
  }

  void _precacheNearbyImages(BuildContext context, int currentIndex, List<Post> posts) {
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

  void _showNewPostsAndScrollToTop() {
    if (_pendingNewPosts.isEmpty) return;

    setState(() {
      _posts = [..._pendingNewPosts, ..._posts];
      _pendingNewPosts = [];
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    _fetchReactions(_posts.take(30).toList());
  }

  /// Convert a Nostr event to a Post model.
  Post _convertToPost(Nip01Event event, Profile author) {
    String? replyToId;
    String? rootEventId;

    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e') {
        if (tag.length > 3) {
          final marker = tag[3];
          if (marker == 'reply') {
            replyToId = tag[1];
          } else if (marker == 'root') {
            rootEventId = tag[1];
          }
        } else if (replyToId == null) {
          replyToId = tag[1];
        }
      }
    }

    return Post(
      id: event.id,
      author: PostAuthor(
        pubkey: event.pubKey,
        displayName: author.nameForDisplay,
        nip05: author.nip05,
        picture: author.picture,
        about: author.about,
      ),
      content: event.content,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      replyToId: replyToId,
      rootEventId: rootEventId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_profile == null) {
      return _buildErrorState('User not found');
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Compact profile header
          SliverToBoxAdapter(
            child: _buildCompactProfileHeader(),
          ),

          // Divider
          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.3),
            ),
          ),

          // New posts button
          if (_pendingNewPosts.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildNewPostsButton(_pendingNewPosts.length),
            ),

          // Posts list
          if (_posts.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _posts.length) {
                    return _buildLoadMoreIndicator();
                  }

                  _precacheNearbyImages(context, index, _posts);

                  final post = _posts[index];
                  return PostCard(
                    post: post,
                    showDivider: index < _posts.length - 1 || _isLoadingMore || _hasMore,
                  );
                },
                childCount: _posts.length + (_isLoadingMore || _hasMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactProfileHeader() {
    final profile = _profile!;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar
          ClipOval(
            child: profile.picture != null && profile.picture!.isNotEmpty
                ? SmartImage(
                    imageUrl: profile.picture!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildAvatarPlaceholder(profile),
                    errorWidget: (context, url, error) => _buildAvatarPlaceholder(profile),
                  )
                : _buildAvatarPlaceholder(profile),
          ),

          const SizedBox(width: 12),

          // Name and username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.nameForDisplay,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.nip05 != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  profile.atUsername,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Post count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_posts.length} posts',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(Profile profile) {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surfaceVariant,
      child: Center(
        child: Text(
          profile.nameForDisplay.isNotEmpty
              ? profile.nameForDisplay[0].toUpperCase()
              : '?',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading user',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUserFeed,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No posts yet',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This user has not posted anything.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPostsButton(int count) {
    return GestureDetector(
      onTap: _showNewPostsAndScrollToTop,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasMore) {
      return const SizedBox(height: 40);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No more posts',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Content widget for a channel column.
class _ChannelContent extends ConsumerStatefulWidget {
  const _ChannelContent({required this.config});

  final ColumnConfig config;

  @override
  ConsumerState<_ChannelContent> createState() => _ChannelContentState();
}

class _ChannelContentState extends ConsumerState<_ChannelContent> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isAtBottom = true;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadChannel());
  }

  @override
  void dispose() {
    _mounted = false;
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _channelId => widget.config.channelId ?? widget.config.id;

  void _loadChannel() {
    if (!_mounted) return;
    final channel = Channel(
      id: _channelId,
      name: widget.config.title ?? 'Channel',
      creatorPubkey: '',
      createdAt: DateTime.now(),
    );
    ref.read(channelChatProvider(_channelId).notifier).loadChannel(channel);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!_mounted) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    _isAtBottom = currentScroll >= maxScroll - 50;

    if (currentScroll <= 100) {
      ref.read(channelChatProvider(_channelId).notifier).loadMoreMessages();
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_mounted) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) return;

    _messageController.clear();

    final success = await ref
        .read(channelChatProvider(_channelId).notifier)
        .sendMessage(content: content);

    if (!_mounted) return;
    if (success) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(channelChatProvider(_channelId));
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is AuthStateAuthenticated;
    final currentUserPubkey = authState is AuthStateAuthenticated
        ? authState.keypair.publicKey
        : null;

    // Auto-scroll when new messages arrive
    ref.listen<ChannelChatState>(
      channelChatProvider(_channelId),
      (previous, next) {
        if (previous is ChannelChatStateLoaded &&
            next is ChannelChatStateLoaded &&
            next.messages.length > previous.messages.length) {
          if (_isAtBottom) {
            _scrollToBottom();
          }
        }
      },
    );

    return _buildBody(chatState, currentUserPubkey, isAuthenticated);
  }

  Widget _buildBody(
    ChannelChatState state,
    String? currentUserPubkey,
    bool isAuthenticated,
  ) {
    return switch (state) {
      ChannelChatStateInitial() => const Center(
          child: Text('Loading...'),
        ),
      ChannelChatStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ChannelChatStateError(:final message) => _buildErrorState(message),
      ChannelChatStateLoaded(
        :final messages,
        :final isLoadingMore,
        :final isSending,
      ) =>
        Column(
          children: [
            Expanded(
              child: _buildMessagesList(
                messages,
                isLoadingMore,
                currentUserPubkey,
              ),
            ),
            _buildMessageComposer(isAuthenticated, isSending),
          ],
        ),
    };
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading channel',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadChannel,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(
    List<ChannelMessage> messages,
    bool isLoadingMore,
    String? currentUserPubkey,
  ) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to say something!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (isLoadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final messageIndex = isLoadingMore ? index - 1 : index;
        final message = messages[messageIndex];
        final isOwnMessage = currentUserPubkey != null &&
            message.authorPubkey == currentUserPubkey;

        return ChannelMessageBubble(
          message: message,
          isOwnMessage: isOwnMessage,
        );
      },
    );
  }

  Widget _buildMessageComposer(bool isAuthenticated, bool isSending) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 3,
              minLines: 1,
              enabled: isAuthenticated && !isSending,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: isAuthenticated
                    ? 'Type a message...'
                    : 'Log in to send messages',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          if (isSending)
            const Padding(
              padding: EdgeInsets.all(6),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: isAuthenticated &&
                      _messageController.text.trim().isNotEmpty
                  ? _sendMessage
                  : null,
              icon: Icon(
                Icons.send,
                size: 20,
                color:
                    isAuthenticated && _messageController.text.trim().isNotEmpty
                        ? AppColors.primary
                        : AppColors.textSecondary,
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder widget for column types that are not yet implemented.
class _ComingSoonPlaceholder extends StatelessWidget {
  const _ComingSoonPlaceholder({required this.config});

  final ColumnConfig config;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              config.icon,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Coming Soon',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${config.displayTitle} column is not yet available.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Content widget for the notifications column.
class _NotificationsContent extends ConsumerStatefulWidget {
  const _NotificationsContent({required this.config});

  final ColumnConfig config;

  @override
  ConsumerState<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends ConsumerState<_NotificationsContent> {
  final ScrollController _scrollController = ScrollController();
  static const double _loadMoreThreshold = 0.8;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadNotifications());
  }

  @override
  void dispose() {
    _mounted = false;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!_mounted) return;

    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      return;
    }

    await ref.read(notificationsProvider.notifier).loadNotifications(
          userPubkey: authState.keypair.publicKey,
        );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll * _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_mounted) return;

    final notificationsState = ref.read(notificationsProvider);
    if (notificationsState is! NotificationsStateLoaded) return;
    if (notificationsState.isLoadingMore || !notificationsState.hasMore) return;

    await ref.read(notificationsProvider.notifier).loadMore();
  }

  Future<void> _handleRefresh() async {
    await ref.read(notificationsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final notificationsState = ref.watch(notificationsProvider);

    // Check if user is authenticated
    if (authState is! AuthStateAuthenticated) {
      return _buildNotAuthenticatedState();
    }

    return _buildNotificationsBody(notificationsState);
  }

  Widget _buildNotAuthenticatedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign In Required',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to view your notifications.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsBody(NotificationsState state) {
    return switch (state) {
      NotificationsStateInitial() => const Center(
          child: Text('Pull to refresh'),
        ),
      NotificationsStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      NotificationsStateError(:final message) => _buildErrorState(message),
      NotificationsStateLoaded(
        :final notifications,
        :final isLoadingMore,
        :final hasMore,
      ) =>
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(notifications, isLoadingMore, hasMore),
        ),
    };
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading notifications',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No notifications yet',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'When someone mentions, replies, or\nreacts to your posts, you\'ll see it here.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsList(
    List<NotificationItem> notifications,
    bool isLoadingMore,
    bool hasMore,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: notifications.length + (isLoadingMore ? 1 : (hasMore ? 1 : 0)),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index >= notifications.length) {
          return _buildLoadMoreIndicator(isLoadingMore, hasMore);
        }

        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          showDivider: index < notifications.length - 1 || isLoadingMore || hasMore,
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator(bool isLoadingMore, bool hasMore) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasMore) {
      return const SizedBox(height: 40);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No more notifications',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// A single notification tile displaying the notification type, author, and content.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    this.showDivider = true,
  });

  final NotificationItem notification;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            // TODO: Navigate to the notification target (post/profile)
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification type icon
                _buildTypeIcon(),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author and action
                      _buildHeader(),

                      // Content preview (if available)
                      if (notification.content != null &&
                          notification.content!.isNotEmpty &&
                          notification.type != NotificationType.reaction)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            notification.content!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Timestamp
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatTimestamp(notification.createdAt),
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile picture
                const SizedBox(width: 8),
                _buildProfilePicture(),
              ],
            ),
          ),
        ),

        // Divider
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.3),
            indent: 12,
            endIndent: 12,
          ),
      ],
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.mention:
        icon = Icons.alternate_email;
        color = AppColors.info;
      case NotificationType.reply:
        icon = Icons.reply;
        color = AppColors.primary;
      case NotificationType.reaction:
        icon = Icons.favorite;
        color = AppColors.error;
      case NotificationType.repost:
        icon = Icons.repeat;
        color = AppColors.success;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }

  Widget _buildHeader() {
    final displayName = notification.fromDisplayName ??
        _truncatePubkey(notification.fromPubkey);

    String actionText;
    switch (notification.type) {
      case NotificationType.mention:
        actionText = 'mentioned you';
      case NotificationType.reply:
        actionText = 'replied to you';
      case NotificationType.reaction:
        final emoji = notification.content ?? '+';
        actionText = 'reacted $emoji';
      case NotificationType.repost:
        actionText = 'reposted your note';
    }

    return RichText(
      text: TextSpan(
        style: AppTypography.bodyMedium,
        children: [
          TextSpan(
            text: displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: ' $actionText',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    if (notification.fromPicture != null &&
        notification.fromPicture!.isNotEmpty) {
      return ClipOval(
        child: SmartImage(
          imageUrl: notification.fromPicture!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(),
          errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
        ),
      );
    }

    return _buildAvatarPlaceholder();
  }

  Widget _buildAvatarPlaceholder() {
    final displayName = notification.fromDisplayName ??
        _truncatePubkey(notification.fromPubkey);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
