import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';

import '../core/constants/relay_constants.dart';
import 'ndk_service.dart';

/// Service for managing Nostr reactions (NIP-25).
///
/// Reactions in Nostr are kind:7 events that reference another event.
/// Content is typically "+" for like, "-" for dislike, or an emoji.
///
/// Example:
/// ```dart
/// final reactions = await ReactionService.instance.fetchReactions(
///   eventIds: ['event-id-1', 'event-id-2'],
/// );
///
/// await ReactionService.instance.publishReaction(
///   eventId: 'target-event-id',
///   authorPubkey: 'author-pubkey',
///   privateKey: 'user-private-key',
/// );
/// ```
class ReactionService {
  ReactionService._();

  static final ReactionService _instance = ReactionService._();

  /// Singleton instance of ReactionService
  static ReactionService get instance => _instance;

  final _ndkService = NdkService.instance;

  /// Publish a reaction (like) to a note.
  ///
  /// Creates a kind:7 event with content "+" (like) referencing the target event.
  ///
  /// Returns the published reaction event on success, null on failure.
  ///
  /// Parameters:
  /// - [eventId]: The ID of the event to react to
  /// - [authorPubkey]: The public key of the event author (for 'p' tag)
  /// - [privateKey]: The user's private key for signing
  /// - [content]: The reaction content (default "+", can be emoji)
  Future<Nip01Event?> publishReaction({
    required String eventId,
    required String authorPubkey,
    required String privateKey,
    String content = '+',
  }) async {
    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      debugPrint('Publishing reaction to event: $eventId');

      // Get public key from private key
      final publicKey = Bip340.getPublicKey(privateKey);

      // Create reaction event (kind:7 per NIP-25)
      // Tags: ["e", <event-id>], ["p", <pubkey-of-author>]
      final event = Nip01Event(
        pubKey: publicKey,
        kind: 7, // Reaction
        content: content,
        tags: [
          ['e', eventId],
          ['p', authorPubkey],
        ],
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event
      event.sign(privateKey);

      // Broadcast to all connected relays
      final broadcastResponse = _ndkService.ndk.broadcast.broadcast(
        nostrEvent: event,
      );

      // Wait for broadcast to complete
      await broadcastResponse.broadcastDoneFuture;

      debugPrint('Reaction published successfully: ${event.id}');
      return event;
    } catch (e) {
      debugPrint('Error publishing reaction: $e');
      return null;
    }
  }

  /// Fetch reactions for a list of event IDs.
  ///
  /// Returns a map of event ID to list of reactions.
  ///
  /// Example:
  /// ```dart
  /// final reactions = await ReactionService.instance.fetchReactions(
  ///   eventIds: ['event-id-1', 'event-id-2'],
  /// );
  /// final likesForEvent1 = reactions['event-id-1'] ?? [];
  /// ```
  Future<Map<String, List<Nip01Event>>> fetchReactions({
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) {
      return {};
    }

    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      debugPrint('Fetching reactions for ${eventIds.length} events...');

      // Create filter for kind:7 (reactions) referencing these events
      final filter = Filter(
        kinds: [7], // Reactions
        eTags: eventIds, // Events we want reactions for
      );

      // Fetch reactions from relays
      final request = _ndkService.ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final reactionsByEvent = <String, List<Nip01Event>>{};

      await for (final event in request.stream) {
        // Find which event this reaction is for (from 'e' tag)
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'e') {
            final targetEventId = tag[1];
            reactionsByEvent.putIfAbsent(targetEventId, () => []);
            reactionsByEvent[targetEventId]!.add(event);
            break; // Only count once per reaction
          }
        }
      }

      debugPrint(
        'Fetched reactions for ${reactionsByEvent.length} events',
      );
      return reactionsByEvent;
    } catch (e) {
      debugPrint('Error fetching reactions: $e');
      return {};
    }
  }

  /// Check if a user has reacted to an event.
  ///
  /// Returns true if the user (identified by pubkey) has a reaction
  /// to the specified event.
  bool hasUserReacted({
    required String eventId,
    required String userPubkey,
    required Map<String, List<Nip01Event>> reactions,
  }) {
    final eventReactions = reactions[eventId] ?? [];
    return eventReactions.any((reaction) => reaction.pubKey == userPubkey);
  }

  /// Count reactions for an event.
  ///
  /// Optionally filter by content (e.g., "+" for likes only).
  int countReactions({
    required String eventId,
    required Map<String, List<Nip01Event>> reactions,
    String? contentFilter,
  }) {
    final eventReactions = reactions[eventId] ?? [];
    if (contentFilter == null) {
      return eventReactions.length;
    }
    return eventReactions.where((r) => r.content == contentFilter).length;
  }
}
