import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/shared.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../feed/widgets/post_card.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_header.dart';

/// Screen displaying a user's profile.
///
/// Shows profile header with banner, avatar, name, bio, stats,
/// and tabbed content for posts, replies, media, and likes.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.pubkey,
  });

  /// The pubkey of the profile to display.
  final String pubkey;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Load profile data
    Future.microtask(() {
      ref.read(profileScreenProvider(widget.pubkey).notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileScreenProvider(widget.pubkey));

    return Scaffold(
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ProfileScreenState state) {
    return switch (state) {
      ProfileScreenStateInitial() => const Center(
          child: CircularProgressIndicator(),
        ),
      ProfileScreenStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ProfileScreenStateError(:final message) => _buildErrorView(message),
      ProfileScreenStateLoaded() => _buildLoadedView(state),
    };
  }

  Widget _buildErrorView(String message) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text('Profile'),
        ),
        SliverFillRemaining(
          child: Center(
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
                  'Error loading profile',
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
                    ref
                        .read(profileScreenProvider(widget.pubkey).notifier)
                        .loadProfile();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedView(ProfileScreenStateLoaded state) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
            title: Text(state.profile.nameForDisplay),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _handleShare(state.profile),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, state.profile),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy_pubkey',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20),
                        SizedBox(width: 8),
                        Text('Copy pubkey'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_npub',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20),
                        SizedBox(width: 8),
                        Text('Copy npub'),
                      ],
                    ),
                  ),
                  if (state.isOwnProfile) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'copy_nsec',
                      child: Row(
                        children: [
                          Icon(Icons.key, size: 20),
                          SizedBox(width: 8),
                          Text('Copy nsec'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Logout', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'mute',
                      child: Row(
                        children: [
                          Icon(Icons.volume_off, size: 20),
                          SizedBox(width: 8),
                          Text('Mute'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, size: 20),
                          SizedBox(width: 8),
                          Text('Report'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: ProfileHeader(
              profile: state.profile,
              postsCount: state.posts.length,
              followingCount: state.followingCount,
              followersCount: state.followersCount,
              isOwnProfile: state.isOwnProfile,
              isFollowing: state.isFollowing,
              onFollowTap: () => _handleFollowTap(state),
              onEditTap: () => _handleEditProfile(),
              onFollowingTap: () => _handleFollowingTap(),
              onFollowersTap: () => _handleFollowersTap(),
              onMentionTap: (mention) => _handleMentionTap(mention),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Replies'),
                  Tab(text: 'Media'),
                  Tab(text: 'Likes'),
                ],
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          // Posts tab
          _LazyTab(
            controller: _tabController,
            index: 0,
            builder: () => _buildPostsTab(state),
          ),

          // Replies tab (placeholder)
          _LazyTab(
            controller: _tabController,
            index: 1,
            builder: () => _buildPlaceholderTab('Replies', 'Replies will appear here'),
          ),

          // Media tab (placeholder)
          _LazyTab(
            controller: _tabController,
            index: 2,
            builder: () => _buildPlaceholderTab('Media', 'Media posts will appear here'),
          ),

          // Likes tab (placeholder)
          _LazyTab(
            controller: _tabController,
            index: 3,
            builder: () => _buildPlaceholderTab('Likes', 'Liked posts will appear here'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(ProfileScreenStateLoaded state) {
    if (state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(profileScreenProvider(widget.pubkey).notifier)
            .refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.posts.length,
        itemBuilder: (context, index) {
          final post = state.posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PostCard(
              post: post,
              onTap: () {
                // TODO: Navigate to single post view
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _handleShare(Profile profile) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _handleMenuAction(String action, Profile profile) {
    switch (action) {
      case 'copy_pubkey':
        Clipboard.setData(ClipboardData(text: profile.pubkey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pubkey copied to clipboard')),
        );
        break;
      case 'copy_npub':
        final authState = ref.read(authProvider);
        final npub = authState is AuthStateAuthenticated ? authState.npub : '';
        if (npub.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: npub));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('npub copied to clipboard')),
          );
        }
        break;
      case 'copy_nsec':
        final authState = ref.read(authProvider);
        if (authState is AuthStateAuthenticated) {
          Clipboard.setData(ClipboardData(text: authState.nsec));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('nsec copied - keep it secret!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;
      case 'logout':
        _showLogoutConfirmation();
        break;
      case 'mute':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mute functionality coming soon')),
        );
        break;
      case 'report':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report functionality coming soon')),
        );
        break;
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? Make sure you have your nsec backed up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _handleFollowTap(ProfileScreenStateLoaded state) {
    // TODO: Implement follow/unfollow
    final action = state.isFollowing ? 'Unfollow' : 'Follow';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action functionality coming soon')),
    );
  }

  void _handleEditProfile() {
    // TODO: Navigate to edit profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit profile coming soon')),
    );
  }

  void _handleFollowingTap() {
    // TODO: Navigate to following list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Following list coming soon')),
    );
  }

  void _handleFollowersTap() {
    // TODO: Navigate to followers list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Followers list coming soon')),
    );
  }

  void _handleMentionTap(MentionSegment mention) {
    // Navigate to mentioned profile
    if (mention.entityType == NostrEntityType.npub ||
        mention.entityType == NostrEntityType.nprofile) {
      // Extract pubkey from bech32 if possible
      // For now, use the bech32 directly (would need proper decoding)
      // TODO: Decode bech32 to get actual pubkey
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigate to profile: ${mention.shortDisplay}')),
      );
    }
  }
}

/// Lazy-loading tab widget that only builds content when visible.
///
/// Prevents animation overlap by deferring tab content construction
/// until the tab is actually selected.
class _LazyTab extends StatefulWidget {
  const _LazyTab({
    required this.controller,
    required this.index,
    required this.builder,
  });

  final TabController controller;
  final int index;
  final Widget Function() builder;

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  bool _hasBeenVisible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
    _checkVisibility();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    _checkVisibility();
  }

  void _checkVisibility() {
    if (widget.controller.index == widget.index && !_hasBeenVisible) {
      setState(() {
        _hasBeenVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBeenVisible) {
      return const SizedBox.shrink();
    }
    return widget.builder();
  }
}

/// Delegate for persistent tab bar header.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
