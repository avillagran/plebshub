import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/profile_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../feed/models/post.dart';
import '../models/profile.dart';

/// Provider for ProfileService singleton.
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService.instance;
});

/// Provider for fetching a profile by pubkey.
///
/// This is a family provider that caches profiles per pubkey.
///
/// Example:
/// ```dart
/// final profileAsync = ref.watch(profileProvider(pubkey));
///
/// profileAsync.when(
///   data: (profile) => Text(profile.nameForDisplay),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
final profileProvider = FutureProvider.family<Profile, String>((ref, pubkey) async {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.fetchProfile(pubkey);
});

/// Provider for the current user's profile (if authenticated).
///
/// Returns null if not authenticated, otherwise fetches the profile
/// for the current user's pubkey.
final currentUserProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authProvider);

  if (authState is! AuthStateAuthenticated) {
    return null;
  }

  final profileService = ref.watch(profileServiceProvider);
  return profileService.fetchProfile(authState.keypair.publicKey);
});

/// State for the profile screen.
@immutable
sealed class ProfileScreenState {
  const ProfileScreenState();
}

/// Initial state - nothing loaded yet.
class ProfileScreenStateInitial extends ProfileScreenState {
  const ProfileScreenStateInitial();
}

/// Loading state - fetching profile data.
class ProfileScreenStateLoading extends ProfileScreenState {
  const ProfileScreenStateLoading();
}

/// Loaded state - profile data available.
class ProfileScreenStateLoaded extends ProfileScreenState {
  const ProfileScreenStateLoaded({
    required this.profile,
    required this.posts,
    required this.followingCount,
    required this.followersCount,
    required this.isFollowing,
    required this.isOwnProfile,
  });

  final Profile profile;
  final List<Post> posts;
  final int followingCount;
  final int followersCount;
  final bool isFollowing;
  final bool isOwnProfile;
}

/// Error state - something went wrong.
class ProfileScreenStateError extends ProfileScreenState {
  const ProfileScreenStateError({required this.message});

  final String message;
}

/// Provider for the profile screen state.
///
/// Manages loading profile, posts, and related data for display.
final profileScreenProvider =
    StateNotifierProvider.family<ProfileScreenNotifier, ProfileScreenState, String>(
  (ref, pubkey) => ProfileScreenNotifier(ref, pubkey),
);

/// Notifier for managing profile screen state.
class ProfileScreenNotifier extends StateNotifier<ProfileScreenState> {
  ProfileScreenNotifier(this._ref, this._pubkey) : super(const ProfileScreenStateInitial());

  final Ref _ref;
  final String _pubkey;

  final _profileService = ProfileService.instance;

  /// Load all profile data.
  Future<void> loadProfile() async {
    state = const ProfileScreenStateLoading();

    try {
      debugPrint('Loading profile for: ${_pubkey.substring(0, 8)}...');

      // Fetch profile and posts in parallel
      final results = await Future.wait([
        _profileService.fetchProfile(_pubkey),
        _profileService.fetchUserPosts(_pubkey, limit: 30),
        _profileService.fetchFollowingCount(_pubkey),
        _fetchFollowersCountSafe(_pubkey),
        _checkIsFollowing(),
      ]);

      final profile = results[0] as Profile;
      final postEvents = results[1] as List<Nip01Event>;
      final followingCount = results[2] as int;
      final followersCount = results[3] as int;
      final isFollowing = results[4] as bool;

      // Convert events to posts
      final posts = postEvents.map((event) => _convertToPost(event, profile)).toList();

      // Check if this is the current user's profile
      final authState = _ref.read(authProvider);
      final isOwnProfile = authState is AuthStateAuthenticated &&
          authState.keypair.publicKey == _pubkey;

      state = ProfileScreenStateLoaded(
        profile: profile,
        posts: posts,
        followingCount: followingCount,
        followersCount: followersCount,
        isFollowing: isFollowing,
        isOwnProfile: isOwnProfile,
      );

      debugPrint('Profile loaded: ${profile.nameForDisplay}, ${posts.length} posts');
    } catch (e, stackTrace) {
      debugPrint('Error loading profile: $e\n$stackTrace');
      state = ProfileScreenStateError(message: 'Failed to load profile: ${e.toString()}');
    }
  }

  /// Refresh profile data.
  Future<void> refresh() async {
    // Clear cache for this profile
    _profileService.clearFromCache(_pubkey);
    await loadProfile();
  }

  /// Safe wrapper for followers count that catches errors.
  Future<int> _fetchFollowersCountSafe(String pubkey) async {
    try {
      // Note: This can be slow/expensive. Consider caching or using a count relay.
      return await _profileService.fetchFollowersCount(pubkey);
    } catch (e) {
      debugPrint('Error fetching followers count: $e');
      return 0;
    }
  }

  /// Check if current user is following this profile.
  Future<bool> _checkIsFollowing() async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      return false;
    }

    // Can't follow yourself
    if (authState.keypair.publicKey == _pubkey) {
      return false;
    }

    return _profileService.isFollowing(authState.keypair.publicKey, _pubkey);
  }

  /// Convert a Nostr event to a Post model.
  Post _convertToPost(Nip01Event event, Profile author) {
    // Extract reply and root event IDs from tags
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
}

/// Provider for fetching multiple profiles at once (batch).
///
/// Useful for resolving author profiles in a list of posts.
final batchProfilesProvider =
    FutureProvider.family<Map<String, Profile>, List<String>>((ref, pubkeys) async {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.fetchProfiles(pubkeys);
});
