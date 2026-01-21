import 'dart:convert';

import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';

import 'blossom_constants.dart';

/// Blossom authentication event generator.
///
/// Blossom servers use NIP-98 HTTP Auth with kind:24242 events
/// to authenticate requests. This class generates and encodes
/// these authentication events.
///
/// The authentication flow:
/// 1. Create a kind:24242 event with appropriate tags
/// 2. Sign the event with the user's private key
/// 3. Encode the event as base64 JSON
/// 4. Add to request as `Authorization: Nostr <base64>`
///
/// Example:
/// ```dart
/// final auth = BlossomAuth();
/// final header = auth.createAuthHeader(
///   method: 'upload',
///   sha256: fileHash,
///   privateKey: userPrivateKey,
///   expiration: DateTime.now().add(Duration(minutes: 5)),
/// );
/// // header = 'Nostr eyJ...'
/// ```
class BlossomAuth {
  /// Blossom auth event kind (NIP-98 inspired)
  static const int authEventKind = 24242;

  /// Default expiration duration for auth events
  static const Duration defaultExpiration = Duration(minutes: 5);

  /// Creates a kind:24242 authentication event for Blossom.
  ///
  /// Parameters:
  /// - [method]: The HTTP method being authorized ('upload', 'delete', 'list')
  /// - [sha256]: SHA-256 hash of the content (for upload/delete)
  /// - [privateKey]: User's private key (hex) for signing
  /// - [expiration]: When the auth expires (default: 5 minutes)
  /// - [serverUrl]: Optional server URL to include in event
  ///
  /// Returns: A signed [Nip01Event] ready for encoding.
  Nip01Event createAuthEvent({
    required String method,
    required String privateKey,
    String? sha256,
    DateTime? expiration,
    String? serverUrl,
  }) {
    final publicKey = Bip340.getPublicKey(privateKey);
    final exp = expiration ?? DateTime.now().add(defaultExpiration);
    final expUnix = (exp.millisecondsSinceEpoch / 1000).round().toString();

    // Build tags according to Blossom spec
    final tags = <List<String>>[
      ['t', method.toLowerCase()],
      ['expiration', expUnix],
    ];

    // Add hash tag if provided (required for upload/delete)
    if (sha256 != null && sha256.isNotEmpty) {
      tags.add(['x', sha256]);
    }

    // Optionally add server URL
    if (serverUrl != null) {
      tags.add(['u', serverUrl]);
    }

    // Create and sign the event
    return Nip01Event(
      pubKey: publicKey,
      kind: authEventKind,
      content: 'Authorize $method',
      tags: tags,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    )..sign(privateKey);
  }

  /// Creates the Authorization header value for Blossom requests.
  ///
  /// Returns a string in format: `Nostr <base64-encoded-event-json>`
  ///
  /// Parameters:
  /// - [method]: The HTTP method being authorized
  /// - [privateKey]: User's private key (hex) for signing
  /// - [sha256]: SHA-256 hash of the content (optional)
  /// - [expiration]: When the auth expires (optional)
  /// - [serverUrl]: Server URL to include (optional)
  ///
  /// Example:
  /// ```dart
  /// final auth = BlossomAuth();
  /// final header = auth.createAuthHeader(
  ///   method: 'upload',
  ///   sha256: 'abc123...',
  ///   privateKey: myPrivateKey,
  /// );
  /// request.headers['Authorization'] = header;
  /// ```
  String createAuthHeader({
    required String method,
    required String privateKey,
    String? sha256,
    DateTime? expiration,
    String? serverUrl,
  }) {
    final event = createAuthEvent(
      method: method,
      privateKey: privateKey,
      sha256: sha256,
      expiration: expiration,
      serverUrl: serverUrl,
    );

    return encodeEventToHeader(event);
  }

  /// Encodes a signed event to the Authorization header format.
  ///
  /// Format: `Nostr <base64(json(event))>`
  ///
  /// The event JSON includes all standard fields:
  /// - id, pubkey, created_at, kind, tags, content, sig
  String encodeEventToHeader(Nip01Event event) {
    final eventJson = {
      'id': event.id,
      'pubkey': event.pubKey,
      'created_at': event.createdAt,
      'kind': event.kind,
      'tags': event.tags,
      'content': event.content,
      'sig': event.sig,
    };

    final jsonString = jsonEncode(eventJson);
    final base64Encoded = base64Encode(utf8.encode(jsonString));

    return 'Nostr $base64Encoded';
  }

  /// Validates an auth event has required fields.
  ///
  /// Checks:
  /// - Event is kind 24242
  /// - Has 't' tag with method
  /// - Has 'expiration' tag with valid timestamp
  /// - Expiration is in the future
  /// - Has valid signature
  bool isValidAuthEvent(Nip01Event event) {
    if (event.kind != authEventKind) {
      return false;
    }

    // Check for method tag
    final methodTag = event.tags.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 't',
      orElse: () => [],
    );
    if (methodTag.length < 2) {
      return false;
    }

    // Check for expiration tag
    final expTag = event.tags.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 'expiration',
      orElse: () => [],
    );
    if (expTag.length < 2) {
      return false;
    }

    // Verify expiration is in the future
    final expUnix = int.tryParse(expTag[1]);
    if (expUnix == null) {
      return false;
    }
    final expiration = DateTime.fromMillisecondsSinceEpoch(expUnix * 1000);
    if (expiration.isBefore(DateTime.now())) {
      return false;
    }

    // Verify signature exists and is not empty
    return event.sig.isNotEmpty;
  }

  /// Creates auth headers for upload operation.
  ///
  /// Convenience method that includes proper Content-Type header.
  ///
  /// Returns a map of headers to add to the upload request.
  Map<String, String> createUploadHeaders({
    required String sha256,
    required String privateKey,
    required String mimeType,
    required int contentLength,
    String? serverUrl,
  }) {
    final authHeader = createAuthHeader(
      method: 'upload',
      sha256: sha256,
      privateKey: privateKey,
      serverUrl: serverUrl,
    );

    return {
      'Authorization': authHeader,
      'Content-Type': mimeType,
      'Content-Length': contentLength.toString(),
      'User-Agent': kBlossomUserAgent,
    };
  }

  /// Creates auth headers for delete operation.
  ///
  /// Returns a map of headers to add to the delete request.
  Map<String, String> createDeleteHeaders({
    required String sha256,
    required String privateKey,
    String? serverUrl,
  }) {
    final authHeader = createAuthHeader(
      method: 'delete',
      sha256: sha256,
      privateKey: privateKey,
      serverUrl: serverUrl,
    );

    return {
      'Authorization': authHeader,
      'User-Agent': kBlossomUserAgent,
    };
  }

  /// Creates auth headers for list operation.
  ///
  /// List operation doesn't require sha256 since it lists all blobs.
  /// Returns a map of headers to add to the list request.
  Map<String, String> createListHeaders({
    required String privateKey,
    String? serverUrl,
  }) {
    final authHeader = createAuthHeader(
      method: 'list',
      privateKey: privateKey,
      serverUrl: serverUrl,
    );

    return {
      'Authorization': authHeader,
      'User-Agent': kBlossomUserAgent,
    };
  }
}
