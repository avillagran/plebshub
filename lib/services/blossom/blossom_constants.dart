/// Constants and endpoints for Blossom media servers.
///
/// Blossom is a media hosting protocol for Nostr that allows
/// decentralized file uploads using SHA-256 content addressing.
///
/// See: https://github.com/hzrd149/blossom
library;

/// Default Blossom server URL.
///
/// Primal's Blossom server is a reliable public instance.
const String kDefaultBlossomServer = 'https://blossom.primal.net';

/// List of known public Blossom servers for fallback.
const List<String> kPublicBlossomServers = [
  'https://blossom.primal.net',
  'https://blossom.oxtr.dev',
  'https://cdn.satellite.earth',
];

/// Maximum file size allowed for upload (100 MB).
const int kMaxBlossomFileSize = 100 * 1024 * 1024;

/// User-Agent header for Blossom requests.
const String kBlossomUserAgent = 'PlebsHub/1.0 (+https://plebshub.com)';

/// Allowed MIME types for Blossom uploads.
const Set<String> kAllowedBlossomMimeTypes = {
  // Images
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  // Videos
  'video/mp4',
  'video/webm',
  'video/quicktime',
  // Audio
  'audio/mpeg',
  'audio/mp4',
  'audio/ogg',
  'audio/webm',
};

/// Helper class for constructing Blossom API endpoints.
///
/// Blossom servers expose a simple REST API:
/// - `PUT /upload` - Upload a file (requires auth)
/// - `GET /list/{pubkey}` - List blobs for a public key
/// - `GET /{sha256}` - Download a blob by hash
/// - `DELETE /{sha256}` - Delete a blob (requires auth)
///
/// Example:
/// ```dart
/// final uploadUrl = BlossomEndpoints.upload(kDefaultBlossomServer);
/// final listUrl = BlossomEndpoints.list(kDefaultBlossomServer, userPubkey);
/// final blobUrl = BlossomEndpoints.get(kDefaultBlossomServer, sha256Hash);
/// ```
class BlossomEndpoints {
  BlossomEndpoints._();

  /// Upload endpoint for uploading new blobs.
  ///
  /// Method: PUT
  /// Auth: Required (Nostr kind:24242 event)
  /// Body: Raw file bytes
  /// Headers: Authorization, Content-Type, Content-Length
  static String upload(String baseUrl) => '$baseUrl/upload';

  /// List endpoint for listing blobs owned by a public key.
  ///
  /// Method: GET
  /// Auth: Optional (required for private blobs)
  /// Returns: JSON array of blob metadata
  static String list(String baseUrl, String pubkey) => '$baseUrl/list/$pubkey';

  /// Get endpoint for downloading a blob by its SHA-256 hash.
  ///
  /// Method: GET
  /// Auth: Not required (blobs are public by hash)
  /// Returns: Raw file bytes with appropriate Content-Type
  static String get(String baseUrl, String sha256) => '$baseUrl/$sha256';

  /// Delete endpoint for removing a blob.
  ///
  /// Method: DELETE
  /// Auth: Required (Nostr kind:24242 event)
  /// Only the owner (uploader) can delete a blob.
  static String delete(String baseUrl, String sha256) => '$baseUrl/$sha256';

  /// Mirror endpoint for mirroring a blob from another server.
  ///
  /// Method: PUT
  /// Auth: Required (Nostr kind:24242 event)
  /// Body: JSON with 'url' field pointing to source blob
  static String mirror(String baseUrl) => '$baseUrl/mirror';
}
