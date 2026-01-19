import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/shared.dart';
import '../models/profile.dart';

/// A reusable header widget for displaying profile information.
///
/// Shows banner image, avatar, name, username, NIP-05 badge, bio, and stats.
///
/// Example:
/// ```dart
/// ProfileHeader(
///   profile: profile,
///   followingCount: 150,
///   followersCount: 1200,
///   postsCount: 500,
///   isOwnProfile: false,
///   isFollowing: true,
///   onFollowTap: () => toggleFollow(),
///   onEditTap: () => editProfile(),
/// )
/// ```
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.followingCount = 0,
    this.followersCount = 0,
    this.postsCount = 0,
    this.isOwnProfile = false,
    this.isFollowing = false,
    this.onFollowTap,
    this.onEditTap,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onMentionTap,
  });

  /// The profile to display.
  final Profile profile;

  /// Number of accounts this user is following.
  final int followingCount;

  /// Number of followers this user has.
  final int followersCount;

  /// Number of posts this user has made.
  final int postsCount;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// Whether the current user is following this profile.
  final bool isFollowing;

  /// Callback when the follow/unfollow button is tapped.
  final VoidCallback? onFollowTap;

  /// Callback when the edit profile button is tapped (own profile only).
  final VoidCallback? onEditTap;

  /// Callback when the following count is tapped.
  final VoidCallback? onFollowingTap;

  /// Callback when the followers count is tapped.
  final VoidCallback? onFollowersTap;

  /// Callback when a mention in the bio is tapped.
  final OnMentionTap? onMentionTap;

  static const double _bannerHeight = 150.0;
  static const double _avatarSize = 80.0;
  static const double _avatarBorderWidth = 4.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner and Avatar stack
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Banner image
            _buildBanner(),

            // Avatar (overlapping banner)
            Positioned(
              left: 16,
              bottom: -(_avatarSize / 2),
              child: _buildAvatar(),
            ),

            // Action button (Follow/Edit) positioned at bottom right
            Positioned(
              right: 16,
              bottom: -20,
              child: _buildActionButton(),
            ),
          ],
        ),

        // Space for avatar overlap
        const SizedBox(height: _avatarSize / 2 + 16),

        // Profile info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              Text(
                profile.nameForDisplay,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              // Username and NIP-05
              Row(
                children: [
                  Text(
                    profile.atUsername,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (profile.nip05 != null) ...[
                    const SizedBox(width: 8),
                    _buildNip05Badge(),
                  ],
                ],
              ),

              // Bio
              if (profile.about != null && profile.about!.isNotEmpty) ...[
                const SizedBox(height: 12),
                NostrContent(
                  content: profile.about!,
                  style: AppTypography.bodyMedium,
                  onMentionTap: onMentionTap,
                  showImages: false,
                ),
              ],

              // Website
              if (profile.website != null && profile.website!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _cleanWebsiteUrl(profile.website!),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Lightning address
              if (profile.lud16 != null && profile.lud16!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.lud16!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Stats row
              _buildStatsRow(),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    if (profile.banner != null && profile.banner!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: profile.banner!,
        height: _bannerHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildBannerPlaceholder(),
        errorWidget: (context, url, error) => _buildBannerPlaceholder(),
      );
    }
    return _buildBannerPlaceholder();
  }

  Widget _buildBannerPlaceholder() {
    return Container(
      height: _bannerHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: _avatarSize + _avatarBorderWidth * 2,
      height: _avatarSize + _avatarBorderWidth * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surface,
          width: _avatarBorderWidth,
        ),
      ),
      child: ClipOval(
        child: profile.picture != null && profile.picture!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: profile.picture!,
                width: _avatarSize,
                height: _avatarSize,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildAvatarPlaceholder(),
                errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
              )
            : _buildAvatarPlaceholder(),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      color: AppColors.surfaceVariant,
      child: Center(
        child: Text(
          profile.nameForDisplay.isNotEmpty
              ? profile.nameForDisplay[0].toUpperCase()
              : '?',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (isOwnProfile) {
      return OutlinedButton(
        onPressed: onEditTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          side: BorderSide(color: AppColors.border),
        ),
        child: Text(
          'Edit Profile',
          style: AppTypography.labelMedium,
        ),
      );
    }

    return ElevatedButton(
      onPressed: onFollowTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowing ? AppColors.surfaceVariant : AppColors.primary,
        foregroundColor: isFollowing ? AppColors.textPrimary : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      child: Text(
        isFollowing ? 'Following' : 'Follow',
        style: AppTypography.labelMedium,
      ),
    );
  }

  Widget _buildNip05Badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 2),
          Text(
            profile.nip05Domain ?? profile.nip05!,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatItem(
          count: postsCount,
          label: 'Posts',
          onTap: null,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          count: followingCount,
          label: 'Following',
          onTap: onFollowingTap,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          count: followersCount,
          label: 'Followers',
          onTap: onFollowersTap,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required int count,
    required String label,
    VoidCallback? onTap,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatCount(count),
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }

  /// Format count for display (e.g., 1234 -> "1.2K").
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// Clean website URL for display (remove protocol).
  String _cleanWebsiteUrl(String url) {
    return url
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll(RegExp(r'/+$'), ''); // Remove trailing slashes
  }
}

/// A compact profile header for use in lists or smaller spaces.
class ProfileHeaderCompact extends StatelessWidget {
  const ProfileHeaderCompact({
    super.key,
    required this.profile,
    this.onTap,
    this.trailing,
  });

  /// The profile to display.
  final Profile profile;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            // Avatar
            ClipOval(
              child: profile.picture != null && profile.picture!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profile.picture!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildAvatarPlaceholder(),
                      errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
                    )
                  : _buildAvatarPlaceholder(),
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
                          style: AppTypography.titleMedium,
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

            // Trailing widget
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
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
}
