import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/profile_service.dart';
import '../models/profile.dart';

/// Global cache state for profiles.
///
/// This is a map of pubkey -> Profile that widgets can watch for reactive updates.
/// When a profile is loaded from network or cache, it's added here and all
/// watching widgets automatically update.
@immutable
class ProfileCacheState {
  const ProfileCacheState({
    this.profiles = const {},
    this.loadingPubkeys = const {},
  });

  /// Map of pubkey to Profile.
  final Map<String, Profile> profiles;

  /// Set of pubkeys currently being fetched.
  final Set<String> loadingPubkeys;

  /// Get a profile by pubkey, or null if not cached.
  Profile? getProfile(String pubkey) => profiles[pubkey];

  /// Check if a profile is currently loading.
  bool isLoading(String pubkey) => loadingPubkeys.contains(pubkey);

  /// Create a copy with an updated profile.
  ProfileCacheState withProfile(String pubkey, Profile profile) {
    return ProfileCacheState(
      profiles: {...profiles, pubkey: profile},
      loadingPubkeys: loadingPubkeys.difference({pubkey}),
    );
  }

  /// Create a copy with multiple updated profiles.
  ProfileCacheState withProfiles(Map<String, Profile> newProfiles) {
    return ProfileCacheState(
      profiles: {...profiles, ...newProfiles},
      loadingPubkeys: loadingPubkeys.difference(newProfiles.keys.toSet()),
    );
  }

  /// Create a copy with a pubkey marked as loading.
  ProfileCacheState withLoading(String pubkey) {
    return ProfileCacheState(
      profiles: profiles,
      loadingPubkeys: {...loadingPubkeys, pubkey},
    );
  }

  /// Create a copy with multiple pubkeys marked as loading.
  ProfileCacheState withLoadingMany(Set<String> pubkeys) {
    return ProfileCacheState(
      profiles: profiles,
      loadingPubkeys: {...loadingPubkeys, ...pubkeys},
    );
  }
}

/// Notifier for the profile cache.
///
/// Manages profile caching with reactive updates. Widgets can watch specific
/// profiles and will automatically rebuild when the profile data arrives.
///
/// Example:
/// ```dart
/// // Watch a specific profile
/// final profile = ref.watch(
///   profileCacheProvider.select((state) => state.getProfile(pubkey))
/// );
///
/// // Request a profile to be loaded
/// ref.read(profileCacheProvider.notifier).ensureProfile(pubkey);
/// ```
class ProfileCacheNotifier extends StateNotifier<ProfileCacheState> {
  ProfileCacheNotifier() : super(const ProfileCacheState()) {
    // Listen for profile updates from the service
    _profileService.addUpdateListener(_onProfileUpdate);
  }

  final _profileService = ProfileService.instance;

  /// Called when ProfileService updates a profile.
  ///
  /// This ensures the cache stays in sync with the service's cache
  /// and enables reactive updates when profiles are fetched.
  void _onProfileUpdate(String pubkey, Profile profile) {
    // Only update if mounted (not disposed)
    if (!mounted) return;

    // Update our cache state
    state = state.withProfile(pubkey, profile);
  }

  @override
  void dispose() {
    _profileService.removeUpdateListener(_onProfileUpdate);
    super.dispose();
  }

  /// Pending profile fetches to avoid duplicate requests.
  final Map<String, Future<Profile>> _pendingFetches = {};

  /// Get a cached profile immediately, or null if not cached.
  ///
  /// This is a synchronous getter that doesn't trigger any fetches.
  Profile? getProfile(String pubkey) {
    return state.profiles[pubkey];
  }

  /// Set a profile in the cache.
  ///
  /// This immediately updates the cache and notifies all listeners.
  void setProfile(String pubkey, Profile profile) {
    state = state.withProfile(pubkey, profile);
  }

  /// Set multiple profiles in the cache.
  ///
  /// This batch updates the cache and notifies all listeners once.
  void setProfiles(Map<String, Profile> profiles) {
    if (profiles.isEmpty) return;
    state = state.withProfiles(profiles);
  }

