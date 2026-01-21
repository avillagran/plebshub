/// Default Nostr relays for the application.
///
/// These relays are used as the initial connection points when the user
/// first starts the app. Users can add/remove relays in settings.
const List<String> kDefaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.snort.social',
  'wss://relay.primal.net',
  'wss://purplepag.es',
  'wss://nostr.wine',
];

/// Minimum number of relays that should be connected
const int kMinimumRelayCount = 2;

/// Maximum number of concurrent relay connections
const int kMaximumRelayCount = 10;

/// Relay connection timeout in seconds
const int kRelayConnectionTimeout = 10;

/// Relay reconnection delay in seconds
const int kRelayReconnectionDelay = 5;
