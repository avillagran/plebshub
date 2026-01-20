import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';

import '../core/constants/cache_config.dart';
import '../features/feed/models/nostr_event.dart';
import '../features/feed/models/post.dart';
import 'cache/cache_service.dart';
import 'database_service.dart';
import 'ndk_service.dart';
import 'profile_service.dart';

/// Batch of posts for debounced updates.
class PostBatch {
  PostBatch({
    required this.posts,
    required this.isComplete,
    this.hasMore = true,
  });

  final List<Post> posts;
  final bool isComplete;
  final bool hasMore;
}

/// Service for fetching and parsing feed data off the main UI thread.
///
/// This service:
/// - Moves network operations off the UI thread
/// - Uses `compute()` for heavy JSON parsing in isolates
/// - Returns streams for non-blocking real-time updates
/// - Batches events over 100ms windows to reduce state updates
/// - Implements stale-while-revalidate caching pattern
///
/// Example:
/// ```dart
/// final feedService = FeedService.instance;
///
/// // Stream posts without blocking UI
/// feedService.streamFollowingFeed(userPubkey).listen((batch) {
///   // Update state with batch.posts
/// });
/// ```
class FeedService {
  FeedService._();

  static final FeedService _instance = FeedService._();

  /// Singleton instance of FeedService.
  static FeedService get instance => _instance;

  final _ndkService = NdkService.instance;
  final _dbService = DatabaseService.instance;
  final _cacheService = CacheService.instance;
  final _profileService = ProfileService.instance;

  /// Debounce duration for batching events before state updates.
  static const Duration _debounceDuration = Duration(milliseconds: 100);

  /// Get cache key for the following feed.
  String _feedCacheKey(String userPubkey) =>
      '${CacheConfig.feedKeyPrefix}following_$userPubkey';

  /// Stream posts from followed users with non-blocking architecture.
  ///
  /// Emits [PostBatch] objects:
  /// 1. First: cached posts (immediate, isComplete=false)
  /// 2. Then: fresh posts as they arrive (batched every 100ms)
  /// 3. Finally: complete signal (isComplete=true)
  ///
  /// This pattern shows cached data immediately while streaming fresh
  /// data in the background, without blocking the UI thread.
  Stream<PostBatch> streamFollowingFeed({
    required String userPubkey,
    int limit = 50,
    int timeWindowSeconds = 24 * 60 * 60,
  }) async* {
    // Step 1: Emit cached posts immediately
    final cachedPosts = await _loadFromCache(userPubkey);
    if (cachedPosts.isNotEmpty) {
      yield PostBatch(
        posts: cachedPosts,
        isComplete: false,
        hasMore: true,
      );
    }

    // Step 2: Fetch following list
    final followingPubkeys = await _profileService.fetchFollowing(userPubkey);
    if (followingPubkeys.isEmpty) {
      yield PostBatch(posts: [], isComplete: true, hasMore: false);
      return;
    }

    // Step 3: Stream fresh posts from network
    yield* _streamFreshPosts(
      followingPubkeys: followingPubkeys,
      limit: limit,
      timeWindowSeconds: timeWindowSeconds,
      existingPosts: cachedPosts,
      userPubkey: userPubkey,
    );
  }

  /// Stream fresh posts from network with debouncing.
  Stream<PostBatch> _streamFreshPosts({
    required List<String> followingPubkeys,
    required int limit,
    required int timeWindowSeconds,
    required List<Post> existingPosts,
    required String userPubkey,
  }) async* {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final since = now - timeWindowSeconds;

    final filter = Filter(
      kinds: [1],
      authors: followingPubkeys,
      since: since,
      limit: limit,
    );

    // Collect events in batches
    final eventBuffer = <Nip01Event>[];
    final batchController = StreamController<PostBatch>();
    Timer? debounceTimer;

    // Track all posts for final merge
    final allFreshPosts = <Post>[];

    void flushBuffer() async {
      if (eventBuffer.isEmpty) return;

      final eventsToProcess = List<Nip01Event>.from(eventBuffer);
      eventBuffer.clear();

      // Parse events in isolate
      final posts = await _parseEventsInBackground(eventsToProcess);
      allFreshPosts.addAll(posts);

      // Save to database in background (don't await)
      _saveEventsToDatabase(eventsToProcess);

      // Merge with existing posts
      final mergedPosts = _mergeAndDeduplicate(existingPosts, allFreshPosts);
      mergedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      batchController.add(PostBatch(
        posts: mergedPosts,
        isComplete: false,
        hasMore: true,
      ));
    }

    try {
      // Stream events from relays
      final events = await _ndkService.fetchEvents(filter: filter);

      for (final event in events) {
        eventBuffer.add(event);

        // Debounce: flush buffer after 100ms of no new events
        debounceTimer?.cancel();
        debounceTimer = Timer(_debounceDuration, flushBuffer);
      }

      // Final flush
      debounceTimer?.cancel();
      flushBuffer();

      // Yield all batched updates
      await for (final batch in batchController.stream) {
        yield batch;
      }
    } finally {
      debounceTimer?.cancel();
      await batchController.close();
    }

    // Final complete batch
    final finalPosts = _mergeAndDeduplicate(existingPosts, allFreshPosts);
    finalPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Cache the final result
    _cacheToStorage(finalPosts, userPubkey);

    yield PostBatch(
      posts: finalPosts,
      isComplete: true,
      hasMore: allFreshPosts.length >= limit ~/ 2,
    );
  }

