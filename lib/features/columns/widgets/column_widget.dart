import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/image_precache_service.dart';
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
      case ColumnType.hashtag:
      case ColumnType.user:
      case ColumnType.notifications:
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadFeed());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    final authState = ref.read(authProvider);
    if (authState is AuthStateAuthenticated) {
      await ref.read(feedProvider.notifier).loadFollowingFeed(
            userPubkey: authState.keypair.publicKey,
          );
    } else {
      await ref.read(feedProvider.notifier).loadFeedCacheFirst();
    }
    if (!mounted) return;
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
    final feedState = ref.read(feedProvider);
    if (feedState is! FeedStateLoaded) return;
    if (feedState.isLoadingMore || !feedState.hasMore) return;

    final previousCount = feedState.posts.length;
    await ref.read(feedProvider.notifier).loadMore();

    if (!mounted) return;

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadFeed());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    await ref.read(exploreFeedProvider.notifier).loadGlobalFeed();
    if (!mounted) return;
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
    final feedState = ref.read(exploreFeedProvider);
    if (feedState is! ExploreFeedStateLoaded) return;
    if (feedState.isLoadingMore || !feedState.hasMore) return;

    final previousCount = feedState.posts.length;
    await ref.read(exploreFeedProvider.notifier).loadMore();

    if (!mounted) return;

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
      ) =>
        RefreshIndicator(
          onRefresh: _handleRefresh,
          child: posts.isEmpty
              ? _buildEmptyState()
              : _buildPostsList(posts, isLoadingMore, hasMore),
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
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: posts.length + (isLoadingMore ? 1 : (hasMore ? 1 : 0)),
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return _buildLoadMoreIndicator(isLoadingMore, hasMore);
        }

        _precacheNearbyImages(context, index, posts);

        final post = posts[index];
        return PostCard(
          post: post,
          showDivider: index < posts.length - 1 || isLoadingMore || hasMore,
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadChannel());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _channelId => widget.config.channelId ?? widget.config.id;

  void _loadChannel() {
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
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) return;

    _messageController.clear();

    final success = await ref
        .read(channelChatProvider(_channelId).notifier)
        .sendMessage(content: content);

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
