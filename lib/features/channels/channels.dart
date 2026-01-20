/// Channels feature - NIP-28 public chat channels.
///
/// This feature provides IRC-style public chat channels using NIP-28:
/// - kind:40 = channel creation
/// - kind:41 = channel metadata update
/// - kind:42 = channel message
/// - kind:43 = hide message (moderation)
/// - kind:44 = mute user (moderation)

// Models
export 'models/channel.dart';
export 'models/channel_message.dart';

// Providers
export 'providers/channel_provider.dart';

// Screens
export 'screens/channels_list_screen.dart';
export 'screens/channel_chat_screen.dart';

// Widgets
export 'widgets/channel_message_bubble.dart';
export 'widgets/create_channel_dialog.dart';
