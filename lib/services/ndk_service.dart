import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_rust_verifier/ndk_rust_verifier.dart';

import '../core/constants/relay_constants.dart';

/// Service for managing NDK (Nostr Development Kit) instance.
///
/// This service provides a singleton NDK instance configured with
/// platform-specific verifiers:
/// - Native platforms (Android, iOS, macOS, Windows, Linux): RustEventVerifier
/// - Web platform: Bip340EventVerifier (pure Dart)
///
/// Example:
/// ```dart
/// final ndk = NdkService.instance.ndk;
/// final relays = NdkService.instance.connectedRelays;
/// ```
class NdkService {
  NdkService._();

  static final NdkService _instance = NdkService._();

  /// Singleton instance of NdkService
  static NdkService get instance => _instance;

  Ndk? _ndk;

  /// Get the NDK instance, initializing it if necessary
  Ndk get ndk {
    _ndk ??= _initializeNdk();
    return _ndk!;
  }

  /// Initialize NDK with platform-specific configuration
  Ndk _initializeNdk() {
    final config = NdkConfig(
      // Use Dart verifier for web, Rust verifier for native platforms
      eventVerifier:
          kIsWeb ? Bip340EventVerifier() : RustEventVerifier(),
      // Cache manager for storing events
      cache: MemCacheManager(),
      // Bootstrap relays - these will be connected on start
      bootstrapRelays: kDefaultRelays,
    );

    final ndk = Ndk(config);

    return ndk;
  }

  /// Get list of connected relay URLs
  List<String> get connectedRelayUrls =>
      ndk.relays.connectedRelays.map((r) => r.url).toList();

  /// Check if a specific relay is connected
  bool isRelayConnected(String relayUrl) =>
      ndk.relays.isRelayConnected(relayUrl);

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
}
