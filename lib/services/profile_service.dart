import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';

import '../core/constants/cache_config.dart';
import '../features/profile/models/profile.dart';
import 'cache/cache_service.dart';
import 'ndk_service.dart';

/// Service for fetching and caching Nostr profiles (kind:0 metadata).
///
/// This service provides methods to:
/// - Fetch individual profiles by pubkey
/// - Batch fetch multiple profiles
/// - Cache profiles in memory and on disk for persistence
/// - Fetch a user's posts (kind:1 events)
///
/// Example:
/// ```dart
/// final profileService = ProfileService.instance;
///
/// // Fetch a single profile
/// final profile = await profileService.fetchProfile(pubkey);
///
/// // Fetch multiple profiles
/// final profiles = await profileService.fetchProfiles([pubkey1, pubkey2]);
///
/// // Get cached profile (returns null if not cached)
/// final cached = profileService.getCachedProfile(pubkey);
/// ```
class ProfileService {
  ProfileService._();

  static final ProfileService _instance = ProfileService._();

  /// Singleton instance of ProfileService.
  static ProfileService get instance => _instance;

  final _ndkService = NdkService.instance;
  final _cacheService = CacheService.instance;

  /// In-memory cache of profiles by pubkey.
  final Map<String, Profile> _profileCache = {};

  /// Get a cached profile by pubkey, or null if not cached.
  Profile? getCachedProfile(String pubkey) {
    return _profileCache[pubkey];
  }

  /// Check if a profile is cached.
  bool isCached(String pubkey) {
    return _profileCache.containsKey(pubkey);
  }

  /// Clear a specific profile from cache.
  Future<void> clearFromCache(String pubkey) async {
    _profileCache.remove(pubkey);

    // Also clear from disk cache
    if (_cacheService.isInitialized) {
      final cacheKey = '${CacheConfig.profileKeyPrefix}$pubkey';
      try {
        await _cacheService.remove(cacheKey);
      } catch (e) {
        debugPrint('Error clearing profile from disk cache: $e');
      }
    }
  }

  /// Clear all cached profiles.
  Future<void> clearCache() async {
    _profileCache.clear();

    // Also clear from disk cache
    if (_cacheService.isInitialized) {
      try {
        final count = await _cacheService.removeByPrefix(CacheConfig.profileKeyPrefix);
        debugPrint('Cleared $count profiles from disk cache');
      } catch (e) {
        debugPrint('Error clearing profiles from disk cache: $e');
      }
    }
  }

