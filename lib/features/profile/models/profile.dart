import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:ndk/ndk.dart';

/// A user profile from Nostr (kind:0 metadata).
///
/// Contains all standard NIP-01 metadata fields plus helper methods
/// for display formatting.
///
/// Example:
/// ```dart
/// final profile = Profile.fromEvent(kind0Event);
/// print(profile.displayName); // "Alice"
/// print(profile.shortenedNpub); // "npub1abc...xyz"
/// ```
class Profile extends Equatable {
  const Profile({
    required this.pubkey,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.nip05,
    this.lud16,
    this.website,
    this.createdAt,
  });

  /// The user's public key in hex format.
  final String pubkey;

  /// The user's name (NIP-01 "name" field).
  final String? name;

  /// The user's display name (NIP-01 "display_name" field).
  final String? displayName;

  /// The user's bio/about text (NIP-01 "about" field).
  final String? about;

  /// URL to the user's profile picture.
  final String? picture;

  /// URL to the user's banner/header image.
  final String? banner;

  /// NIP-05 verification identifier (e.g., "alice@example.com").
  final String? nip05;

  /// Lightning address for receiving payments (e.g., "alice@getalby.com").
  final String? lud16;

  /// User's website URL.
  final String? website;

  /// When the profile metadata was last updated.
  final DateTime? createdAt;

  /// Creates a Profile from a Nostr kind:0 event.
  ///
  /// Parses the event content as JSON and extracts standard metadata fields.
  /// Returns a Profile with just the pubkey if content is invalid.
  factory Profile.fromEvent(Nip01Event event) {
    if (event.kind != 0) {
      throw ArgumentError('Profile.fromEvent requires kind:0 event, got kind:${event.kind}');
    }

    Map<String, dynamic>? metadata;
    try {
      metadata = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (e) {
      // Invalid JSON, return profile with just pubkey
      return Profile(
        pubkey: event.pubKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      );
    }

    return Profile(
      pubkey: event.pubKey,
      name: metadata['name'] as String?,
      displayName: metadata['display_name'] as String?,
      about: metadata['about'] as String?,
      picture: metadata['picture'] as String?,
      banner: metadata['banner'] as String?,
      nip05: metadata['nip05'] as String?,
      lud16: metadata['lud16'] as String?,
      website: metadata['website'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }

  /// Creates a placeholder Profile with only a pubkey.
  ///
  /// Useful when profile metadata hasn't been fetched yet.
  factory Profile.placeholder(String pubkey) {
    return Profile(pubkey: pubkey);
  }

  /// Returns the best available name for display.
  ///
  /// Priority: displayName > name > shortened pubkey
  String get nameForDisplay {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return shortenedPubkey;
  }

  /// Returns a shortened version of the pubkey for display.
  ///
  /// Format: first 8 chars ... last 4 chars
  /// Example: "abc12345...wxyz"
  String get shortenedPubkey {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }

  /// Returns the npub-formatted pubkey (shortened for display).
  ///
  /// Note: This is a display helper that creates a npub prefix.
  /// For actual bech32 encoding, use a proper encoder.
  String get shortenedNpub {
    // Show as npub1abc...xyz format for display
    return 'npub1${pubkey.substring(0, 4)}...${pubkey.substring(pubkey.length - 4)}';
  }

  /// Returns the @username for display (using name or shortened pubkey).
  String get atUsername {
    if (name != null && name!.isNotEmpty) {
      return '@$name';
    }
    return '@${shortenedPubkey}';
  }

  /// Returns the NIP-05 username part (before the @).
  ///
  /// Example: "alice@example.com" -> "alice"
  String? get nip05Username {
    if (nip05 == null) return null;
    final parts = nip05!.split('@');
    if (parts.isEmpty) return null;
    // If it starts with _, it's the root identifier
    if (parts[0] == '_') return null;
    return parts[0];
  }

  /// Returns the NIP-05 domain part (after the @).
  ///
  /// Example: "alice@example.com" -> "example.com"
  String? get nip05Domain {
    if (nip05 == null) return null;
    final parts = nip05!.split('@');
    if (parts.length < 2) return null;
    return parts[1];
  }

  /// Creates a copy of this Profile with the given fields replaced.
  Profile copyWith({
    String? pubkey,
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? nip05,
    String? lud16,
    String? website,
    DateTime? createdAt,
  }) {
    return Profile(
      pubkey: pubkey ?? this.pubkey,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      picture: picture ?? this.picture,
      banner: banner ?? this.banner,
      nip05: nip05 ?? this.nip05,
      lud16: lud16 ?? this.lud16,
      website: website ?? this.website,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts the Profile to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'pubkey': pubkey,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (about != null) 'about': about,
      if (picture != null) 'picture': picture,
      if (banner != null) 'banner': banner,
      if (nip05 != null) 'nip05': nip05,
      if (lud16 != null) 'lud16': lud16,
      if (website != null) 'website': website,
      if (createdAt != null) 'created_at': createdAt!.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Creates a Profile from a JSON map.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      pubkey: json['pubkey'] as String,
      name: json['name'] as String?,
      displayName: json['display_name'] as String?,
      about: json['about'] as String?,
      picture: json['picture'] as String?,
      banner: json['banner'] as String?,
      nip05: json['nip05'] as String?,
      lud16: json['lud16'] as String?,
      website: json['website'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        pubkey,
        name,
        displayName,
        about,
        picture,
        banner,
        nip05,
        lud16,
        website,
        createdAt,
      ];

  @override
  String toString() => 'Profile(pubkey: $shortenedPubkey, name: $name)';
}
