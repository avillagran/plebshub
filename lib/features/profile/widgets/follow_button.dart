import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../providers/follow_provider.dart';

/// A button for following/unfollowing a user.
///
/// Shows:
/// - "Follow" when not following
/// - "Following" when following (changes to "Unfollow" on hover)
/// - Loading indicator during operation
/// - Disabled for own profile
///
/// Example:
/// ```dart
/// FollowButton(
///   pubkey: userPubkey,
///   onFollowChanged: (isFollowing) {
///     print(isFollowing ? 'Now following' : 'Unfollowed');
///   },
/// )
/// ```
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.pubkey,
    this.onFollowChanged,
    this.compact = false,
  });

  /// The pubkey of the user to follow/unfollow.
  final String pubkey;

  /// Callback when follow status changes.
  final ValueChanged<bool>? onFollowChanged;

  /// Whether to use compact styling (smaller button).
  final bool compact;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _isHovered = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isFollowing = ref.watch(isFollowingProvider(widget.pubkey));
    final isUpdating = ref.watch(isFollowUpdatingProvider);

    // Don't show for unauthenticated users
    if (authState is! AuthStateAuthenticated) {
      return const SizedBox.shrink();
    }

    // Don't show follow button for own profile
    if (authState.keypair.publicKey == widget.pubkey) {
      return const SizedBox.shrink();
    }

    final isDisabled = _isLoading || isUpdating;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: widget.compact
            ? _buildCompactButton(isFollowing, isDisabled)
            : _buildFullButton(isFollowing, isDisabled),
      ),
    );
  }

  Widget _buildFullButton(bool isFollowing, bool isDisabled) {
    if (isFollowing) {
      // Following state - show "Following" or "Unfollow" on hover
      return ElevatedButton(
        onPressed: isDisabled ? null : _handleTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isHovered ? AppColors.error.withValues(alpha: 0.1) : AppColors.surfaceVariant,
          foregroundColor: _isHovered ? AppColors.error : AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          side: BorderSide(
            color: _isHovered ? AppColors.error : AppColors.border,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _isHovered ? 'Unfollow' : 'Following',
                style: AppTypography.labelMedium.copyWith(
                  color: _isHovered ? AppColors.error : null,
                ),
              ),
      );
    } else {
      // Not following - show "Follow"
      return ElevatedButton(
        onPressed: isDisabled ? null : _handleTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Follow',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                ),
              ),
      );
    }
  }

  Widget _buildCompactButton(bool isFollowing, bool isDisabled) {
    if (isFollowing) {
      return OutlinedButton(
        onPressed: isDisabled ? null : _handleTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(0, 32),
          side: BorderSide(
            color: _isHovered ? AppColors.error : AppColors.border,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _isHovered ? 'Unfollow' : 'Following',
                style: AppTypography.labelSmall.copyWith(
                  color: _isHovered ? AppColors.error : AppColors.textSecondary,
                ),
              ),
      );
    } else {
      return ElevatedButton(
        onPressed: isDisabled ? null : _handleTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(0, 32),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Follow',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                ),
              ),
      );
    }
  }

  Future<void> _handleTap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final followNotifier = ref.read(followProvider.notifier);
      final success = await followNotifier.toggleFollow(widget.pubkey);

      if (success && widget.onFollowChanged != null) {
        final isNowFollowing = ref.read(isFollowingProvider(widget.pubkey));
        widget.onFollowChanged!(isNowFollowing);
      }

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update follow status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// A simple follow/unfollow icon button variant.
class FollowIconButton extends ConsumerStatefulWidget {
  const FollowIconButton({
    super.key,
    required this.pubkey,
    this.onFollowChanged,
  });

  final String pubkey;
  final ValueChanged<bool>? onFollowChanged;

  @override
  ConsumerState<FollowIconButton> createState() => _FollowIconButtonState();
}

class _FollowIconButtonState extends ConsumerState<FollowIconButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isFollowing = ref.watch(isFollowingProvider(widget.pubkey));

    // Don't show for unauthenticated users
    if (authState is! AuthStateAuthenticated) {
      return const SizedBox.shrink();
    }

    // Don't show for own profile
    if (authState.keypair.publicKey == widget.pubkey) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: _handleTap,
      icon: Icon(
        isFollowing ? Icons.person_remove : Icons.person_add,
        color: isFollowing ? AppColors.error : AppColors.primary,
      ),
      tooltip: isFollowing ? 'Unfollow' : 'Follow',
    );
  }

  Future<void> _handleTap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final followNotifier = ref.read(followProvider.notifier);
      final success = await followNotifier.toggleFollow(widget.pubkey);

      if (success && widget.onFollowChanged != null) {
        final isNowFollowing = ref.read(isFollowingProvider(widget.pubkey));
        widget.onFollowChanged!(isNowFollowing);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
