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
import '../../../services/database/app_database.dart';
import '../models/post.dart';
import 'feed_provider.dart';

/// Provider for a hashtag feed.
///
/// This is a family provider that creates a separate feed instance for each hashtag.
/// Each hashtag feed manages its own state independently.
///
/// Example:
/// ```dart
/// // In a widget
/// final feedState = ref.watch(hashtagFeedProvider('bitcoin'));
///
/// // Load feed for the hashtag
/// ref.read(hashtagFeedProvider('bitcoin').notifier).loadFeed();
///
/// // Refresh
/// ref.read(hashtagFeedProvider('bitcoin').notifier).refresh();
/// ```
final hashtagFeedProvider = StateNotifierProvider.family<HashtagFeedNotifier,
    HashtagFeedState, String>((ref, hashtag) {
  return HashtagFeedNotifier(hashtag: hashtag);
});

/// State for a hashtag feed.
@immutable
sealed class HashtagFeedState {
  const HashtagFeedState();
}

/// Initial state - no data loaded yet
class HashtagFeedStateInitial extends HashtagFeedState {
  const HashtagFeedStateInitial();
}

/// Loading state - fetching data from relays
class HashtagFeedStateLoading extends HashtagFeedState {
  const HashtagFeedStateLoading();
}

/// Loaded state - feed data available
class HashtagFeedStateLoaded extends HashtagFeedState {
  const HashtagFeedStateLoaded({
    required this.posts,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.oldestTimestamp,
    this.isRefreshingInBackground = false,
    this.newPostsCount = 0,
    this.pendingPosts = const [],
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

  /// Number of new posts waiting to be shown.
  final int newPostsCount;

  /// Posts that arrived while user was viewing feed (not yet merged).
  final List<Post> pendingPosts;

  /// Create a copy with updated fields.
  HashtagFeedStateLoaded copyWith({
    List<Post>? posts,
    bool? isLoadingMore,
    bool? hasMore,
    int? oldestTimestamp,
    bool? isRefreshingInBackground,
    int? newPostsCount,
    List<Post>? pendingPosts,
  }) {
    return HashtagFeedStateLoaded(
      posts: posts ?? this.posts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
      isRefreshingInBackground:
          isRefreshingInBackground ?? this.isRefreshingInBackground,
      newPostsCount: newPostsCount ?? this.newPostsCount,
      pendingPosts: pendingPosts ?? this.pendingPosts,
    );
  }
}

/// Error state - something went wrong
class HashtagFeedStateError extends HashtagFeedState {
  const HashtagFeedStateError({required this.message});

  final String message;
}

/// Notifier for managing hashtag feed state.
class HashtagFeedNotifier extends StateNotifier<HashtagFeedState> {
  HashtagFeedNotifier({required this.hashtag})
      : super(const HashtagFeedStateInitial());

  /// The hashtag this feed is for (without # prefix).
  final String hashtag;

  final _ndkService = NdkService.instance;
  final _dbService = DatabaseService.instance;
  final _cacheService = CacheService.instance;
  final _profileService = ProfileService.instance;

  /// Cache key for this hashtag feed.
  String get _feedCacheKey => '${CacheConfig.feedKeyPrefix}hashtag_$hashtag';

  /// Load the hashtag feed with cache-first pattern.
  ///
  /// 1. Immediately shows cached posts if available (no loading spinner)
  /// 2. Fetches fresh posts in background (fire-and-forget)
  /// 3. New posts are stored as pending (not merged immediately)
  /// 4. UI shows "X nuevos" button when new posts arrive
  ///
  /// If no cache exists, shows loading state and waits for network.
  Future<void> loadFeed() async {
    // Step 1: Try to show cached data immediately
    final hasCached = await _loadFromCache();

    if (hasCached) {
      // Cache loaded - fetch fresh posts in background (fire-and-forget)
      unawaited(_fetchFreshPostsInBackground());
    } else {
      // No cache, show loading state and wait for network
      state = const HashtagFeedStateLoading();
      await _fetchFreshPostsInBackground();
    }
  }

  /// Fetch fresh posts from relays in background.
  ///
  /// Queries for kind:1 events with 't' tag matching the hashtag.
  Future<void> _fetchFreshPostsInBackground() async {
    try {
      final currentState = state;
      final existingIds = <String>{};

      // Collect IDs of posts already displayed
      if (currentState is HashtagFeedStateLoaded) {
        existingIds.addAll(currentState.posts.map((p) => p.id));
        existingIds.addAll(currentState.pendingPosts.map((p) => p.id));
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - FeedConfig.initialTimeWindowSeconds;

      // Create filter for kind:1 (text notes) with 't' tag matching hashtag
      // NIP-12: Generic tag queries using #<single-letter> format
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        since: since,
        limit: FeedConfig.initialLoadLimit,
        tTags: [hashtag.toLowerCase()], // 't' tag for hashtags
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        // If we were loading (no cache), show empty state
        if (state is HashtagFeedStateLoading) {
          state = const HashtagFeedStateLoaded(
            posts: [],
            hasMore: false,
          );
        }
        return;
      }

      // Parse events in isolate and save to DB (non-blocking)
      final allPosts = await _saveEventsToDatabase(ndkEvents);

      // Sort by creation time (newest first)
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final afterFetchState = state;
      if (afterFetchState is HashtagFeedStateLoaded) {
        // Filter to only new posts (not already displayed)
        final newPosts = allPosts
            .where((post) => !existingIds.contains(post.id))
            .toList();

        if (newPosts.isNotEmpty) {
          // Add new posts as pending
          state = afterFetchState.copyWith(
            newPostsCount: newPosts.length,
            pendingPosts: newPosts,
            isRefreshingInBackground: false,
          );

          // Batch-fetch author profiles for new posts in background
          _batchLoadProfilesInBackground(newPosts);
        } else {
          // No new posts, just clear the refreshing flag
          state = afterFetchState.copyWith(
            isRefreshingInBackground: false,
          );
        }

        // Cache the merged posts (existing + new)
        final mergedPosts = _mergeAndDeduplicate(
          afterFetchState.posts,
          allPosts,
        );
        mergedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _cacheToStorage(mergedPosts);
      } else if (afterFetchState is HashtagFeedStateLoading) {
        // We had no cache - show all posts directly
        final oldestTimestamp = allPosts.isNotEmpty
            ? allPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
            : null;

        state = HashtagFeedStateLoaded(
          posts: allPosts,
          hasMore: allPosts.length >= FeedConfig.paginationBatchSize,
          oldestTimestamp: oldestTimestamp,
        );

        // Batch-fetch author profiles in background (non-blocking)
        _batchLoadProfilesInBackground(allPosts);

        // Cache the loaded posts
        await _cacheToStorage(allPosts);
      }
    } catch (e) {
      // If we were loading (no cache), show error
      if (state is HashtagFeedStateLoading) {
        state = HashtagFeedStateError(
          message: 'Failed to load #$hashtag feed: $e',
        );
      } else if (state is HashtagFeedStateLoaded) {
        // Keep showing cached content, just clear refreshing flag
        state = (state as HashtagFeedStateLoaded).copyWith(
          isRefreshingInBackground: false,
        );
      }
    }
  }

  /// Show pending new posts by merging them into the visible list.
  ///
  /// Called when user taps the "X nuevos" button.
  void showNewPosts() {
    final currentState = state;
    if (currentState is! HashtagFeedStateLoaded) return;
    if (currentState.pendingPosts.isEmpty) return;

    // Merge pending posts at the top
    final mergedPosts = [
      ...currentState.pendingPosts,
      ...currentState.posts,
    ];

    // Deduplicate (in case any duplicates slipped through)
    final deduplicatedPosts = _mergeAndDeduplicate([], mergedPosts);

    // Sort by creation time (newest first)
    deduplicatedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Enforce memory limit
    var finalPosts = deduplicatedPosts;
    if (finalPosts.length > FeedConfig.maxPostsInMemory) {
      finalPosts = finalPosts.sublist(0, FeedConfig.maxPostsInMemory);
    }

    // Update oldest timestamp if needed
    final oldestTimestamp = finalPosts.isNotEmpty
        ? finalPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
        : currentState.oldestTimestamp;

    state = currentState.copyWith(
      posts: finalPosts,
      pendingPosts: [],
      newPostsCount: 0,
      oldestTimestamp: oldestTimestamp,
    );

    // Cache the merged posts in background
    unawaited(_cacheToStorage(finalPosts));
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

        // Show cached posts immediately (no loading spinner)
        state = HashtagFeedStateLoaded(
          posts: posts,
          hasMore: true,
          oldestTimestamp: oldestTimestamp,
        );

        // Batch-fetch author profiles in background (non-blocking)
        _batchLoadProfilesInBackground(posts);

        return true;
      }
    } catch (e) {
      // Error loading from cache
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
    } catch (e) {
      // Error caching posts
    }
  }

