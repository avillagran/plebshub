import 'dart:async';

import 'package:ndk/ndk.dart';

import '../core/constants/relay_constants.dart';
import 'ndk_service.dart';

/// Service for fetching reply counts for posts (NIP-10).
///
/// Fetches the count of kind:1 events that reference a post's event ID
/// in their "e" tags (indicating they are replies).
///
/// Example:
/// ```dart
/// final counts = await ReplyCountService.instance.fetchReplyCounts(
///   eventIds: ['event-id-1', 'event-id-2'],
/// );
/// final replyCount = counts['event-id-1'] ?? 0;
/// ```
class ReplyCountService {
  ReplyCountService._();

  static final ReplyCountService _instance = ReplyCountService._();

  /// Singleton instance of ReplyCountService.
  static ReplyCountService get instance => _instance;

  final _ndkService = NdkService.instance;

  /// Cache of reply counts by event ID.
  final Map<String, int> _replyCountCache = {};

  /// Get cached reply count for an event.
  int? getCachedCount(String eventId) => _replyCountCache[eventId];

  /// Fetch reply counts for a list of event IDs.
  ///
  /// Returns a map of event ID to reply count.
  /// Uses batch queries to minimize network requests.
  ///
  /// Results are cached for subsequent calls.
  Future<Map<String, int>> fetchReplyCounts({
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) {
      return {};
    }

    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      // Create filter for kind:1 (text notes) that reference these events
      final filter = Filter(
        kinds: [1], // Text notes (replies)
        eTags: eventIds, // Events we want reply counts for
        limit: 5000, // High limit to capture all replies
      );

      // Fetch replies from relays
      final request = _ndkService.ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final replyCounts = <String, int>{};

      // Initialize counts for all requested event IDs
      for (final eventId in eventIds) {
        replyCounts[eventId] = 0;
      }

      await for (final event in request.stream) {
        // Find which event this is a reply to (from 'e' tags)
        // Per NIP-10, look for root or reply markers, or positional tags
        String? replyToId;

        // First, look for marked tags (NIP-10 recommended format)
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'e' && tag.length >= 2) {
            if (tag.length >= 4) {
              final marker = tag[3].toLowerCase();
              if (marker == 'reply' || marker == 'root') {
                // This is a reply - count it for the referenced event
                if (eventIds.contains(tag[1])) {
                  replyCounts[tag[1]] = (replyCounts[tag[1]] ?? 0) + 1;
                  replyToId = tag[1];
                  break;
                }
              }
            }
          }
        }

        // If no marked tags found, use positional parsing (deprecated format)
        if (replyToId == null) {
          for (final tag in event.tags) {
            if (tag.isNotEmpty && tag[0] == 'e' && tag.length >= 2) {
              // Any e-tag reference counts as a reply
              if (eventIds.contains(tag[1])) {
                replyCounts[tag[1]] = (replyCounts[tag[1]] ?? 0) + 1;
                break; // Only count once per reply
              }
            }
          }
        }
      }

      // Update cache
      _replyCountCache.addAll(replyCounts);

      return replyCounts;
    } catch (e) {
      return {};
    }
  }

  /// Fetch reply count for a single event.
  ///
  /// Returns the number of replies to the event.
  Future<int> fetchReplyCount(String eventId) async {
    final counts = await fetchReplyCounts(eventIds: [eventId]);
    return counts[eventId] ?? 0;
  }

  /// Clear the reply count cache.
  void clearCache() {
    _replyCountCache.clear();
  }
}
