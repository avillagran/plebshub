/// Model representing a message in a Nostr public chat channel (NIP-28).
///
/// Channel messages are kind:42 events with tags referencing the channel.
///
/// Example:
/// ```dart
/// final message = ChannelMessage(
///   id: 'message-id',
///   channelId: 'channel-id',
///   content: 'Hello, world!',
///   authorPubkey: 'author-pubkey',
///   createdAt: DateTime.now(),
/// );
/// ```
class ChannelMessage {
  /// Creates a new ChannelMessage.
  const ChannelMessage({
    required this.id,
    required this.channelId,
    required this.content,
    required this.authorPubkey,
    required this.createdAt,
    this.replyToId,
    this.replyToAuthorPubkey,
  });

  /// The message ID (event ID).
  final String id;

  /// The channel ID this message belongs to.
  final String channelId;

  /// Message content/text.
  final String content;

  /// Public key of the message author.
  final String authorPubkey;

  /// When the message was created.
  final DateTime createdAt;

  /// ID of the message being replied to (if any).
  final String? replyToId;

  /// Public key of the author being replied to (if any).
  final String? replyToAuthorPubkey;

  /// Create a ChannelMessage from a kind:42 Nostr event.
  ///
  /// Tags should include:
  /// - ["e", <channel-id>, <relay>, "root"] - references the channel
  /// - ["e", <reply-to-id>, <relay>, "reply"] - optional, for replies
  /// - ["p", <reply-to-author>] - optional, for replies
  factory ChannelMessage.fromEvent({
    required String eventId,
    required String content,
    required String pubkey,
    required int createdAt,
    required List<List<String>> tags,
  }) {
    String? channelId;
    String? replyToId;
    String? replyToAuthorPubkey;

    // Parse tags to extract channel ID and reply info
    for (final tag in tags) {
      if (tag.isEmpty) continue;

      if (tag[0] == 'e' && tag.length >= 2) {
        // Check for marker (NIP-10 style)
        if (tag.length >= 4) {
          final marker = tag[3];
          if (marker == 'root') {
            channelId = tag[1];
          } else if (marker == 'reply') {
            replyToId = tag[1];
          }
        } else if (channelId == null) {
          // Fallback: first e tag without marker is the channel
          channelId = tag[1];
        }
      } else if (tag[0] == 'p' && tag.length >= 2) {
        // Author being mentioned/replied to
        if (replyToAuthorPubkey == null) {
          replyToAuthorPubkey = tag[1];
        }
      }
    }

    return ChannelMessage(
      id: eventId,
      channelId: channelId ?? '',
      content: content,
      authorPubkey: pubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      replyToId: replyToId,
      replyToAuthorPubkey: replyToAuthorPubkey,
    );
  }

  /// Create NIP-28 compliant tags for a channel message.
  ///
  /// Creates tags with:
  /// - ["e", <channel-id>, <relay>, "root"] - channel reference
  /// - ["e", <reply-to-id>, <relay>, "reply"] - optional reply reference
  /// - ["p", <reply-to-author>] - optional author mention
  static List<List<String>> createMessageTags({
    required String channelId,
    String? relayUrl,
    String? replyToId,
    String? replyToAuthorPubkey,
  }) {
    final tags = <List<String>>[];
    final relay = relayUrl ?? '';

    // Channel reference (root)
    tags.add(['e', channelId, relay, 'root']);

    // Reply reference (if replying to a message)
    if (replyToId != null) {
      tags.add(['e', replyToId, relay, 'reply']);
    }

    // Author mention (if replying)
    if (replyToAuthorPubkey != null) {
      tags.add(['p', replyToAuthorPubkey]);
    }

    return tags;
  }

  /// Whether this message is a reply to another message.
  bool get isReply => replyToId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChannelMessage(id: $id, channelId: $channelId, content: ${content.length > 20 ? '${content.substring(0, 20)}...' : content})';
}