  /// Merge and deduplicate two lists of posts.
  List<Post> _mergeAndDeduplicate(
    List<Post> existing,
    List<Post> fresh,
  ) {
    final postMap = <String, Post>{};

    for (final post in existing) {
      postMap[post.id] = post;
    }

    for (final post in fresh) {
      postMap[post.id] = post;
    }

    return postMap.values.toList();
  }

  /// Load more posts (pagination).
  Future<void> loadMore() async {
    final currentState = state;

    // Only load more if in loaded state and not already loading
    if (currentState is! HashtagFeedStateLoaded) return;
    if (currentState.isLoadingMore) return;
    if (!currentState.hasMore) return;

    final until = currentState.oldestTimestamp;
    if (until == null) return;

    // Set loading state
    state = currentState.copyWith(isLoadingMore: true);

    try {
      // Create filter for older posts with 't' tag matching hashtag
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        until: until - 1, // Exclude the oldest post we already have
        limit: FeedConfig.paginationBatchSize,
        tTags: [hashtag.toLowerCase()],
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
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
        combinedPosts = combinedPosts.sublist(0, FeedConfig.maxPostsInMemory);
      }

      // Calculate new oldest timestamp
      final newOldestTimestamp = combinedPosts.isNotEmpty
          ? combinedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      state = HashtagFeedStateLoaded(
        posts: combinedPosts,
        isLoadingMore: false,
        hasMore: newPosts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: newOldestTimestamp,
      );

      // Batch-fetch author profiles for new posts in background (non-blocking)
      _batchLoadProfilesInBackground(newPosts);

      // Update cache with new posts
      await _cacheToStorage(combinedPosts);
    } catch (e) {
      // Revert to previous state without loading indicator
      state = currentState.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the feed.
  Future<void> refresh() => loadFeed();

  /// Save NDK events to the database (non-blocking).
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
      for (final ndkEvent in ndkEvents) {
        try {
          await _dbService.db.upsertNostrEvent(NostrEventEntry(
            id: ndkEvent.id,
            pubkey: ndkEvent.pubKey,
            createdAt: ndkEvent.createdAt,
            kind: ndkEvent.kind,
            content: ndkEvent.content,
            tags: jsonEncode(ndkEvent.tags),
            sig: ndkEvent.sig,
          ));
        } catch (e) {
          // Error saving event - skip
        }
      }
    });

    return posts;
  }

  /// Batch-load author profiles in background.
  void _batchLoadProfilesInBackground(List<Post> posts) {
    if (posts.isEmpty) return;

    final pubkeys = posts.map((p) => p.author.pubkey).toSet().toList();

    // Fire and forget - don't await
    unawaited(_profileService.fetchProfiles(pubkeys).catchError((Object e) {
      return <String, Profile>{};
    }));
  }
}

/// Top-level function for parsing events in isolate.
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
