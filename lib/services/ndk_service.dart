import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ndk/domain_layer/entities/connection_source.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';

import '../core/constants/relay_constants.dart';

/// Service for managing NDK (Nostr Development Kit) instance.
///
/// This service provides a singleton NDK instance configured with
/// platform-specific verifiers:
/// - Native platforms (Android, iOS, macOS, Windows, Linux): RustEventVerifier
/// - Web platform: Bip340EventVerifier (pure Dart)
///
/// Features:
/// - Automatic relay connection on initialization
/// - Event fetching and streaming
/// - Relay connection management
///
/// Example:
/// ```dart
/// final ndk = NdkService.instance.ndk;
/// final relays = NdkService.instance.connectedRelays;
///
/// // Fetch events
/// final events = await NdkService.instance.fetchEvents(
///   filter: Filter(kinds: [1], limit: 50),
/// );
///
/// // Stream events
/// NdkService.instance.streamEvents(
///   filter: Filter(kinds: [1]),
/// ).listen((event) {
///   print('New event: ${event.id}');
/// });
/// ```
class NdkService {
  NdkService._();

  static final NdkService _instance = NdkService._();

  /// Singleton instance of NdkService
  static NdkService get instance => _instance;

  Ndk? _ndk;
  bool _isConnecting = false;
  bool _isConnected = false;

  /// Get the NDK instance, initializing it if necessary
  Ndk get ndk {
    _ndk ??= _initializeNdk();
    return _ndk!;
  }

  /// Check if relays are connected
  bool get isConnected => _isConnected;

  /// Check if currently connecting to relays
  bool get isConnecting => _isConnecting;

  /// Initialize NDK with platform-specific configuration
  Ndk _initializeNdk() {
    final config = NdkConfig(
      // Use pure Dart verifier for all platforms (Rust verifier requires Flutter 3.32+)
      eventVerifier: Bip340EventVerifier(),
      // Cache manager for storing events
      cache: MemCacheManager(),
      // Bootstrap relays - these will be connected on start
      bootstrapRelays: kDefaultRelays,
    );

    final ndk = Ndk(config);

    return ndk;
  }

