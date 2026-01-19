import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';
part 'post.g.dart';

/// UI model for displaying a Nostr post/note.
///
/// This model represents a denormalized view of a Nostr event (kind:1)
/// with additional metadata needed for UI display.
///
/// Example:
/// ```dart
/// final post = Post(
///   id: 'event-id',
///   author: PostAuthor(
///     pubkey: 'user-pubkey',
///     displayName: 'Alice',
///     nip05: 'alice@example.com',
///   ),
///   content: 'Hello Nostr!',
///   createdAt: DateTime.now(),
///   reactionsCount: 5,
///   repostsCount: 2,
///   zapsCount: 1,
/// );
/// ```
@freezed
class Post with _$Post {
  const factory Post({
    /// Event ID (32-byte hex string)
    required String id,

    /// Author information
    required PostAuthor author,

    /// Post content (text)
    required String content,

    /// When the post was created
    required DateTime createdAt,

    /// Number of reactions (likes) this post has received
    @Default(0) int reactionsCount,

    /// Number of times this post has been reposted
    @Default(0) int repostsCount,

    /// Number of zaps (Lightning payments) this post has received
    @Default(0) int zapsCount,

    /// Reply-to event ID (if this is a reply)
    String? replyToId,

    /// Root event ID (for threading)
    String? rootEventId,

    /// Number of replies to this post
    @Default(0) int replyCount,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}

/// Author information for a post.
@freezed
class PostAuthor with _$PostAuthor {
  const factory PostAuthor({
    /// Author's public key (32-byte hex string)
    required String pubkey,

    /// Display name (from kind:0 metadata, or truncated pubkey if not available)
    required String displayName,

    /// NIP-05 verification (e.g., alice@example.com)
    String? nip05,

    /// Profile picture URL
    String? picture,

    /// About/bio text
    String? about,
  }) = _PostAuthor;

  factory PostAuthor.fromJson(Map<String, dynamic> json) =>
      _$PostAuthorFromJson(json);
}
