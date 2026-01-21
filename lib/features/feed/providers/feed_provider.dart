import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../core/constants/cache_config.dart';
import '../../../services/cache/cache_service.dart';
import '../../../services/database_service.dart';
import '../../../services/feed_service.dart';
import '../../../services/ndk_service.dart';
import '../../../services/thread_service.dart';
import '../../../services/database/app_database.dart';
import '../models/post.dart';

/// Provider for the FeedNotifier.
///
/// This provider manages the global feed state and provides methods for:
/// - Loading the global feed (recent kind:1 notes)
/// - Refreshing the feed
/// - Converting NDK events to Post models
/// - Caching events in Drift database
/// - Pagination with lazy loading
/// - Memory management with history limits
///
/// Example:
/// ```dart
/// // In a widget
/// final feedState = ref.watch(feedProvider);
///
/// // Load feed
/// ref.read(feedProvider.notifier).loadGlobalFeed();
///
/// // Load more posts (pagination)
/// ref.read(feedProvider.notifier).loadMore();
///
/// // Refresh feed
/// ref.read(feedProvider.notifier).refresh();
/// ```
final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier();
});

/// Configuration constants for feed pagination and memory management.
class FeedConfig {
  /// Initial number of posts to load.
  static const int initialLoadLimit = 50;

  /// Number of posts to load per pagination batch.
  static const int paginationBatchSize = 30;

  /// Maximum number of posts to keep in memory.
  /// Oldest posts are discarded when this limit is exceeded.
  static const int maxPostsInMemory = 500;

  /// Initial time window for fetching posts (24 hours in seconds).
  static const int initialTimeWindowSeconds = 24 * 60 * 60;
}

/// State for the feed.
@immutable
sealed class FeedState {
  const FeedState();
}

/// Initial state - no data loaded yet
class FeedStateInitial extends FeedState {
  const FeedStateInitial();
}

/// Loading state - fetching data from relays
class FeedStateLoading extends FeedState {
  const FeedStateLoading();
}