  /// Connect to relays explicitly.
  ///
  /// This method ensures relays are connected. It's safe to call multiple times.
  /// Returns true if connection was successful or already connected.
  Future<bool> connectToRelays() async {
    if (_isConnected) {
      return true;
    }

    if (_isConnecting) {
      // Wait for existing connection attempt
      await Future.delayed(const Duration(milliseconds: 100));
      return _isConnected;
    }

    _isConnecting = true;

    try {
      // Connect to bootstrap relays
      for (final relayUrl in kDefaultRelays) {
        try {
          await ndk.relays.connectRelay(
            dirtyUrl: relayUrl,
            connectionSource: ConnectionSource.explicit,
          );
        } catch (e) {
          debugPrint('Failed to connect to $relayUrl: $e');
          // Continue with other relays
        }
      }

      // Wait for connections to establish (WebSocket isOpen takes time to propagate)
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      var connectedCount = 0;

      while (DateTime.now().isBefore(deadline)) {
        connectedCount = connectedRelayUrls.length;
        if (connectedCount >= kMinimumRelayCount) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _isConnected = connectedCount >= kMinimumRelayCount;
      return _isConnected;
    } catch (e) {
      debugPrint('Error connecting to relays: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Fetch events from relays using a filter.
  ///
  /// Returns a list of [Nip01Event] objects matching the filter criteria.
  ///
  /// Example:
  /// ```dart
  /// final events = await NdkService.instance.fetchEvents(
  ///   filter: Filter(kinds: [1], limit: 50),
  ///   timeout: Duration(seconds: 5),
  /// );
  /// ```
  Future<List<Nip01Event>> fetchEvents({
    required Filter filter,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Ensure relays are connected
    await connectToRelays();

    try {
      final request = ndk.requests.query(
        filters: [filter],
        explicitRelays: kDefaultRelays,
      );

      final events = <Nip01Event>[];

      await for (final event in request.stream) {
        events.add(event);
      }

      return events;
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  /// Stream events from relays using a filter.
  ///
  /// Returns an [NdkResponse] containing the stream and request ID.
  /// **Important**: The caller is responsible for closing the subscription
  /// when done by calling `closeSubscription(response.requestId)`.
  ///
  /// Example:
  /// ```dart
  /// final response = await NdkService.instance.streamEvents(
  ///   filter: Filter(kinds: [1]),
  /// );
  ///
  /// final subscription = response.stream.listen((event) {
  ///   print('New event: ${event.id}');
  /// });
  ///
  /// // When done:
  /// subscription.cancel();
  /// await NdkService.instance.closeSubscription(response.requestId);
  /// ```
  Future<NdkResponse> streamEvents({
    required Filter filter,
  }) async {
    // Ensure relays are connected
    await connectToRelays();

    final response = ndk.requests.subscription(
      filters: [filter],
    );

    return response;
  }

  /// Close a subscription by its request ID.
  ///
  /// This should be called when a subscription is no longer needed to
  /// prevent "data after EOSE" warnings and memory leaks.
  Future<void> closeSubscription(String requestId) async {
    try {
      await ndk.requests.closeSubscription(requestId);
    } catch (e) {
      debugPrint('Error closing subscription $requestId: $e');
    }
  }

  /// Get list of connected relay URLs
  ///
  /// Uses lastSuccessfulConnect timestamp instead of isOpen() which
  /// doesn't reliably report connection state in NDK 0.3.x
  List<String> get connectedRelayUrls {
    return kDefaultRelays.where((url) {
      final connectivity = ndk.relays.getRelayConnectivity(url);
      return connectivity != null &&
          connectivity.relay.lastSuccessfulConnect != null &&
          connectivity.relayTransport != null;
    }).toList();
  }

  /// Check if a specific relay is connected
  bool isRelayConnected(String relayUrl) {
    final connectivity = ndk.relays.getRelayConnectivity(relayUrl);
    return connectivity != null &&
        connectivity.relay.lastSuccessfulConnect != null &&
        connectivity.relayTransport != null;
  }

  /// Disconnect from a specific relay
  Future<void> disconnectRelay(String relayUrl) async {
    await ndk.relays.closeTransport(relayUrl);
  }

  /// Disconnect from all relays
  Future<void> disconnectAll() async {
    await ndk.relays.closeAllTransports();
  }

  /// Clean up and destroy the NDK instance
  Future<void> destroy() async {
    if (_ndk != null) {
      await _ndk!.destroy();
      _ndk = null;
    }
  }

  /// Reset NDK instance (useful for testing or switching accounts)
  void reset() {
    _ndk = null;
  }

  /// Publish a kind:1 text note event to relays.
  ///
  /// Creates a new event with the given content, signs it with the provided
  /// private key, and broadcasts it to all connected relays.
  ///
  /// Returns the published event on success, null on failure.
  ///
  /// Example:
  /// ```dart
  /// final event = await NdkService.instance.publishTextNote(
  ///   content: 'Hello Nostr!',
  ///   privateKey: userPrivateKey,
  /// );
  /// ```
  Future<Nip01Event?> publishTextNote({
    required String content,
    required String privateKey,
    List<List<String>> tags = const [],
  }) async {
    try {
      // Ensure relays are connected
      await connectToRelays();

      // Get public key from private key
      final publicKey = Bip340.getPublicKey(privateKey);

      // Create event
      final event = Nip01Event(
        pubKey: publicKey,
        kind: 1,
        content: content,
        tags: tags,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event
      event.sign(privateKey);

      // Broadcast to all connected relays using the NDK broadcast API
      final broadcastResponse = ndk.broadcast.broadcast(
        nostrEvent: event,
      );

      // Wait for broadcast to complete
      await broadcastResponse.broadcastDoneFuture;

      return event;
    } catch (e) {
      debugPrint('Error publishing event: $e');
      return null;
    }
  }
}