  /// Ensure a profile is loaded.
  ///
  /// If the profile is already cached, returns immediately.
  /// Otherwise, triggers a fetch and updates the cache when complete.
  /// Widgets watching this pubkey will automatically update.
  Future<void> ensureProfile(String pubkey) async {
    // Already cached
    if (state.profiles.containsKey(pubkey)) {
      return;
    }

    // Already fetching
    if (_pendingFetches.containsKey(pubkey)) {
      await _pendingFetches[pubkey];
      return;
    }

    // Mark as loading
    state = state.withLoading(pubkey);

    // Start fetch
    final fetchFuture = _fetchProfile(pubkey);
    _pendingFetches[pubkey] = fetchFuture;

    try {
      await fetchFuture;
    } finally {
      _pendingFetches.remove(pubkey);
    }
  }

  /// Ensure multiple profiles are loaded.
  ///
  /// Batch-fetches any profiles not already cached.
  /// This is more efficient than calling ensureProfile for each pubkey.
  Future<void> ensureProfiles(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return;

    // Filter to pubkeys not already cached or loading
    final pubkeysToFetch = pubkeys
        .where((pk) =>
            !state.profiles.containsKey(pk) && !_pendingFetches.containsKey(pk))
        .toSet()
        .toList();

    if (pubkeysToFetch.isEmpty) return;

    // Mark all as loading
    state = state.withLoadingMany(pubkeysToFetch.toSet());

    // debugPrint('Batch fetching ${pubkeysToFetch.length} profiles for cache...');

    try {
      // Batch fetch all profiles
      final profiles = await _profileService.fetchProfiles(pubkeysToFetch);

      // Update cache with all fetched profiles
      state = state.withProfiles(profiles);

      // debugPrint('Cached ${profiles.length} profiles from batch fetch');
    } catch (e) {
      // debugPrint('Error batch fetching profiles: $e');
      // Remove loading state on error (profiles will show placeholders)
      state = ProfileCacheState(
        profiles: state.profiles,
        loadingPubkeys: state.loadingPubkeys.difference(pubkeysToFetch.toSet()),
      );
    }
  }

  /// Fetch a single profile and update cache.
  Future<Profile> _fetchProfile(String pubkey) async {
    try {
      final profile = await _profileService.fetchProfile(pubkey);
      state = state.withProfile(pubkey, profile);
      return profile;
    } catch (e) {
      // debugPrint('Error fetching profile for $pubkey: $e');
      // Create placeholder profile on error
      final placeholder = Profile.placeholder(pubkey);
      state = state.withProfile(pubkey, placeholder);
      return placeholder;
    }
  }

  /// Clear a profile from cache.
  ///
  /// Forces a refetch next time the profile is requested.
  void clearProfile(String pubkey) {
    if (!state.profiles.containsKey(pubkey)) return;

    final newProfiles = Map<String, Profile>.from(state.profiles);
    newProfiles.remove(pubkey);

    state = ProfileCacheState(
      profiles: newProfiles,
      loadingPubkeys: state.loadingPubkeys,
    );
  }

  /// Clear all profiles from cache.
  void clearAll() {
    state = const ProfileCacheState();
  }
}

/// Provider for the global profile cache.
///
/// Use this to access and update the profile cache reactively.
///
/// Example - watching a specific profile:
/// ```dart
/// // In a widget
/// final profile = ref.watch(
///   profileCacheProvider.select((state) => state.getProfile(pubkey))
/// );
///
/// // Ensure the profile is loaded
/// ref.read(profileCacheProvider.notifier).ensureProfile(pubkey);
/// ```
final profileCacheProvider =
    StateNotifierProvider<ProfileCacheNotifier, ProfileCacheState>((ref) {
  return ProfileCacheNotifier();
});

/// Provider to watch a specific profile by pubkey.
///
/// Automatically triggers a fetch if the profile is not cached.
/// Returns null while loading, then the Profile when available.
///
/// Example:
/// ```dart
/// final profile = ref.watch(watchProfileProvider(pubkey));
/// if (profile == null) {
///   return Text('Loading...');
/// }
/// return Text(profile.nameForDisplay);
/// ```
final watchProfileProvider = Provider.family<Profile?, String>((ref, pubkey) {
  // Watch the cache for this specific pubkey
  final profile = ref.watch(
    profileCacheProvider.select((state) => state.getProfile(pubkey)),
  );

  // If not cached, trigger a fetch
  if (profile == null) {
    // Use Future.microtask to avoid modifying state during build
    Future.microtask(() {
      ref.read(profileCacheProvider.notifier).ensureProfile(pubkey);
    });
  }

  return profile;
});
