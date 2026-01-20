import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../core/constants/cache_config.dart';
import '../../../services/cache/cache_service.dart';
import '../../../services/database_service.dart';
import '../../../services/ndk_service.dart';
import '../../../services/profile_service.dart';
import '../../profile/models/profile.dart';
import '../models/nostr_event.dart';
import '../models/post.dart';
import 'feed_provider.dart';

/// Provider for the ExploreFeedNotifier.
///
/// This provider manages the global explore feed state (all public posts)
/// and provides methods for:
/// - Loading the global feed (recent kind:1 notes from anyone)
/// - Refreshing the feed
/// - Converting NDK events to Post models
/// - Caching events in Isar database
/// - Pagination with lazy loading
/// - Memory management with history limits
/// - Smart caching with stale-while-revalidate pattern
///
/// Example:
/// ```dart
/// // In a widget
/// final feedState = ref.watch(exploreFeedProvider);
///
/// // Load global feed
/// ref.read(exploreFeedProvider.notifier).loadGlobalFeed();
///
/// // Load more posts (pagination)
/// ref.read(exploreFeedProvider.notifier).loadMore();
///
/// // Refresh feed
/// ref.read(exploreFeedProvider.notifier).refresh();
/// ```
final exploreFeedProvider =
    StateNotifierProvider<ExploreFeedNotifier, ExploreFeedState>((ref) {
  return ExploreFeedNotifier();
});

/// State for the explore feed.
@immutable
sealed class ExploreFeedState {
  const ExploreFeedState();
}

/// Initial state - no data loaded yet
class ExploreFeedStateInitial extends ExploreFeedState {
  const ExploreFeedStateInitial();
}

/// Loading state - fetching data from relays
class ExploreFeedStateLoading extends ExploreFeedState {
  const ExploreFeedStateLoading();
}

/// Loaded state - feed data available
class ExploreFeedStateLoaded extends ExploreFeedState {
  const ExploreFeedStateLoaded({
    required this.posts,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.oldestTimestamp,
    this.isRefreshingInBackground = false,
  });

  final List<Post> posts;

  /// Whether more posts are currently being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more posts available to load.
  final bool hasMore;

  /// Timestamp of the oldest post for pagination cursor.
  final int? oldestTimestamp;

  /// Whether the feed is being refreshed in background (stale-while-revalidate).
  final bool isRefreshingInBackground;

  /// Create a copy with updated fields.
  ExploreFeedStateLoaded copyWith({
    List<Post>? posts,
    bool? isLoadingMore,
    bool? hasMore,
    int? oldestTimestamp,
    bool? isRefreshingInBackground,
  }) {
    return ExploreFeedStateLoaded(
      posts: posts ?? this.posts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
      isRefreshingInBackground:
          isRefreshingInBackground ?? this.isRefreshingInBackground,
    );
  }
}

/// Error state - something went wrong
class ExploreFeedStateError extends ExploreFeedState {
  const ExploreFeedStateError({required this.message});

  final String message;
}

/// Notifier for managing explore feed state.
class ExploreFeedNotifier extends StateNotifier<ExploreFeedState> {
  ExploreFeedNotifier() : super(const ExploreFeedStateInitial());

  final _ndkService = NdkService.instance;
  final _dbService = DatabaseService.instance;
  final _cacheService = CacheService.instance;
  final _profileService = ProfileService.instance;

  /// Cache key for the global explore feed.
  static const String _feedCacheKey = '${CacheConfig.feedKeyPrefix}explore';

  /// Load the global feed with stale-while-revalidate pattern.
  ///
  /// 1. Immediately shows cached posts if available
  /// 2. Fetches fresh posts in background
  /// 3. Merges new posts with cached (deduplicates by id)
  Future<void> loadGlobalFeed() async {
    // Step 1: Try to show cached data immediately
    final hasCached = await _loadFromCache();

    if (!hasCached) {
      // No cache, show loading state
      state = const ExploreFeedStateLoading();
    }

    // Step 2: Fetch fresh data (in background if we have cache)
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - FeedConfig.initialTimeWindowSeconds;

      // debugPrint(
      //   'Loading explore feed (limit: ${FeedConfig.initialLoadLimit}, '
      //   'since: ${DateTime.fromMillisecondsSinceEpoch(since * 1000)})...',
      // );

      // Mark as refreshing in background if we have cached data
      if (state is ExploreFeedStateLoaded) {
        state = (state as ExploreFeedStateLoaded).copyWith(
          isRefreshingInBackground: true,
        );
      }

      // Create filter for kind:1 (text notes) with time window - no author filter
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        since: since,
        limit: FeedConfig.initialLoadLimit,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty && state is! ExploreFeedStateLoaded) {
        // debugPrint('No events found in explore feed');
        state = const ExploreFeedStateLoaded(
          posts: [],
          hasMore: true,
        );
        return;
      }

