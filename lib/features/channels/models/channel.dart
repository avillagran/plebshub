import 'dart:convert';

/// Model representing a Nostr public chat channel (NIP-28).
///
/// Channels are created with kind:40 events and can have their metadata
/// updated with kind:41 events.
///
/// Example:
/// ```dart
/// final channel = Channel(
///   id: 'event-id',
///   name: 'nostr-dev',
///   about: 'Nostr development discussion',
///   picture: 'https://example.com/icon.png',
///   creatorPubkey: 'creator-pubkey',
///   createdAt: DateTime.now(),
/// );
/// ```
class Channel {
  /// Creates a new Channel.
  const Channel({
    required this.id,
    required this.name,
    this.about,
    this.picture,
    required this.creatorPubkey,
    required this.createdAt,
    this.relayUrl,
  });

  /// The channel ID (event ID of the kind:40 creation event).
  final String id;

  /// Channel name.
  final String name;

  /// Channel description/about text.
  final String? about;

  /// Channel picture URL.
  final String? picture;

  /// Public key of the channel creator.
  final String creatorPubkey;

  /// When the channel was created.
  final DateTime createdAt;

  /// Recommended relay URL for the channel.
  final String? relayUrl;

  /// Create a Channel from a kind:40 Nostr event.
  ///
  /// The event content should be a JSON object with:
  /// - name: Channel name (required)
  /// - about: Channel description (optional)
  /// - picture: Channel image URL (optional)
  factory Channel.fromEvent({
    required String eventId,
    required String content,
    required String pubkey,
    required int createdAt,
    String? relayUrl,
  }) {
    // Parse JSON content
    Map<String, dynamic> metadata = {};
    try {
      metadata = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      // If parsing fails, use empty metadata
    }

    return Channel(
      id: eventId,
      name: metadata['name'] as String? ?? 'Unnamed Channel',
      about: metadata['about'] as String?,
      picture: metadata['picture'] as String?,
      creatorPubkey: pubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      relayUrl: relayUrl,
    );
  }

  /// Create a copy with updated metadata from a kind:41 event.
  Channel copyWithMetadata({
    String? name,
    String? about,
    String? picture,
  }) {
    return Channel(
      id: id,
      name: name ?? this.name,
      about: about ?? this.about,
      picture: picture ?? this.picture,
      creatorPubkey: creatorPubkey,
      createdAt: createdAt,
      relayUrl: relayUrl,
    );
  }

  /// Convert to JSON for creating kind:40 event content.
  String toEventContent() {
    final data = <String, dynamic>{
      'name': name,
    };

    if (about != null && about!.isNotEmpty) {
      data['about'] = about;
    }

    if (picture != null && picture!.isNotEmpty) {
      data['picture'] = picture;
    }

    return jsonEncode(data);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Channel(id: $id, name: $name)';
}
