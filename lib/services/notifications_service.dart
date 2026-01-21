import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';

import '../core/constants/relay_constants.dart';
import '../features/notifications/models/notification_item.dart';
import 'ndk_service.dart';
import 'profile_service.dart';

/// Service for fetching Nostr notifications.
///
/// Notifications include:
/// - Mentions: kind:1 posts that tag the user's pubkey in 'p' tag
/// - Replies: kind:1 posts that reference user's posts in 'e' tag
/// - Reactions: kind:7 events referencing user's posts
/// - Reposts: kind:6 events referencing user's posts
///
/// Example:
/// ```dart
/// final notifications = await NotificationsService.instance.fetchNotifications(
///   userPubkey: 'user-pubkey',
///   limit: 50,
/// );
/// ```
class NotificationsService {
  NotificationsService._();

  static final NotificationsService _instance = NotificationsService._();

  /// Singleton instance of NotificationsService
  static NotificationsService get instance => _instance;

  final _ndkService = NdkService.instance;
  final _profileService = ProfileService.instance;

  /// Fetch notifications for a user.
  ///
  /// Queries for:
  /// - kind:1 with #p tag = userPubkey (mentions)
  /// - kind:7 with #p tag = userPubkey (reactions to user's posts)
  /// - kind:6 with #p tag = userPubkey (reposts of user's posts)
  ///
  /// For replies, we need to first fetch the user's posts, then query for
  /// kind:1 events with 'e' tags referencing those posts.
  ///
  /// Returns a list of [NotificationItem] sorted by creation time (newest first).
  Future<List<NotificationItem>> fetchNotifications({
    required String userPubkey,
    int limit = 50,
    int? since,
    int? until,
  }) async {
    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      debugPrint('Fetching notifications for user: $userPubkey');

      // Fetch all notification types in parallel for better performance
      final results = await Future.wait([
        _fetchMentionsAndReplies(
          userPubkey: userPubkey,
          limit: limit,
          since: since,
          until: until,
        ),
        _fetchReactions(
          userPubkey: userPubkey,
          limit: limit,
          since: since,
          until: until,
        ),
        _fetchReposts(
          userPubkey: userPubkey,
          limit: limit,
          since: since,
          until: until,
        ),
      ]);

      // Combine all notifications
      final allNotifications = <NotificationItem>[
        ...results[0], // mentions and replies
        ...results[1], // reactions
        ...results[2], // reposts
      ];

      // Sort by creation time (newest first)
      allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Limit total results
      final limitedNotifications = allNotifications.take(limit).toList();

      // Fetch profiles for notification authors
      await _enrichWithProfiles(limitedNotifications);

      debugPrint(
        'Fetched ${limitedNotifications.length} notifications',
      );

      return limitedNotifications;
    } catch (e, stackTrace) {
      debugPrint('Error fetching notifications: $e\n$stackTrace');
      return [];
    }
  }

  /// Fetch mentions and replies (kind:1 events that tag the user).
  ///
  /// Mentions: posts that include the user's pubkey in a 'p' tag
  /// Replies: posts that reference the user's posts in an 'e' tag
  Future<List<NotificationItem>> _fetchMentionsAndReplies({
    required String userPubkey,
    int limit = 50,
    int? since,
    int? until,
  }) async {
    try {
      // Query for kind:1 events that tag the user (mentions)
      final filter = Filter(
        kinds: [1],
        pTags: [userPubkey],
        limit: limit,
        since: since,
        until: until,
      );

      final request = _ndkService.ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final notifications = <NotificationItem>[];

      await for (final event in request.stream) {
        // Skip events from the user themselves
        if (event.pubKey == userPubkey) continue;

        // Determine if this is a mention or reply
        final type = _determineNotificationType(event, userPubkey);

        notifications.add(NotificationItem(
          id: event.id,
          type: type,
          fromPubkey: event.pubKey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            event.createdAt * 1000,
          ),
          eventId: _extractReferencedEventId(event),
          content: event.content,
        ));
      }

      return notifications;
    } catch (e) {
      debugPrint('Error fetching mentions/replies: $e');
      return [];
    }
  }

  /// Determine if a kind:1 event is a mention or reply.
  ///
  /// If the event has an 'e' tag with the user's event ID, it's a reply.
  /// Otherwise, if it just has a 'p' tag with the user's pubkey, it's a mention.
  NotificationType _determineNotificationType(
    Nip01Event event,
    String userPubkey,
  ) {
    // Check if this is a reply (has 'e' tags indicating it's replying to something)
    final hasEventReferences = event.tags.any(
      (tag) => tag.isNotEmpty && tag[0] == 'e',
    );

    // If it has event references, it's more likely a reply
    // If it only has 'p' tag mentions, it's a mention
    if (hasEventReferences) {
      return NotificationType.reply;
    }

    return NotificationType.mention;
  }

  /// Extract the referenced event ID from an event's tags.
  String? _extractReferencedEventId(Nip01Event event) {
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length >= 2) {
        return tag[1];
      }
    }
    return null;
  }

  /// Fetch reactions (kind:7 events) that reference the user.
  Future<List<NotificationItem>> _fetchReactions({
    required String userPubkey,
    int limit = 50,
    int? since,
    int? until,
  }) async {
    try {
      // Query for kind:7 events that tag the user (reactions to their posts)
      final filter = Filter(
        kinds: [7],
        pTags: [userPubkey],
        limit: limit,
        since: since,
        until: until,
      );

      final request = _ndkService.ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final notifications = <NotificationItem>[];

      await for (final event in request.stream) {
        // Skip reactions from the user themselves
        if (event.pubKey == userPubkey) continue;

        notifications.add(NotificationItem(
          id: event.id,
          type: NotificationType.reaction,
          fromPubkey: event.pubKey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            event.createdAt * 1000,
          ),
          eventId: _extractReferencedEventId(event),
          content: event.content, // Usually '+' or emoji
        ));
      }

      return notifications;
    } catch (e) {
      debugPrint('Error fetching reactions: $e');
      return [];
    }
  }

  /// Fetch reposts (kind:6 events) that reference the user's posts.
  Future<List<NotificationItem>> _fetchReposts({
    required String userPubkey,
    int limit = 50,
    int? since,
    int? until,
  }) async {
    try {
      // Query for kind:6 events that tag the user (reposts of their posts)
      final filter = Filter(
        kinds: [6],
        pTags: [userPubkey],
        limit: limit,
        since: since,
        until: until,
      );

      final request = _ndkService.ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final notifications = <NotificationItem>[];

      await for (final event in request.stream) {
        // Skip reposts from the user themselves
        if (event.pubKey == userPubkey) continue;

        notifications.add(NotificationItem(
          id: event.id,
          type: NotificationType.repost,
          fromPubkey: event.pubKey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            event.createdAt * 1000,
          ),
          eventId: _extractReferencedEventId(event),
          content: null, // Reposts typically don't have meaningful content
        ));
      }

      return notifications;
    } catch (e) {
      debugPrint('Error fetching reposts: $e');
      return [];
    }
  }

  /// Enrich notifications with profile information.
  ///
  /// Fetches profiles for all unique pubkeys in the notifications
  /// and updates the display name and picture fields.
  Future<void> _enrichWithProfiles(List<NotificationItem> notifications) async {
    if (notifications.isEmpty) return;

    try {
      // Get unique pubkeys
      final pubkeys = notifications.map((n) => n.fromPubkey).toSet().toList();

      // Fetch profiles in batch
      final profiles = await _profileService.fetchProfiles(pubkeys);

      // Update notifications with profile info
      for (var i = 0; i < notifications.length; i++) {
        final notification = notifications[i];
        final profile = profiles[notification.fromPubkey];

        if (profile != null) {
          notifications[i] = notification.copyWith(
            fromDisplayName: profile.displayName ?? profile.name,
            fromPicture: profile.picture,
          );
        }
      }
    } catch (e) {
      debugPrint('Error enriching notifications with profiles: $e');
      // Continue with notifications without profile info
    }
  }

  /// Fetch more notifications for pagination.
  ///
  /// Uses the timestamp of the oldest notification as the 'until' parameter.
  Future<List<NotificationItem>> fetchMoreNotifications({
    required String userPubkey,
    required int untilTimestamp,
    int limit = 50,
  }) async {
    return fetchNotifications(
      userPubkey: userPubkey,
      limit: limit,
      until: untilTimestamp - 1, // Exclude the oldest notification we have
    );
  }
}
