import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/database_service.dart';
import '../../../services/ndk_service.dart';
import '../models/nostr_event.dart';
import '../models/post.dart';

/// Provider for the FeedNotifier.
///
/// This provider manages the global feed state and provides methods for:
/// - Loading the global feed (recent kind:1 notes)
/// - Refreshing the feed
/// - Converting NDK events to Post models
/// - Caching events in Isar database
///
/// Example:
/// ```dart
/// // In a widget
/// final feedState = ref.watch(feedProvider);
///
/// // Load feed
/// ref.read(feedProvider.notifier).loadGlobalFeed();
///
/// // Refresh feed
/// ref.read(feedProvider.notifier).refresh();
/// ```
final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier();
});

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
  const FeedStateLoaded({required this.posts});

  final List<Post> posts;
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

  /// Load the global feed (recent kind:1 notes).
  ///
  /// Fetches up to [limit] recent text notes from relays,
  /// converts them to Post models, and caches them in the database.
  Future<void> loadGlobalFeed({int limit = 50}) async {
    state = const FeedStateLoading();

    try {
      debugPrint('Loading global feed (limit: $limit)...');

      // Create filter for kind:1 (text notes)
      final filter = Filter(
        kinds: [1], // kind:1 = text notes
        limit: limit,
      );

      // Fetch events from relays
      final ndkEvents = await _ndkService.fetchEvents(filter: filter);

      if (ndkEvents.isEmpty) {
        debugPrint('No events found in global feed');
        state = const FeedStateLoaded(posts: []);
        return;
      }

      // Convert NDK events to our NostrEvent model and save to DB
      final nostrEvents = await _saveEventsToDatabase(ndkEvents);

      // Convert NostrEvents to Post models
      final posts = nostrEvents.map(_convertToPost).toList();

      // Sort by creation time (newest first)
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('Loaded ${posts.length} posts');
      state = FeedStateLoaded(posts: posts);
    } catch (e, stackTrace) {
      debugPrint('Error loading global feed: $e\n$stackTrace');
      state = FeedStateError(
        message: 'Failed to load feed: ${e.toString()}',
      );
    }
  }

  /// Refresh the feed.
  ///
  /// This is an alias for [loadGlobalFeed] to support pull-to-refresh patterns.
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
}
