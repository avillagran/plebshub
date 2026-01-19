import 'package:isar/isar.dart';

part 'nostr_event.g.dart';

/// Isar collection schema for Nostr events (kind:1 notes).
///
/// Stores basic text notes following NIP-01 event structure.
/// Additional event kinds will be added as features are implemented.
@collection
class NostrEvent {
  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.content,
    required this.tags,
    required this.sig,
  });

  /// Isar's internal auto-increment ID.
  Id get isarId => fastHash(id);

  /// Event ID (32-byte hex string).
  @Index(unique: true)
  late String id;

  /// Public key of event creator (32-byte hex string).
  @Index()
  late String pubkey;

  /// Unix timestamp (seconds since epoch).
  @Index()
  late int createdAt;

  /// Event kind (1 = text note, per NIP-01).
  @Index()
  late int kind;

  /// Event content (text for kind:1).
  late String content;

  /// Tags as JSON-encoded list of lists.
  ///
  /// Stored as List\<String\> where each string is a JSON array.
  /// Example: ["e", "event-id", "relay-url", "marker"]
  late List<String> tags;

  /// Event signature (64-byte hex string).
  late String sig;

  /// Generate a fast hash for the event ID to use as Isar ID.
  ///
  /// Uses FNV-1a hash algorithm on the hex string.
  static Id fastHash(String string) {
    var hash = 0xcbf29ce484222325;

    var i = 0;
    while (i < string.length) {
      final codeUnit = string.codeUnitAt(i++);
      hash ^= codeUnit >> 8;
      hash *= 0x100000001b3;
      hash ^= codeUnit & 0xFF;
      hash *= 0x100000001b3;
    }

    return hash;
  }
}