  /// Fetch more posts for pagination (non-blocking).
  ///
  /// Returns a stream of [PostBatch] for older posts.
  Stream<PostBatch> streamMorePosts({
    required List<String> followingPubkeys,
    required int until,
    int limit = 30,
  }) async* {
    final filter = Filter(
      kinds: [1],
      authors: followingPubkeys,
      until: until - 1,
      limit: limit,
    );

    final events = await _ndkService.fetchEvents(filter: filter);

    if (events.isEmpty) {
      yield PostBatch(posts: [], isComplete: true, hasMore: false);
      return;
    }

    // Parse in background
    final posts = await _parseEventsInBackground(events);

    // Save to database (don't block)
    _saveEventsToDatabase(events);

    yield PostBatch(
      posts: posts,
      isComplete: true,
      hasMore: posts.length >= limit ~/ 2,
    );
  }

  /// Parse Nostr events in a background isolate.
  ///
  /// Uses `compute()` to move heavy JSON parsing off the main thread.
  /// This prevents UI stutters when parsing large batches of events.
  Future<List<Post>> _parseEventsInBackground(List<Nip01Event> events) async {
    if (events.isEmpty) return [];

    // Convert NDK events to serializable map for isolate
    final rawEvents = events.map((e) => {
      'id': e.id,
      'pubKey': e.pubKey,
      'createdAt': e.createdAt,
      'kind': e.kind,
      'content': e.content,
      'tags': e.tags,
      'sig': e.sig,
    }).toList();

    // Parse in isolate
    return compute(_parseEventsIsolate, rawEvents);
  }

  /// Load posts from cache.
  Future<List<Post>> _loadFromCache(String userPubkey) async {
    if (!_cacheService.isInitialized) {
      return [];
    }

    try {
      final cached = await _cacheService.get<List<dynamic>>(
        _feedCacheKey(userPubkey),
        allowStale: true,
      );

      if (cached != null && cached.isNotEmpty) {
        // Parse cached posts in isolate for large caches
        if (cached.length > 50) {
          final rawPosts = cached.cast<Map<String, dynamic>>();
          return compute(_parseCachedPostsIsolate, rawPosts);
        }

        // Small cache - parse inline
        return cached
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      // Error loading from cache - return empty
    }

    return [];
  }

  /// Cache posts to storage (non-blocking).
  void _cacheToStorage(List<Post> posts, String userPubkey) {
    if (!_cacheService.isInitialized) return;

    // Run caching in background - don't await
    Future(() async {
      try {
        final postsToCache = posts.take(500).toList();
        final jsonList = postsToCache.map((post) => post.toJson()).toList();

        await _cacheService.set(
          _feedCacheKey(userPubkey),
          jsonList,
          CacheConfig.postsTtl,
        );
      } catch (e) {
        // Error caching posts - ignore
      }
    });
  }

  /// Save events to database (non-blocking).
  void _saveEventsToDatabase(List<Nip01Event> ndkEvents) {
    if (ndkEvents.isEmpty) return;

    // Run database writes in background - don't block UI
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
  }

  /// Merge and deduplicate two lists of posts.
  List<Post> _mergeAndDeduplicate(List<Post> existing, List<Post> fresh) {
    final postMap = <String, Post>{};

    for (final post in existing) {
      postMap[post.id] = post;
    }

    for (final post in fresh) {
      postMap[post.id] = post;
    }

    return postMap.values.toList();
  }

  /// Fetch following pubkeys for a user.
  ///
  /// Returns the cached or fresh list of pubkeys the user is following.
  Future<List<String>?> fetchFollowing(String userPubkey) async {
    return _profileService.fetchFollowing(userPubkey);
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

/// Top-level function for parsing cached posts in isolate.
List<Post> _parseCachedPostsIsolate(List<Map<String, dynamic>> rawPosts) {
  final posts = <Post>[];

  for (final json in rawPosts) {
    try {
      posts.add(Post.fromJson(json));
    } catch (e) {
      // Skip invalid cached posts
    }
  }

  posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return posts;
}
