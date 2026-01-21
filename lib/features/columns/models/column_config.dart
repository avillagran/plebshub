import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'column_config.freezed.dart';
part 'column_config.g.dart';

/// Types of columns available in the multi-column layout.
///
/// Each type represents a different content source or view:
/// - [home]: Home feed showing posts from followed users
/// - [explore]: Global/explore feed with trending content
/// - [hashtag]: Posts containing a specific hashtag
/// - [user]: Posts from a specific user
/// - [channel]: NIP-28 IRC-style channel chat
/// - [notifications]: User's notifications
/// - [messages]: Direct messages (NIP-04/NIP-17)
/// - [search]: Search results
enum ColumnType {
  /// Home feed (following)
  home,

  /// Global/explore feed
  explore,

  /// Hashtag feed (#bitcoin, #nostr)
  hashtag,

  /// Specific user's posts
  user,

  /// IRC-style channel (NIP-28)
  channel,

  /// User notifications
  notifications,

  /// Direct messages
  messages,

  /// Search results
  search,
}

/// Configuration for a single column in the multi-column layout.
///
/// Each column has a unique ID and a type that determines what content
/// it displays. Additional properties like [hashtag], [userPubkey], etc.
/// are used depending on the column type.
///
/// Example:
/// ```dart
/// final homeColumn = ColumnConfig(
///   id: 'col-home-1',
///   type: ColumnType.home,
///   position: 0,
/// );
///
/// final hashtagColumn = ColumnConfig(
///   id: 'col-hashtag-bitcoin',
///   type: ColumnType.hashtag,
///   hashtag: 'bitcoin',
///   position: 1,
/// );
/// ```
@freezed
class ColumnConfig with _$ColumnConfig {
  const factory ColumnConfig({
    /// Unique identifier for this column (UUID)
    required String id,

    /// Type of content this column displays
    required ColumnType type,

    /// Custom title for the column (uses default based on type if null)
    String? title,

    /// Hashtag to display (required for [ColumnType.hashtag])
    String? hashtag,

    /// User's public key (required for [ColumnType.user])
    String? userPubkey,

    /// Channel ID (required for [ColumnType.channel])
    String? channelId,

    /// Search query (required for [ColumnType.search])
    String? searchQuery,

    /// Column width in logical pixels
    @Default(350) double width,

    /// Position in the column order (0-indexed, left to right)
    @Default(0) int position,
  }) = _ColumnConfig;

  /// Private constructor required for custom getters ([displayTitle], [icon]).
  const ColumnConfig._();

  factory ColumnConfig.fromJson(Map<String, dynamic> json) =>
      _$ColumnConfigFromJson(json);

  /// Returns the display title for this column.
  ///
  /// If a custom [title] is set, returns that. Otherwise returns
  /// a default title based on the column [type]:
  /// - home: "Home"
  /// - explore: "Explore"
  /// - hashtag: "#bitcoin" (uses the hashtag value)
  /// - user: "User" (or custom title showing username)
  /// - channel: "Channel" (or custom title showing channel name)
  /// - notifications: "Notifications"
  /// - messages: "Messages"
  /// - search: "Search: query" (uses the search query)
  String get displayTitle {
    if (title != null) return title!;

    switch (type) {
      case ColumnType.home:
        return 'Home';
      case ColumnType.explore:
        return 'Explore';
      case ColumnType.hashtag:
        return hashtag != null ? '#$hashtag' : 'Hashtag';
      case ColumnType.user:
        // Show truncated pubkey for user columns
        if (userPubkey != null && userPubkey!.isNotEmpty) {
          if (userPubkey!.startsWith('npub1')) {
            return '@${userPubkey!.substring(0, 12)}...';
          }
          return '@${userPubkey!.substring(0, 8)}...';
        }
        return 'User';
      case ColumnType.channel:
        return 'Channel';
      case ColumnType.notifications:
        return 'Notifications';
      case ColumnType.messages:
        return 'Messages';
      case ColumnType.search:
        return searchQuery != null ? 'Search: $searchQuery' : 'Search';
    }
  }

  /// Returns the appropriate icon for this column type.
  ///
  /// Icons are from Material Design:
  /// - home: home icon
  /// - explore: explore icon
  /// - hashtag: tag icon
  /// - user: person icon
  /// - channel: forum/chat icon
  /// - notifications: notifications icon
  /// - messages: mail icon
  /// - search: search icon
  IconData get icon {
    switch (type) {
      case ColumnType.home:
        return Icons.home_outlined;
      case ColumnType.explore:
        return Icons.explore_outlined;
      case ColumnType.hashtag:
        return Icons.tag;
      case ColumnType.user:
        return Icons.person_outlined;
      case ColumnType.channel:
        return Icons.forum_outlined;
      case ColumnType.notifications:
        return Icons.notifications_outlined;
      case ColumnType.messages:
        return Icons.mail_outlined;
      case ColumnType.search:
        return Icons.search;
    }
  }
}
