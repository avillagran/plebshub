import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

/// Types of notifications in the Nostr network.
///
/// Each type corresponds to a specific Nostr event:
/// - [mention]: kind:1 posts that tag the user's pubkey in 'p' tag
/// - [reply]: kind:1 posts that reference user's posts in 'e' tag
/// - [reaction]: kind:7 events referencing user's posts (likes)
/// - [repost]: kind:6 events referencing user's posts (reposts)
enum NotificationType {
  /// Someone mentioned the user in a post (kind:1 with 'p' tag)
  mention,

  /// Someone replied to the user's post (kind:1 with 'e' tag)
  reply,

  /// Someone reacted to the user's post (kind:7)
  reaction,

  /// Someone reposted the user's post (kind:6)
  repost,
}

/// Model representing a notification in the Nostr network.
///
/// A notification can be a mention, reply, reaction, or repost.
/// Each notification contains information about who triggered it,
/// when it happened, and optionally the content or referenced event.
///
/// Example:
/// ```dart
/// final notification = NotificationItem(
///   id: 'event-id',
///   type: NotificationType.reaction,
///   fromPubkey: 'sender-pubkey',
///   createdAt: DateTime.now(),
///   eventId: 'referenced-event-id',
///   content: '+',
/// );
/// ```
@freezed
class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    /// Unique identifier for this notification (event ID)
    required String id,

    /// Type of notification (mention, reply, reaction, repost)
    required NotificationType type,

    /// Public key of the user who triggered this notification
    required String fromPubkey,

    /// When this notification was created
    required DateTime createdAt,

    /// The event ID being referenced (for replies, reactions, reposts)
    String? eventId,

    /// Content of the notification (for mentions, replies, or reaction emoji)
    String? content,

    /// Display name of the user who triggered this notification
    String? fromDisplayName,

    /// Profile picture URL of the user who triggered this notification
    String? fromPicture,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
