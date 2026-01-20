import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/profile_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';

/// State for follow operations.
@immutable
sealed class FollowState {
  const FollowState();
}

/// Initial state - follow data not loaded.
class FollowStateInitial extends FollowState {
  const FollowStateInitial();
}

/// Loading state - fetching follow data.
class FollowStateLoading extends FollowState {
  const FollowStateLoading();
}

/// Loaded state - follow data available.
class FollowStateLoaded extends FollowState {
  const FollowStateLoaded({
    required this.following,
    this.isUpdating = false,
  });

  /// Set of pubkeys the current user is following.
  final Set<String> following;

  /// Whether a follow/unfollow operation is in progress.
  final bool isUpdating;

  /// Check if following a specific pubkey.
  bool isFollowing(String pubkey) => following.contains(pubkey);

  FollowStateLoaded copyWith({
    Set<String>? following,
    bool? isUpdating,
  }) {
    return FollowStateLoaded(
      following: following ?? this.following,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

/// Error state.
class FollowStateError extends FollowState {
  const FollowStateError({required this.message});

  final String message;
}

/// Provider for the current user's follow state.
///
/// Manages the list of pubkeys the current user is following and provides
/// methods to follow/unfollow users with optimistic UI updates.
final followProvider = StateNotifierProvider<FollowNotifier, FollowState>((ref) {
  return FollowNotifier(ref);
});

/// Notifier for managing follow state.
class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier(this._ref) : super(const FollowStateInitial()) {
    // Load following list when authenticated
    _ref.listen(authProvider, (previous, next) {
      if (next is AuthStateAuthenticated) {
        loadFollowing();
      } else {
        state = const FollowStateInitial();
      }
    });

    // Check if already authenticated
    final authState = _ref.read(authProvider);
    if (authState is AuthStateAuthenticated) {
      loadFollowing();
    }
  }

  final Ref _ref;
  final _profileService = ProfileService.instance;

  /// Load the current user's following list.
  Future<void> loadFollowing() async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      return;
    }

    state = const FollowStateLoading();

    try {
      final following = await _profileService.fetchFollowing(
        authState.keypair.publicKey,
      );

      state = FollowStateLoaded(following: following.toSet());
      // debugPrint('Loaded ${following.length} following');
    } catch (e) {
      // debugPrint('Error loading following: $e');
      state = FollowStateError(message: 'Failed to load following: $e');
    }
  }

  /// Check if the current user is following a pubkey.
  bool isFollowing(String pubkey) {
    final currentState = state;
    if (currentState is FollowStateLoaded) {
      return currentState.isFollowing(pubkey);
    }
    return false;
  }

  /// Toggle follow status for a pubkey.
  ///
  /// Uses optimistic UI update - immediately updates local state,
  /// then syncs with the network. Reverts on error.
  Future<bool> toggleFollow(String pubkey) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      // debugPrint('Cannot follow: not authenticated');
      return false;
    }

    // Cannot follow yourself
    if (authState.keypair.publicKey == pubkey) {
      // debugPrint('Cannot follow yourself');
      return false;
    }

    final currentState = state;
    if (currentState is! FollowStateLoaded) {
      // debugPrint('Cannot follow: state not loaded');
      return false;
    }

    final wasFollowing = currentState.isFollowing(pubkey);
    final newFollowing = Set<String>.from(currentState.following);

    // Optimistic update
    if (wasFollowing) {
      newFollowing.remove(pubkey);
    } else {
      newFollowing.add(pubkey);
    }

    state = currentState.copyWith(
      following: newFollowing,
      isUpdating: true,
    );

    try {
      final privateKey = authState.keypair.privateKey!;
      final currentUserPubkey = authState.keypair.publicKey;

      bool success;
      if (wasFollowing) {
        success = await _profileService.unfollowUser(
          currentUserPubkey: currentUserPubkey,
          targetPubkey: pubkey,
          privateKey: privateKey,
        );
      } else {
        success = await _profileService.followUser(
          currentUserPubkey: currentUserPubkey,
          targetPubkey: pubkey,
          privateKey: privateKey,
        );
      }

      if (success) {
        // Update complete
        state = FollowStateLoaded(
          following: newFollowing,
          isUpdating: false,
        );
        // debugPrint('${wasFollowing ? "Unfollowed" : "Followed"} $pubkey');
        return true;
      } else {
        // Revert on failure
        state = currentState.copyWith(isUpdating: false);
        // debugPrint('Failed to ${wasFollowing ? "unfollow" : "follow"} $pubkey');
        return false;
      }
    } catch (e) {
      // Revert on error
      // debugPrint('Error toggling follow: $e');
      state = currentState.copyWith(isUpdating: false);
      return false;
    }
  }

  /// Follow a user.
  Future<bool> follow(String pubkey) async {
    if (!isFollowing(pubkey)) {
      return toggleFollow(pubkey);
    }
    return true;
  }

  /// Unfollow a user.
  Future<bool> unfollow(String pubkey) async {
    if (isFollowing(pubkey)) {
      return toggleFollow(pubkey);
    }
    return true;
  }

  /// Refresh the following list from the network.
  Future<void> refresh() async {
    await loadFollowing();
  }
}

/// Provider to check if following a specific pubkey.
///
/// This is a family provider for reactive UI updates.
final isFollowingProvider = Provider.family<bool, String>((ref, pubkey) {
  final state = ref.watch(followProvider);
  if (state is FollowStateLoaded) {
    return state.isFollowing(pubkey);
  }
  return false;
});

/// Provider to check if a follow operation is in progress.
final isFollowUpdatingProvider = Provider<bool>((ref) {
  final state = ref.watch(followProvider);
  if (state is FollowStateLoaded) {
    return state.isUpdating;
  }
  return false;
});
