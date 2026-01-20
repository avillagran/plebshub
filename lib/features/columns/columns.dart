/// Columns feature - TweetDeck-style multi-column layout.
///
/// This feature provides a multi-column desktop layout where users can:
/// - Add multiple columns showing different content types
/// - Reorder columns via drag-and-drop
/// - Remove columns they don't need
/// - Use preset layouts for common configurations
///
/// Column types available:
/// - Home: User's home feed (following)
/// - Explore: Global feed
/// - Hashtag: Posts with a specific hashtag (#bitcoin, #nostr)
/// - User: Posts from a specific user
/// - Notifications: User's notifications
/// - Messages: Direct messages (NIP-04/NIP-17)
/// - Channel: IRC-style chat (NIP-28)
/// - Search: Search results

// Models
export 'models/column_config.dart';

// Providers
export 'providers/columns_provider.dart';

// Widgets
export 'widgets/multi_column_layout.dart';
export 'widgets/column_widget.dart';
