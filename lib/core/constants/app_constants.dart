/// Application-wide constants.
abstract final class AppConstants {
  /// The application name.
  static const appName = 'PlebsHub';

  /// The application version.
  static const version = '0.1.0';

  /// Default relay list for new users.
  /// Note: Primary list is kDefaultRelays in relay_constants.dart
  static const defaultRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.snort.social',
    'wss://relay.primal.net',
    'wss://purplepag.es',
    'wss://nostr.wine',
  ];

  /// Default zap amount in sats.
  static const defaultZapAmount = 21;

  /// Maximum columns in multi-column layout.
  static const maxColumns = 5;

  /// Minimum column width in pixels.
  static const minColumnWidth = 300.0;
}