      // Parse events in isolate and save to DB (non-blocking)
      final freshPosts = await _saveEventsToDatabase(ndkEvents);

      // Get current posts (from cache or empty)
      final currentPosts = state is ExploreFeedStateLoaded
          ? (state as ExploreFeedStateLoaded).posts
          : <Post>[];

      // Merge and deduplicate
      final mergedPosts = _mergeAndDeduplicate(currentPosts, freshPosts);

      // Sort by creation time (newest first)
      mergedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Calculate oldest timestamp for pagination
      final oldestTimestamp = mergedPosts.isNotEmpty
          ? mergedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      // debugPrint('Loaded ${freshPosts.length} fresh posts, '
      //     'merged to ${mergedPosts.length} total');

      state = ExploreFeedStateLoaded(
        posts: mergedPosts,
        hasMore: freshPosts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: oldestTimestamp,
        isRefreshingInBackground: false,
      );

      // Batch-fetch author profiles in background (non-blocking)
      _batchLoadProfilesInBackground(mergedPosts);

      // Cache the merged posts
      await _cacheToStorage(mergedPosts);
    } catch (e, stackTrace) {
      // debugPrint('Error loading explore feed: $e\n$stackTrace');

      // If we have cached data, keep showing it
      if (state is ExploreFeedStateLoaded) {
        state = (state as ExploreFeedStateLoaded).copyWith(
          isRefreshingInBackground: false,
        );
      } else {
        state = ExploreFeedStateError(
          message: 'Failed to load feed: ${e.toString()}',
        );
      }
    }
  }

  /// Load posts from cache.
  ///
  /// Returns true if cached data was loaded, false otherwise.
  Future<bool> _loadFromCache() async {
    if (!_cacheService.isInitialized) {
      return false;
    }

    try {
      final cached = await _cacheService.get<List<dynamic>>(
        _feedCacheKey,
        allowStale: true, // Always show stale data while we refresh
      );

      if (cached != null && cached.isNotEmpty) {
        final posts = cached
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort by creation time (newest first)
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final oldestTimestamp = posts.isNotEmpty
            ? posts.last.createdAt.millisecondsSinceEpoch ~/ 1000
            : null;

        // debugPrint('Loaded ${posts.length} explore posts from cache');

        state = ExploreFeedStateLoaded(
          posts: posts,
          hasMore: true,
          oldestTimestamp: oldestTimestamp,
          isRefreshingInBackground: true, // We'll refresh in background
        );

        // Batch-fetch author profiles in background (non-blocking)
        _batchLoadProfilesInBackground(posts);

        return true;
      }
    } catch (e) {
      // debugPrint('Error loading explore feed from cache: $e');
    }

    return false;
  }

  /// Cache posts to storage.
  Future<void> _cacheToStorage(List<Post> posts) async {
    if (!_cacheService.isInitialized) {
      return;
    }

    try {
      // Only cache the most recent posts to avoid bloat
      final postsToCache = posts.take(FeedConfig.maxPostsInMemory).toList();
      final jsonList = postsToCache.map((post) => post.toJson()).toList();

      await _cacheService.set(
        _feedCacheKey,
        jsonList,
        CacheConfig.postsTtl,
      );

      // debugPrint('Cached ${postsToCache.length} explore posts');
    } catch (e) {
      // debugPrint('Error caching explore posts: $e');
    }
  }

  /// Merge and deduplicate two lists of posts.
  ///
  /// New posts take precedence over existing ones (in case of updates).
  List<Post> _mergeAndDeduplicate(
    List<Post> existing,
    List<Post> fresh,
  ) {
    final postMap = <String, Post>{};

    // Add existing posts first
    for (final post in existing) {
      postMap[post.id] = post;
    }

    // Add fresh posts (overwriting any duplicates)
    for (final post in fresh) {
      postMap[post.id] = post;
    }

    return postMap.values.toList();
  }

  /// Load more posts (pagination).
  ///
  /// Fetches older posts before [oldestTimestamp] from the current state.
  /// Posts are appended to the existing list, with a maximum of
  /// [FeedConfig.maxPostsInMemory] posts kept in memory.
  Future<void> loadMore() async {
    final currentState = state;

    // Only load more if in loaded state and not already loading
    if (currentState is! ExploreFeedStateLoaded) return;
    if (currentState.isLoadingMore) return;
    if (!currentState.hasMore) return;

    final until = currentState.oldestTimestamp;
    if (until == null) return;

    // Set loading state
    state = currentState.copyWith(isLoadingMore: true);

    try {
      // debugPrint(
      //   'Loading more explore posts (until: '
      //   '${DateTime.fromMillisecondsSinceEpoch(until * 1000)}, '
      //   'limit: ${FeedConfig.paginationBatchSize})...',
      // );

      // Create filter for older posts - no author filter
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        until: until - 1, // Exclude the oldest post we already have
        limit: FeedConfig.paginationBatchSize,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        // debugPrint('No more explore posts available');
        state = currentState.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      // Parse events in isolate and save to DB (non-blocking)
      final newPosts = await _saveEventsToDatabase(ndkEvents);

      // Sort new posts by creation time (newest first)
      newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Merge with existing posts
      var combinedPosts = _mergeAndDeduplicate(currentState.posts, newPosts);

      // Sort combined posts
      combinedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Enforce memory limit - discard oldest posts if exceeded
      if (combinedPosts.length > FeedConfig.maxPostsInMemory) {
        // debugPrint(
        //   'Trimming explore posts from ${combinedPosts.length} '
        //   'to ${FeedConfig.maxPostsInMemory}',
        // );
        combinedPosts = combinedPosts.sublist(0, FeedConfig.maxPostsInMemory);
      }

      // Calculate new oldest timestamp
      final newOldestTimestamp = combinedPosts.isNotEmpty
          ? combinedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      // debugPrint(
      //     'Loaded ${newPosts.length} more explore posts, total: ${combinedPosts.length}');
      state = ExploreFeedStateLoaded(
        posts: combinedPosts,
        isLoadingMore: false,
        hasMore: newPosts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: newOldestTimestamp,
      );

      // Batch-fetch author profiles for new posts in background (non-blocking)
      _batchLoadProfilesInBackground(newPosts);

      // Update cache with new posts
      await _cacheToStorage(combinedPosts);
    } catch (e, stackTrace) {
      // debugPrint('Error loading more explore posts: $e\n$stackTrace');
      // Revert to previous state without loading indicator
      state = currentState.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the feed.
  ///
  /// Resets to the latest posts, clearing any pagination state.
  Future<void> refresh() => loadGlobalFeed();

  /// Save NDK events to the database (non-blocking).
  ///
  /// Converts [Nip01Event] objects to [NostrEvent] and stores them in Isar.
  /// Returns the list of posts parsed in isolate for immediate use.
  Future<List<Post>> _saveEventsToDatabase(
    List<Nip01Event> ndkEvents,
  ) async {
    if (ndkEvents.isEmpty) return [];

    // Convert NDK events to serializable map for isolate
    final rawEvents = ndkEvents.map((e) => {
      'id': e.id,
      'pubKey': e.pubKey,
      'createdAt': e.createdAt,
      'kind': e.kind,
      'content': e.content,
      'tags': e.tags,
      'sig': e.sig,
    }).toList();

    // Parse in isolate (heavy JSON processing off main thread)
    final posts = await compute(_parseEventsIsolate, rawEvents);

    // Save to database in background - don't block UI
    Future(() async {
      final nostrEvents = <NostrEvent>[];

      for (final ndkEvent in ndkEvents) {
        try {
          final nostrEvent = NostrEvent(
            id: ndkEvent.id,
            pubkey: ndkEvent.pubKey,
            createdAt: ndkEvent.createdAt,
            kind: ndkEvent.kind,
            content: ndkEvent.content,
            tags: ndkEvent.tags.map((tag) => jsonEncode(tag)).toList(),
            sig: ndkEvent.sig,
          );
          nostrEvents.add(nostrEvent);
        } catch (e) {
          // Error converting event - skip
        }
      }

      if (nostrEvents.isNotEmpty) {
        try {
          await _dbService.isar.writeTxn(() async {
            await _dbService.isar.nostrEvents.putAll(nostrEvents);
          });
        } catch (e) {
          // Error saving events - ignore
        }
      }
    });

    return posts;
  }

  /// Convert a [NostrEvent] to a [Post] model.
  ///
  /// DEPRECATED: Use _parseEventsIsolate for non-blocking parsing.
  /// Kept for backwards compatibility.
  Post _convertToPost(NostrEvent event) {
    // Extract reply and root event IDs from tags
    String? replyToId;
    String? rootEventId;

    for (final tagJson in event.tags) {
      try {
        final tag = jsonDecode(tagJson) as List;
        if (tag.isNotEmpty && tag[0] == 'e') {
          // 'e' tag references another event
          if (tag.length > 3) {
            // NIP-10 format: ["e", <event-id>, <relay-url>, <marker>]
            final marker = tag[3] as String?;
            if (marker == 'reply') {
              replyToId = tag[1] as String;
            } else if (marker == 'root') {
              rootEventId = tag[1] as String;
            }
          } else if (replyToId == null) {
            // Fallback: first 'e' tag is reply-to
            replyToId = tag[1] as String;
          }
        }
      } catch (e) {
        // Skip invalid tags
      }
    }

    // Create author (using truncated pubkey as display name for now)
    final author = PostAuthor(
      pubkey: event.pubkey,
      displayName: _truncatePubkey(event.pubkey),
    );

    return Post(
      id: event.id,
      author: author,
      content: event.content,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        event.createdAt * 1000,
      ),
      replyToId: replyToId,
      rootEventId: rootEventId,
    );
  }

  /// Truncate a pubkey for display.
  ///
  /// Returns the first 8 and last 4 characters of the pubkey.
  /// Example: "npub1abc...xyz"
  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 12) {
      return pubkey;
    }
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }

  /// Batch-load author profiles in background.
  ///
  /// This is fire-and-forget - profiles are fetched asynchronously
  /// and cached. When they arrive, the ProfileCacheProvider is notified
  /// and reactive widgets (ProfileName, ProfileAvatar) auto-update.
  void _batchLoadProfilesInBackground(List<Post> posts) {
    if (posts.isEmpty) return;

    // Extract unique author pubkeys
    final pubkeys = posts.map((p) => p.author.pubkey).toSet().toList();

    // debugPrint('Batch loading ${pubkeys.length} profiles in background...');

    // Fire and forget - don't await
    unawaited(_profileService.fetchProfiles(pubkeys).catchError((Object e) {
      // debugPrint('Error batch loading profiles: $e');
      return <String, Profile>{}; // Return empty map to satisfy type
    }));
  }
}

