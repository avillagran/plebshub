import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/profile_service.dart';
import '../models/profile.dart';
import '../widgets/follow_button.dart';
import '../widgets/profile_header.dart';

/// Enum for follow list type.
enum FollowListType { following, followers }

/// Screen displaying a user's following or followers list.
///
/// Shows tabs for Following and Followers with lists of profiles.
/// Each profile item has a follow button (if not own profile).
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.pubkey,
    this.initialTab = FollowListType.following,
  });

  /// The pubkey of the user whose follow list to display.
  final String pubkey;

  /// Which tab to show initially.
  final FollowListType initialTab;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<String> _followingPubkeys = [];
  List<String> _followersPubkeys = [];
  Map<String, Profile> _profiles = {};

  bool _isLoadingFollowing = true;
  bool _isLoadingFollowers = true;
  String? _errorFollowing;
  String? _errorFollowers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == FollowListType.following ? 0 : 1,
    );

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFollowing(),
      _loadFollowers(),
    ]);
  }

  Future<void> _loadFollowing() async {
    setState(() {
      _isLoadingFollowing = true;
      _errorFollowing = null;
    });

    try {
      final profileService = ProfileService.instance;
      final pubkeys = await profileService.fetchFollowing(widget.pubkey);

      // Batch fetch profiles
      if (pubkeys.isNotEmpty) {
        final profiles = await profileService.fetchProfiles(pubkeys);
        _profiles.addAll(profiles);
      }

      setState(() {
        _followingPubkeys = pubkeys;
        _isLoadingFollowing = false;
      });
    } catch (e) {
      setState(() {
        _errorFollowing = 'Failed to load following: $e';
        _isLoadingFollowing = false;
      });
    }
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoadingFollowers = true;
      _errorFollowers = null;
    });

    try {
      final profileService = ProfileService.instance;
      final pubkeys = await profileService.fetchFollowers(widget.pubkey);

      // Batch fetch profiles
      if (pubkeys.isNotEmpty) {
        final profiles = await profileService.fetchProfiles(pubkeys);
        _profiles.addAll(profiles);
      }

      setState(() {
        _followersPubkeys = pubkeys;
        _isLoadingFollowers = false;
      });
    } catch (e) {
      setState(() {
        _errorFollowers = 'Failed to load followers: $e';
        _isLoadingFollowers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Connections'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Following (${_followingPubkeys.length})'),
            Tab(text: 'Followers (${_followersPubkeys.length})'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Following tab
          _buildFollowingTab(),

          // Followers tab
          _buildFollowersTab(),
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorFollowing != null) {
      return _buildErrorView(_errorFollowing!, _loadFollowing);
    }

    if (_followingPubkeys.isEmpty) {
      return _buildEmptyView(
        'Not following anyone',
        'When you follow someone, they will appear here.',
        Icons.person_add_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowing,
      child: ListView.builder(
        itemCount: _followingPubkeys.length,
        itemBuilder: (context, index) {
          final pubkey = _followingPubkeys[index];
          final profile = _profiles[pubkey] ?? Profile.placeholder(pubkey);
          return _buildProfileItem(profile);
        },
      ),
    );
  }

  Widget _buildFollowersTab() {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorFollowers != null) {
      return _buildErrorView(_errorFollowers!, _loadFollowers);
    }

    if (_followersPubkeys.isEmpty) {
      return _buildEmptyView(
        'No followers yet',
        'When someone follows this account, they will appear here.',
        Icons.people_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowers,
      child: ListView.builder(
        itemCount: _followersPubkeys.length,
        itemBuilder: (context, index) {
          final pubkey = _followersPubkeys[index];
          final profile = _profiles[pubkey] ?? Profile.placeholder(pubkey);
          return _buildProfileItem(profile);
        },
      ),
    );
  }

  Widget _buildProfileItem(Profile profile) {
    return ProfileHeaderCompact(
      profile: profile,
      onTap: () => context.push('/profile/${profile.pubkey}'),
      trailing: FollowButton(
        pubkey: profile.pubkey,
        compact: true,
      ),
    );
  }

  Widget _buildEmptyView(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Something went wrong',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