/// Loaded state - feed data available
class FeedStateLoaded extends FeedState {
  const FeedStateLoaded({
    required this.posts,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.oldestTimestamp,
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

  /// Number of new posts waiting to be shown.
  final int newPostsCount;

  /// Posts that arrived while user was viewing feed (not yet merged).
  final List<Post> pendingPosts;

  /// Create a copy with updated fields.
  FeedStateLoaded copyWith({
    List<Post>? posts,
    bool? isLoadingMore,
    bool? hasMore,
    int? oldestTimestamp,
    int? newPostsCount,
    List<Post>? pendingPosts,
  }) {
    return FeedStateLoaded(
      posts: posts ?? this.posts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
      newPostsCount: newPostsCount ?? this.newPostsCount,
      pendingPosts: pendingPosts ?? this.pendingPosts,
    );
  }
}

/// Error state - something went wrong
class FeedStateError extends FeedState {
  const FeedStateError({required this.message});

  final String message;
}

/// Notifier for managing feed state.
class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(const FeedStateInitial());

  final _ndkService = NdkService.instance;
  final _dbService = DatabaseService.instance;
  final _threadService = ThreadService.instance;
  final _feedService = FeedService.instance;
  final _cacheService = CacheService.instance;

  /// The current user's public key (set when loading following feed).
  String? _currentUserPubkey;

  /// Cache key for unauthenticated global feed.
  static const String _globalFeedCacheKey = '${CacheConfig.feedKeyPrefix}global';

  /// Get cache key for authenticated user's home feed.
  String _homeFeedCacheKey(String userPubkey) =>
      '${CacheConfig.feedKeyPrefix}home_$userPubkey';

  /// Load the global feed (recent kind:1 notes).
  ///
  /// Fetches posts from the last 24 hours, up to [FeedConfig.initialLoadLimit].
  /// This is optimized for initial load - use [loadMore] for pagination.
  ///
  /// Note: Clears _currentUserPubkey to ensure global feed cache is used.
  Future<void> loadGlobalFeed() async {
    // Clear user pubkey so cache uses global key
    _currentUserPubkey = null;

    state = const FeedStateLoading();

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - FeedConfig.initialTimeWindowSeconds;

      // Create filter for kind:1 (text notes) with time window
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        since: since,
        limit: FeedConfig.initialLoadLimit,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        state = const FeedStateLoaded(
          posts: [],
          hasMore: true, // Still might have older posts
        );
        return;
      }

      // Parse events in isolate and save to DB (non-blocking)
      final posts = await _saveEventsToDatabase(ndkEvents);

      // Sort by creation time (newest first)
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Calculate oldest timestamp for pagination
      final oldestTimestamp = posts.isNotEmpty
          ? posts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      state = FeedStateLoaded(
        posts: posts,
        hasMore: posts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: oldestTimestamp,
      );

      // Cache the loaded posts (global feed cache)
      unawaited(_cacheToStorage(posts));
    } catch (e, stackTrace) {
      debugPrint('Error loading global feed: $e\n$stackTrace');
      state = FeedStateError(
        message: 'Failed to load feed: ${e.toString()}',
      );
    }
  }

  /// Load the following feed (posts from users the current user follows).
  ///
  /// Uses cache-first strategy:
  /// 1. Immediately loads and displays cached posts from CacheService
  /// 2. Fetches new posts from relays in the background
  /// 3. New posts are stored as pending (not merged immediately)
  /// 4. UI shows "X nuevos" button when new posts arrive
  ///
  /// Cache key: 'feed_home_{pubkey}' ensures each user gets their own cache.
  /// Falls back to loading state if no cache exists.
  Future<void> loadFollowingFeed({required String userPubkey}) async {
    _currentUserPubkey = userPubkey;

    try {
      // Step 1: Load cached posts FIRST (before any network call)
      // Cache key is based on userPubkey via _homeFeedCacheKey
      final cachedPosts = await _loadFromCache();

      if (cachedPosts.isNotEmpty) {
        // Calculate oldest timestamp for pagination
        final oldestTimestamp =
            cachedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000;

        // Show cached posts INSTANTLY (no loading spinner)
        state = FeedStateLoaded(
          posts: cachedPosts,
          hasMore: true,
          oldestTimestamp: oldestTimestamp,
        );

        // Step 2: Fetch new posts in background (fire-and-forget)
        unawaited(_fetchFollowingPostsInBackground(userPubkey));
      } else {
        // No cache - show loading state and wait for network
        state = const FeedStateLoading();

        List<Post>? loadedPosts;

        // Listen to the stream and update state with each batch
        await for (final batch in _feedService.streamFollowingFeed(
          userPubkey: userPubkey,
          limit: FeedConfig.initialLoadLimit,
          timeWindowSeconds: FeedConfig.initialTimeWindowSeconds,
        )) {
          // Sort posts by creation time (newest first)
          final posts = List<Post>.from(batch.posts)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Calculate oldest timestamp for pagination
          final oldestTimestamp = posts.isNotEmpty
              ? posts.last.createdAt.millisecondsSinceEpoch ~/ 1000
              : null;

          state = FeedStateLoaded(
            posts: posts,
            hasMore: batch.hasMore,
            oldestTimestamp: oldestTimestamp,
          );

          // If batch is complete, cache and we're done
          if (batch.isComplete) {
            loadedPosts = posts;
            break;
          }
        }

        // If no posts were loaded, show empty state
        if (state is FeedStateLoading) {
          state = const FeedStateLoaded(
            posts: [],
            hasMore: false,
          );
        }

        // Cache the loaded posts (following feed cache)
        if (loadedPosts != null && loadedPosts.isNotEmpty) {
          unawaited(_cacheToStorage(loadedPosts));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading following feed: $e\n$stackTrace');
      state = FeedStateError(
        message: 'Failed to load feed: ${e.toString()}',
      );
    }
  }

  /// Fetch new posts from following feed in background.
  ///
  /// This method fetches posts without blocking the UI. New posts are
  /// stored as pending and shown via "X nuevos" button.
  Future<void> _fetchFollowingPostsInBackground(String userPubkey) async {
    try {
      final currentState = state;
      final existingIds = <String>{};

      // Collect IDs of posts already displayed
      if (currentState is FeedStateLoaded) {
        existingIds.addAll(currentState.posts.map((p) => p.id));
        existingIds.addAll(currentState.pendingPosts.map((p) => p.id));
      }

      // Stream posts from relays
      await for (final batch in _feedService.streamFollowingFeed(
        userPubkey: userPubkey,
        limit: FeedConfig.initialLoadLimit,
        timeWindowSeconds: FeedConfig.initialTimeWindowSeconds,
      )) {
        // Sort posts by creation time (newest first)
        final allPosts = List<Post>.from(batch.posts)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Filter to only new posts (not already displayed)
        final newPosts = allPosts
            .where((post) => !existingIds.contains(post.id))
            .toList();

        // Update state with pending posts
        final afterFetchState = state;
        if (afterFetchState is FeedStateLoaded && newPosts.isNotEmpty) {
          state = afterFetchState.copyWith(
            newPostsCount: newPosts.length,
            pendingPosts: newPosts,
          );
        }

        // If batch is complete, we're done
        if (batch.isComplete) break;
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching following feed in background: $e\n$stackTrace');
      // Keep showing cached content - don't update state on error
    }
  }

  /// Load more posts (pagination).
  ///
  /// Fetches older posts before [oldestTimestamp] from the current state.
  /// Posts are appended to the existing list, with a maximum of
  /// [FeedConfig.maxPostsInMemory] posts kept in memory.
  Future<void> loadMore() async {
    final currentState = state;

    // Only load more if in loaded state and not already loading
    if (currentState is! FeedStateLoaded) return;
    if (currentState.isLoadingMore) return;
    if (!currentState.hasMore) return;

    final until = currentState.oldestTimestamp;
    if (until == null) return;

    // Set loading state
    state = currentState.copyWith(isLoadingMore: true);

    try {
      // Create filter for older posts
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        until: until - 1, // Exclude the oldest post we already have
        limit: FeedConfig.paginationBatchSize,
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

      // Combine with existing posts
      var combinedPosts = [...currentState.posts, ...newPosts];

      // Enforce memory limit - discard oldest posts if exceeded
      if (combinedPosts.length > FeedConfig.maxPostsInMemory) {
        combinedPosts = combinedPosts.sublist(0, FeedConfig.maxPostsInMemory);
      }

      // Calculate new oldest timestamp
      final newOldestTimestamp = combinedPosts.isNotEmpty
          ? combinedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      state = FeedStateLoaded(
        posts: combinedPosts,
        isLoadingMore: false,
        hasMore: newPosts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: newOldestTimestamp,
      );

      // Cache the combined posts in background
      unawaited(_cacheToStorage(combinedPosts));
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      // Revert to previous state without loading indicator
      state = currentState.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the feed.
  ///
  /// Resets to the latest posts, clearing any pagination state.
  /// If a user pubkey was set via [loadFollowingFeed], refreshes the
  /// following feed. Otherwise, refreshes the global feed.
  Future<void> refresh() {
    if (_currentUserPubkey != null) {
      return loadFollowingFeed(userPubkey: _currentUserPubkey!);
    }
    return loadGlobalFeed();
  }

  /// Clear the current user pubkey (call when user logs out).
  void clearCurrentUser() {
    _currentUserPubkey = null;
  }

  /// Load feed with cache-first strategy.
  ///
  /// 1. Immediately loads and displays cached posts from database
  /// 2. Fetches new posts from relays in the background (non-blocking)
  /// 3. New posts are stored as pending (not merged immediately)
  /// 4. UI shows "X nuevos" button when new posts arrive
  Future<void> loadFeedCacheFirst() async {
    // Step 1: Load from cache SYNCHRONOUSLY first to show instant content
    // Note: _loadFromCache() returns posts already sorted by createdAt DESC
    final cachedPosts = await _loadFromCache();

    if (cachedPosts.isNotEmpty) {
      // Calculate oldest timestamp for pagination
      final oldestTimestamp =
          cachedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000;

      state = FeedStateLoaded(
        posts: cachedPosts,
        hasMore: true,
        oldestTimestamp: oldestTimestamp,
      );

      // Step 2: Fetch new posts in background (fire-and-forget, don't await)
      // This allows the UI to show cached content immediately while fetching
      unawaited(_fetchNewPostsInBackground());
    } else {
      // No cache, show loading state and wait for network
      state = const FeedStateLoading();
      await _fetchNewPostsInBackground();
    }
  }

  /// Load posts from cache using CacheService.
  ///
  /// Uses auth-aware cache keys:
  /// - Unauthenticated: 'feed_global' key
  /// - Authenticated: 'feed_home_{pubkey}' key
  ///
  /// This ensures users see the correct cached feed based on their auth state.
  ///
  /// For large caches (>50 posts), JSON deserialization is performed in an
  /// isolate via compute() to avoid blocking the main thread.
  Future<List<Post>> _loadFromCache() async {
    if (!_cacheService.isInitialized) {
      return [];
    }

    try {
      // Use different cache key based on auth state
      final cacheKey = _currentUserPubkey != null
          ? _homeFeedCacheKey(_currentUserPubkey!)
          : _globalFeedCacheKey;

      final cached = await _cacheService.get<List<dynamic>>(
        cacheKey,
        allowStale: true, // Show stale data while refreshing
      );

      if (cached != null && cached.isNotEmpty) {
        // Use isolate for large caches to avoid blocking UI
        List<Post> posts;
        if (cached.length > 50) {
          posts = await compute(_parsePostsFromJson, cached);
        } else {
          posts = _parsePostsFromJson(cached);
        }

        // Sort by creation time (newest first)
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return posts;
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }

    return [];
  }

  /// Cache posts to storage using CacheService.
  ///
  /// Uses auth-aware cache keys to store posts for the correct feed type.
  Future<void> _cacheToStorage(List<Post> posts) async {
    if (!_cacheService.isInitialized) {
      return;
    }

    try {
      // Use different cache key based on auth state
      final cacheKey = _currentUserPubkey != null
          ? _homeFeedCacheKey(_currentUserPubkey!)
          : _globalFeedCacheKey;

      // Only cache the most recent posts to avoid bloat
      final postsToCache = posts.take(FeedConfig.maxPostsInMemory).toList();
      final jsonList = postsToCache.map((post) => post.toJson()).toList();

      await _cacheService.set(
        cacheKey,
        jsonList,
        CacheConfig.postsTtl,
      );
    } catch (e) {
      debugPrint('Error caching posts: $e');
    }
  }

  /// Fetch new posts from relays and store as pending.
  Future<void> _fetchNewPostsInBackground() async {
    try {
      final currentState = state;
      final existingIds = <String>{};

      // Collect IDs of posts already displayed
      if (currentState is FeedStateLoaded) {
        existingIds.addAll(currentState.posts.map((p) => p.id));
        existingIds.addAll(currentState.pendingPosts.map((p) => p.id));
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - FeedConfig.initialTimeWindowSeconds;

      // Create filter for kind:1 (text notes) with time window
      final filter = Filter(
        kinds: [1],
        since: since,
        limit: FeedConfig.initialLoadLimit,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        // If we were loading (no cache), show empty state
        if (state is FeedStateLoading) {
          state = const FeedStateLoaded(
            posts: [],
            hasMore: false,
          );
        }
        return;
      }

      // Parse events and save to DB
      final allPosts = await _saveEventsToDatabase(ndkEvents);

      // Filter to only new posts (not already displayed)
      final newPosts = allPosts
          .where((post) => !existingIds.contains(post.id))
          .toList();

      // Sort by creation time (newest first)
      newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final afterFetchState = state;
      if (afterFetchState is FeedStateLoaded) {
        if (newPosts.isNotEmpty) {
          // Add new posts as pending
          state = afterFetchState.copyWith(
            newPostsCount: newPosts.length,
            pendingPosts: newPosts,
          );
        }
        // Cache the merged posts (existing + new)
        final mergedPosts = [...afterFetchState.posts, ...newPosts];
        mergedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _cacheToStorage(mergedPosts);
      } else if (afterFetchState is FeedStateLoading) {
        // We had no cache - show all posts directly
        allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final oldestTimestamp = allPosts.isNotEmpty
            ? allPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
            : null;

        state = FeedStateLoaded(
          posts: allPosts,
          hasMore: allPosts.length >= FeedConfig.paginationBatchSize,
          oldestTimestamp: oldestTimestamp,
        );

        // Cache the loaded posts
        await _cacheToStorage(allPosts);
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching new posts: $e\n$stackTrace');
      // If we were loading (no cache), show error
      if (state is FeedStateLoading) {
        state = FeedStateError(
          message: 'Failed to load feed: ${e.toString()}',
        );
      }
      // Otherwise, keep showing cached content
    }
  }

  /// Show pending new posts by merging them into the visible list.
  ///
  /// Called when user taps the "X nuevos" button.
  void showNewPosts() {
    final currentState = state;
    if (currentState is! FeedStateLoaded) return;
    if (currentState.pendingPosts.isEmpty) return;

    // Merge pending posts at the top
    final mergedPosts = [
      ...currentState.pendingPosts,
      ...currentState.posts,
    ];

    // Enforce memory limit
    var finalPosts = mergedPosts;
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

  /// Save NDK events to the database (non-blocking).
  ///
  /// Converts [Nip01Event] objects to [NostrEvent] and stores them in Drift.
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

  /// Publish a reply to an event.
  ///
  /// Creates a kind:1 event with NIP-10 compliant tags for threading.
  /// Returns true if successful, false otherwise.
  Future<bool> publishReply({
    required String content,
    required String privateKey,
    required String rootId,
    required String rootAuthorPubkey,
    String? replyToId,
    String? replyToAuthorPubkey,
  }) async {
    try {
      // Create NIP-10 compliant tags
      final tags = _threadService.createReplyTags(
        rootId: rootId,
        rootAuthorPubkey: rootAuthorPubkey,
        replyToId: replyToId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );

      // Publish the reply
      final publishedEvent = await _ndkService.publishTextNote(
        content: content,
        privateKey: privateKey,
        tags: tags,
      );

      return publishedEvent != null;
    } catch (e, stackTrace) {
      debugPrint('Error publishing reply: $e\n$stackTrace');
      return false;
    }
  }
}

/// Top-level function for parsing cached posts JSON in isolate.
///
/// Must be a top-level function (not a method or closure) for `compute()`.
/// Used by _loadFromCache() for large caches (>50 posts) to avoid blocking UI.
List<Post> _parsePostsFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) => Post.fromJson(json as Map<String, dynamic>))
      .toList();
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
      String? replyToAuthorPubkey;

      // First pass: extract event references with markers
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

      // Second pass: extract author pubkey from p tags
      // NIP-10: ["p", "<pubkey>", "", "reply"] or just ["p", "<pubkey>"]
      for (final tag in tags) {
        if (tag.isNotEmpty && tag[0] == 'p') {
          final pPubkey = tag[1] as String;
          // Check for marker-based p tag (NIP-10 preferred)
          if (tag.length > 3) {
            final marker = tag[3] as String?;
            if (marker == 'reply') {
              replyToAuthorPubkey = pPubkey;
              break;
            }
          }
          // Fallback: first p tag is likely the reply-to author
          replyToAuthorPubkey ??= pPubkey;
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
        replyToAuthorPubkey: replyToId != null ? replyToAuthorPubkey : null,
      ));
    } catch (e) {
      // Skip invalid events
    }
  }

  return posts;
}
