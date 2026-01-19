import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/database_service.dart';
import '../../../services/ndk_service.dart';
import '../../../services/thread_service.dart';
import '../models/nostr_event.dart';
import '../models/post.dart';

/// Provider for the FeedNotifier.
///
/// This provider manages the global feed state and provides methods for:
/// - Loading the global feed (recent kind:1 notes)
/// - Refreshing the feed
/// - Converting NDK events to Post models
/// - Caching events in Isar database
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
  });

  final List<Post> posts;

  /// Whether more posts are currently being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more posts available to load.
  final bool hasMore;

  /// Timestamp of the oldest post for pagination cursor.
  final int? oldestTimestamp;

  /// Create a copy with updated fields.
  FeedStateLoaded copyWith({
    List<Post>? posts,
    bool? isLoadingMore,
    bool? hasMore,
    int? oldestTimestamp,
  }) {
    return FeedStateLoaded(
      posts: posts ?? this.posts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
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

  /// Load the global feed (recent kind:1 notes).
  ///
  /// Fetches posts from the last 24 hours, up to [FeedConfig.initialLoadLimit].
  /// This is optimized for initial load - use [loadMore] for pagination.
  Future<void> loadGlobalFeed() async {
    state = const FeedStateLoading();

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - FeedConfig.initialTimeWindowSeconds;

      debugPrint(
        'Loading global feed (limit: ${FeedConfig.initialLoadLimit}, '
        'since: ${DateTime.fromMillisecondsSinceEpoch(since * 1000)})...',
      );

      // Create filter for kind:1 (text notes) with time window
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        since: since,
        limit: FeedConfig.initialLoadLimit,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        debugPrint('No events found in global feed');
        state = const FeedStateLoaded(
          posts: [],
          hasMore: true, // Still might have older posts
        );
        return;
      }

      // Convert NDK events to our NostrEvent model and save to DB
      final nostrEvents = await _saveEventsToDatabase(ndkEvents);

      // Convert NostrEvents to Post models
      final posts = nostrEvents.map(_convertToPost).toList();

      // Sort by creation time (newest first)
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Calculate oldest timestamp for pagination
      final oldestTimestamp = posts.isNotEmpty
          ? posts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      debugPrint('Loaded ${posts.length} posts');
      state = FeedStateLoaded(
        posts: posts,
        hasMore: posts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: oldestTimestamp,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading global feed: $e\n$stackTrace');
      state = FeedStateError(
        message: 'Failed to load feed: ${e.toString()}',
      );
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
      debugPrint(
        'Loading more posts (until: '
        '${DateTime.fromMillisecondsSinceEpoch(until * 1000)}, '
        'limit: ${FeedConfig.paginationBatchSize})...',
      );

      // Create filter for older posts
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        until: until - 1, // Exclude the oldest post we already have
        limit: FeedConfig.paginationBatchSize,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        debugPrint('No more posts available');
        state = currentState.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      // Convert NDK events to our NostrEvent model and save to DB
      final nostrEvents = await _saveEventsToDatabase(ndkEvents);

      // Convert NostrEvents to Post models
      final newPosts = nostrEvents.map(_convertToPost).toList();

      // Sort new posts by creation time (newest first)
      newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Combine with existing posts
      var combinedPosts = [...currentState.posts, ...newPosts];

      // Enforce memory limit - discard oldest posts if exceeded
      if (combinedPosts.length > FeedConfig.maxPostsInMemory) {
        debugPrint(
          'Trimming posts from ${combinedPosts.length} '
          'to ${FeedConfig.maxPostsInMemory}',
        );
        combinedPosts = combinedPosts.sublist(0, FeedConfig.maxPostsInMemory);
      }

      // Calculate new oldest timestamp
      final newOldestTimestamp = combinedPosts.isNotEmpty
          ? combinedPosts.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      debugPrint('Loaded ${newPosts.length} more posts, total: ${combinedPosts.length}');
      state = FeedStateLoaded(
        posts: combinedPosts,
        isLoadingMore: false,
        hasMore: newPosts.length >= FeedConfig.paginationBatchSize,
        oldestTimestamp: newOldestTimestamp,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading more posts: $e\n$stackTrace');
      // Revert to previous state without loading indicator
      state = currentState.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh the feed.
  ///
  /// Resets to the latest posts, clearing any pagination state.
  Future<void> refresh() => loadGlobalFeed();

  /// Save NDK events to the database.
  ///
  /// Converts [Nip01Event] objects to [NostrEvent] and stores them in Isar.
  /// Returns the list of saved [NostrEvent] objects.
  Future<List<NostrEvent>> _saveEventsToDatabase(
    List<Nip01Event> ndkEvents,
  ) async {
    final nostrEvents = <NostrEvent>[];

    for (final ndkEvent in ndkEvents) {
      try {
        // Convert NDK event to our NostrEvent model
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
        debugPrint('Error converting NDK event ${ndkEvent.id}: $e');
        // Continue with other events
      }
    }

    // Save to database (batch operation)
    if (nostrEvents.isNotEmpty) {
      try {
        await _dbService.isar.writeTxn(() async {
          await _dbService.isar.nostrEvents.putAll(nostrEvents);
        });
        debugPrint('Saved ${nostrEvents.length} events to database');
      } catch (e) {
        debugPrint('Error saving events to database: $e');
      }
    }

    return nostrEvents;
  }

  /// Convert a [NostrEvent] to a [Post] model.
  ///
  /// This creates a denormalized view suitable for UI display.
  /// TODO: Fetch author metadata from kind:0 events
  /// TODO: Fetch reaction/repost/zap counts
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
      debugPrint('Publishing reply to: ${rootId.substring(0, 8)}...');

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

      if (publishedEvent != null) {
        debugPrint('Reply published: ${publishedEvent.id}');
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Error publishing reply: $e\n$stackTrace');
      return false;
    }
  }
}
