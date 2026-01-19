import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';

import '../core/constants/relay_constants.dart';
import 'ndk_service.dart';

/// Service for managing Nostr reposts (NIP-18).
///
/// Reposts in Nostr are kind:6 events that reference another event.
/// Content can be the JSON stringified original event or empty.
///
/// Example:
/// ```dart
/// final reposts = await RepostService.instance.fetchReposts(
///   eventIds: ['event-id-1', 'event-id-2'],
/// );
///
/// await RepostService.instance.publishRepost(
///   originalEvent: originalNote,
///   privateKey: 'user-private-key',
/// );
/// ```
class RepostService {
  RepostService._();

  static final RepostService _instance = RepostService._();

  /// Singleton instance of RepostService
  static RepostService get instance => _instance;

  final _ndkService = NdkService.instance;

  /// Publish a repost (kind:6) of a note.
  ///
  /// Creates a kind:6 event referencing the original event.
  /// Per NIP-18:
  /// - Content: JSON stringified original event (or empty)
  /// - Tags: ["e", <original-event-id>, <relay-url>], ["p", <original-author-pubkey>]
  ///
  /// Returns the published repost event on success, null on failure.
  ///
  /// Parameters:
  /// - [originalEvent]: The event to repost
  /// - [privateKey]: The user's private key for signing
  /// - [relayHint]: Optional relay URL hint for the original event
  Future<Nip01Event?> publishRepost({
    required Nip01Event originalEvent,
    required String privateKey,
    String? relayHint,
  }) async {
    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      debugPrint('Publishing repost of event: ${originalEvent.id}');

      // Get public key from private key
      final publicKey = Bip340.getPublicKey(privateKey);

      // Create repost event (kind:6 per NIP-18)
      // Content: JSON stringified original event
      // Tags: ["e", <event-id>, <relay-url>], ["p", <pubkey-of-author>]
      final event = Nip01Event(
        pubKey: publicKey,
        kind: 6, // Repost
        content: jsonEncode(originalEvent.toJson()),
        tags: [
          ['e', originalEvent.id, relayHint ?? ''],
          ['p', originalEvent.pubKey],
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

      debugPrint('Repost published successfully: ${event.id}');
      return event;
    } catch (e) {
      debugPrint('Error publishing repost: $e');
      return null;
    }
  }

  /// Publish a simple repost (kind:6) with minimal event data.
  ///
  /// This is a convenience method when you don't have the full original event.
  /// Creates a repost with empty content (valid per NIP-18).
  ///
  /// Parameters:
  /// - [eventId]: The ID of the event to repost
  /// - [authorPubkey]: The public key of the original event author
  /// - [privateKey]: The user's private key for signing
  /// - [relayHint]: Optional relay URL hint for the original event
  Future<Nip01Event?> publishSimpleRepost({
    required String eventId,
    required String authorPubkey,
    required String privateKey,
    String? relayHint,
  }) async {
    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      debugPrint('Publishing simple repost of event: $eventId');

      // Get public key from private key
      final publicKey = Bip340.getPublicKey(privateKey);

      // Create repost event (kind:6 per NIP-18)
      // Content: empty (valid per NIP-18)
      // Tags: ["e", <event-id>, <relay-url>], ["p", <pubkey-of-author>]
      final event = Nip01Event(
        pubKey: publicKey,
        kind: 6, // Repost
        content: '', // Empty content is valid per NIP-18
        tags: [
          ['e', eventId, relayHint ?? ''],
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

      debugPrint('Simple repost published successfully: ${event.id}');
      return event;
    } catch (e) {
      debugPrint('Error publishing simple repost: $e');
      return null;
    }
  }

  /// Fetch reposts for a list of event IDs.
  ///
  /// Returns a map of event ID to list of repost events.
  ///
  /// Example:
  /// ```dart
  /// final reposts = await RepostService.instance.fetchReposts(
  ///   eventIds: ['event-id-1', 'event-id-2'],
  /// );
  /// final repostsForEvent1 = reposts['event-id-1'] ?? [];
  /// ```
  Future<Map<String, List<Nip01Event>>> fetchReposts({
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) {
      return {};
    }

    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      debugPrint('Fetching reposts for ${eventIds.length} events...');

      // Create filter for kind:6 (reposts) referencing these events
      final filter = Filter(
        kinds: [6], // Reposts
        eTags: eventIds, // Events we want reposts for
      );

      // Fetch reposts from relays
      final request = _ndkService.ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final repostsByEvent = <String, List<Nip01Event>>{};

      await for (final event in request.stream) {
        // Find which event this repost is for (from 'e' tag)
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'e') {
            final targetEventId = tag[1];
            repostsByEvent.putIfAbsent(targetEventId, () => []);
            repostsByEvent[targetEventId]!.add(event);
            break; // Only count once per repost
          }
        }
      }

      debugPrint(
        'Fetched reposts for ${repostsByEvent.length} events',
      );
      return repostsByEvent;
    } catch (e) {
      debugPrint('Error fetching reposts: $e');
      return {};
    }
  }

  /// Check if a user has reposted an event.
  ///
  /// Returns true if the user (identified by pubkey) has reposted
  /// the specified event.
  bool hasUserReposted({
    required String eventId,
    required String userPubkey,
    required Map<String, List<Nip01Event>> reposts,
  }) {
    final eventReposts = reposts[eventId] ?? [];
    return eventReposts.any((repost) => repost.pubKey == userPubkey);
  }

  /// Count reposts for an event.
  int countReposts({
    required String eventId,
    required Map<String, List<Nip01Event>> reposts,
  }) {
    return reposts[eventId]?.length ?? 0;
  }
}