/// Top-level function for parsing events in isolate.
///
/// Must be a top-level function (not a method or closure) for `compute()`.
List<Post> _parseEventsIsolate(List<Map<String, dynamic>> rawEvents) {
  final posts = <Post>[];

  for (final raw in rawEvents) {
    try {
      final id = raw['id'] as String;
      final pubkey = raw['pubKey'] as String;
      final createdAt = raw['createdAt'] as int;
      final content = raw['content'] as String;
      final tags = (raw['tags'] as List).cast<List<dynamic>>();

      // Extract reply and root event IDs from tags
      String? replyToId;
      String? rootEventId;

      for (final tag in tags) {
        if (tag.isNotEmpty && tag[0] == 'e') {
          if (tag.length > 3) {
            final marker = tag[3] as String?;
            if (marker == 'reply') {
              replyToId = tag[1] as String;
            } else if (marker == 'root') {
              rootEventId = tag[1] as String;
            }
          } else if (replyToId == null) {
            replyToId = tag[1] as String;
          }
        }
      }

      // Create author with truncated pubkey
      final displayName = pubkey.length <= 12
          ? pubkey
          : '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';

      final author = PostAuthor(
        pubkey: pubkey,
        displayName: displayName,
      );

      posts.add(Post(
        id: id,
        author: author,
        content: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        replyToId: replyToId,
        rootEventId: rootEventId,
      ));
    } catch (e) {
      // Skip invalid events
    }
  }

  return posts;
}