  /// Fetch a single profile by pubkey.
  ///
  /// Returns the profile from cache if available, otherwise fetches from relays.
  /// If the profile cannot be fetched, returns a placeholder profile.
  ///
  /// Set [forceRefresh] to true to bypass cache and fetch fresh data.
  Future<Profile> fetchProfile(String pubkey, {bool forceRefresh = false}) async {
    final cacheKey = '${CacheConfig.profileKeyPrefix}$pubkey';

    // Return in-memory cached profile if available and not forcing refresh
    if (!forceRefresh && _profileCache.containsKey(pubkey)) {
      return _profileCache[pubkey]!;
    }

    // Check disk cache if not forcing refresh
    if (!forceRefresh && _cacheService.isInitialized) {
      try {
        final cached = await _cacheService.get<Map<String, dynamic>>(
          cacheKey,
          allowStale: false,
        );

        if (cached != null) {
          final profile = Profile.fromJson(cached);
          _profileCache[pubkey] = profile;
          debugPrint('Loaded profile from disk cache: ${profile.nameForDisplay}');
          return profile;
        }
      } catch (e) {
        debugPrint('Error loading profile from disk cache: $e');
        // Continue to fetch from relays
      }
    }

    try {
      debugPrint('Fetching profile for pubkey: ${pubkey.substring(0, 8)}...');

      final filter = Filter(
        kinds: [0], // kind:0 = metadata
        authors: [pubkey],
        limit: 1,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 5),
      );

      if (events.isEmpty) {
        debugPrint('No profile found for pubkey: ${pubkey.substring(0, 8)}...');
        // Return placeholder profile
        final placeholder = Profile.placeholder(pubkey);
        _profileCache[pubkey] = placeholder;
        return placeholder;
      }

      // Use the most recent event (in case of multiple)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final profile = Profile.fromEvent(events.first);

      // Cache the profile in memory
      _profileCache[pubkey] = profile;

      // Save to disk cache
      if (_cacheService.isInitialized) {
        try {
          await _cacheService.set(
            cacheKey,
            profile.toJson(),
            CacheConfig.profilesTtl,
          );
          debugPrint('Saved profile to disk cache: ${profile.nameForDisplay}');
        } catch (e) {
          debugPrint('Error saving profile to disk cache: $e');
          // Continue even if caching fails
        }
      }

      return profile;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Return placeholder profile on error
      final placeholder = Profile.placeholder(pubkey);
      _profileCache[pubkey] = placeholder;
      return placeholder;
    }
  }

  /// Fetch multiple profiles by pubkeys.
  ///
  /// Returns a map of pubkey to Profile. Profiles not found will have
  /// placeholder values.
  ///
  /// This method batches the request for efficiency.
  Future<Map<String, Profile>> fetchProfiles(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return {};

    final results = <String, Profile>{};
    final pubkeysToFetch = <String>[];

    // Check in-memory cache first
    for (final pubkey in pubkeys) {
      if (_profileCache.containsKey(pubkey)) {
        results[pubkey] = _profileCache[pubkey]!;
      } else {
        pubkeysToFetch.add(pubkey);
      }
    }

    // Check disk cache for remaining pubkeys
    final stillNeedToFetch = <String>[];
    if (_cacheService.isInitialized) {
      for (final pubkey in pubkeysToFetch) {
        final cacheKey = '${CacheConfig.profileKeyPrefix}$pubkey';
        try {
          final cached = await _cacheService.get<Map<String, dynamic>>(
            cacheKey,
            allowStale: false,
          );

          if (cached != null) {
            final profile = Profile.fromJson(cached);
            _profileCache[pubkey] = profile;
            results[pubkey] = profile;
          } else {
            stillNeedToFetch.add(pubkey);
          }
        } catch (e) {
          debugPrint('Error loading profile from disk cache: $e');
          stillNeedToFetch.add(pubkey);
        }
      }
    } else {
      // If cache not initialized, need to fetch all
      stillNeedToFetch.addAll(pubkeysToFetch);
    }

    if (stillNeedToFetch.isEmpty) {
      return results;
    }

    try {
      debugPrint('Batch fetching ${stillNeedToFetch.length} profiles...');

      final filter = Filter(
        kinds: [0],
        authors: stillNeedToFetch,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Group events by pubkey and use most recent
      final eventsByPubkey = <String, Nip01Event>{};
      for (final event in events) {
        final existing = eventsByPubkey[event.pubKey];
        if (existing == null || event.createdAt > existing.createdAt) {
          eventsByPubkey[event.pubKey] = event;
        }
      }

      // Convert to profiles and cache
      for (final entry in eventsByPubkey.entries) {
        final profile = Profile.fromEvent(entry.value);
        _profileCache[entry.key] = profile;
        results[entry.key] = profile;

        // Save to disk cache
        if (_cacheService.isInitialized) {
          final cacheKey = '${CacheConfig.profileKeyPrefix}${entry.key}';
          try {
            await _cacheService.set(
              cacheKey,
              profile.toJson(),
              CacheConfig.profilesTtl,
            );
          } catch (e) {
            debugPrint('Error saving profile to disk cache: $e');
            // Continue even if caching fails
          }
        }
      }

      // Add placeholders for pubkeys not found
      for (final pubkey in stillNeedToFetch) {
        if (!results.containsKey(pubkey)) {
          final placeholder = Profile.placeholder(pubkey);
          _profileCache[pubkey] = placeholder;
          results[pubkey] = placeholder;
        }
      }

      debugPrint('Fetched ${eventsByPubkey.length} profiles, ${stillNeedToFetch.length - eventsByPubkey.length} not found');

      return results;
    } catch (e) {
      debugPrint('Error batch fetching profiles: $e');
      // Return placeholders for all unfetched pubkeys
      for (final pubkey in stillNeedToFetch) {
        final placeholder = Profile.placeholder(pubkey);
        _profileCache[pubkey] = placeholder;
        results[pubkey] = placeholder;
      }
      return results;
    }
  }

  /// Fetch a user's posts (kind:1 text notes).
  ///
  /// Returns a list of events authored by the given pubkey, sorted by
  /// creation time (newest first).
  Future<List<Nip01Event>> fetchUserPosts(
    String pubkey, {
    int limit = 50,
    DateTime? until,
  }) async {
    try {
      debugPrint('Fetching posts for pubkey: ${pubkey.substring(0, 8)}...');

      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        authors: [pubkey],
        limit: limit,
        until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Sort by creation time (newest first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('Fetched ${events.length} posts');
      return events;
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
      return [];
    }
  }

  /// Fetch a user's replies (kind:1 with reply markers).
  ///
  /// Returns posts that have "e" tags indicating they are replies.
  Future<List<Nip01Event>> fetchUserReplies(
    String pubkey, {
    int limit = 50,
  }) async {
    try {
      final filter = Filter(
        kinds: [1],
        authors: [pubkey],
        limit: limit,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Filter to only replies (events with "e" tags)
      final replies = events.where((event) {
        return event.tags.any((tag) => tag.isNotEmpty && tag[0] == 'e');
      }).toList();

      replies.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return replies;
    } catch (e) {
      debugPrint('Error fetching user replies: $e');
      return [];
    }
  }

  /// Fetch following count for a user (contacts list, kind:3).
  ///
  /// Returns the number of pubkeys in the user's contact list.
  Future<int> fetchFollowingCount(String pubkey) async {
    try {
      final filter = Filter(
        kinds: [3], // kind:3 = contact list
        authors: [pubkey],
        limit: 1,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 5),
      );

      if (events.isEmpty) return 0;

      // Count "p" tags (followed pubkeys)
      final contactList = events.first;
      return contactList.tags.where((tag) => tag.isNotEmpty && tag[0] == 'p').length;
    } catch (e) {
      debugPrint('Error fetching following count: $e');
      return 0;
    }
  }

  /// Fetch followers count for a user.
  ///
  /// This is expensive as it requires querying all contact lists.
  /// Returns an estimate based on a limited query.
  ///
  /// Note: For accurate counts, consider using a dedicated counting relay
  /// or maintaining a local index.
  Future<int> fetchFollowersCount(String pubkey) async {
    try {
      final filter = Filter(
        kinds: [3],
        pTags: [pubkey], // Contact lists that mention this pubkey
        limit: 500, // Limit to avoid expensive queries
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Deduplicate by author (one contact list per user)
      final uniqueAuthors = events.map((e) => e.pubKey).toSet();
      return uniqueAuthors.length;
    } catch (e) {
      debugPrint('Error fetching followers count: $e');
      return 0;
    }
  }

  /// Check if the current user is following a given pubkey.
  ///
  /// Returns true if [followerPubkey] is following [targetPubkey].
  Future<bool> isFollowing(String followerPubkey, String targetPubkey) async {
    try {
      final filter = Filter(
        kinds: [3],
        authors: [followerPubkey],
        limit: 1,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 5),
      );

      if (events.isEmpty) return false;

      final contactList = events.first;
      return contactList.tags.any((tag) =>
          tag.length >= 2 && tag[0] == 'p' && tag[1] == targetPubkey);
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return false;
    }
  }

  /// Fetch the list of pubkeys a user is following.
  ///
  /// Returns a list of pubkeys from the user's contact list (kind:3).
  Future<List<String>> fetchFollowing(String pubkey) async {
    try {
      final filter = Filter(
        kinds: [3],
        authors: [pubkey],
        limit: 1,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 5),
      );

      if (events.isEmpty) return [];

      final contactList = events.first;
      return contactList.tags
          .where((tag) => tag.length >= 2 && tag[0] == 'p')
          .map((tag) => tag[1])
          .toList();
    } catch (e) {
      debugPrint('Error fetching following list: $e');
      return [];
    }
  }

  /// Fetch the list of pubkeys following a user.
  ///
  /// Note: This is expensive and returns an estimate.
  Future<List<String>> fetchFollowers(String pubkey) async {
    try {
      final filter = Filter(
        kinds: [3],
        pTags: [pubkey],
        limit: 500,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Deduplicate by author
      return events.map((e) => e.pubKey).toSet().toList();
    } catch (e) {
      debugPrint('Error fetching followers list: $e');
      return [];
    }
  }

  /// Follow a user by updating the contact list.
  ///
  /// Returns true if successful.
  Future<bool> followUser({
    required String currentUserPubkey,
    required String targetPubkey,
    required String privateKey,
  }) async {
    // TODO: Implement contact list update (kind:3)
    debugPrint('followUser not yet implemented');
    return false;
  }

  /// Unfollow a user by updating the contact list.
  ///
  /// Returns true if successful.
  Future<bool> unfollowUser({
    required String currentUserPubkey,
    required String targetPubkey,
    required String privateKey,
  }) async {
    // TODO: Implement contact list update (kind:3)
    debugPrint('unfollowUser not yet implemented');
    return false;
  }

  /// Update the user's profile metadata.
  ///
  /// Returns the published event if successful, null otherwise.
  Future<Nip01Event?> updateProfile({
    required Profile profile,
    required String privateKey,
  }) async {
    // TODO: Implement profile update (kind:0)
    debugPrint('updateProfile not yet implemented');
    return null;
  }

  // Update listeners for real-time profile updates (stub)
  final List<void Function(String pubkey, Profile profile)> _updateListeners = [];

  /// Add a listener for profile updates.
  void addUpdateListener(void Function(String pubkey, Profile profile) listener) {
    _updateListeners.add(listener);
  }

  /// Remove a profile update listener.
  void removeUpdateListener(void Function(String pubkey, Profile profile) listener) {
    _updateListeners.remove(listener);
  }

  /// Notify listeners of a profile update.
  void _notifyListeners(String pubkey, Profile profile) {
    for (final listener in _updateListeners) {
      listener(pubkey, profile);
    }
  }
}
