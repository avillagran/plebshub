import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/key_service.dart';
import '../../../services/secure_storage_service.dart';
import 'auth_state.dart';

/// Provider for KeyService
final keyServiceProvider = Provider<KeyService>((ref) => KeyService());

/// Provider for SecureStorageService
final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

/// Provider for authentication state and actions.
///
/// This provider manages the user's authentication state and provides
/// methods for:
/// - Generating new keypairs
/// - Importing existing keys (nsec/hex)
/// - Checking existing authentication
/// - Logging out
///
/// Example:
/// ```dart
/// // In a widget
/// final authState = ref.watch(authProvider);
/// final authNotifier = ref.read(authProvider.notifier);
///
/// // Generate new identity
/// await authNotifier.generateNewIdentity();
///
/// // Import from nsec
/// await authNotifier.importFromNsec('nsec1...');
///
/// // Logout
/// await authNotifier.logout();
/// ```
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    keyService: ref.watch(keyServiceProvider),
    storageService: ref.watch(secureStorageServiceProvider),
  );
});

/// Notifier for managing authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required KeyService keyService,
    required SecureStorageService storageService,
  })  : _keyService = keyService,
        _storageService = storageService,
        super(const AuthStateUnauthenticated()) {
    // Check for existing authentication on initialization
    _checkExistingAuth();
  }

  final KeyService _keyService;
  final SecureStorageService _storageService;

  /// Check if user is already authenticated (has stored keypair).
  Future<void> _checkExistingAuth() async {
    try {
      final keypairData = await _storageService.loadKeypair();

      if (keypairData != null) {
        final privateKey = keypairData['privateKey']!;
        final nsec = keypairData['nsec']!;
        final npub = keypairData['npub']!;

        // Recreate keypair
        final keypair = await Future(() => _keyService.importFromHex(privateKey));

        state = AuthStateAuthenticated(
          keypair: keypair,
          nsec: nsec,
          npub: npub,
        );

        debugPrint('Restored authentication from storage: $npub');
      }
    } catch (e) {
      debugPrint('Error checking existing auth: $e');
      // If there's an error loading, remain unauthenticated
      state = const AuthStateUnauthenticated();
    }
  }

  /// Generate a new Nostr identity.
  ///
  /// Creates a new keypair, saves it to secure storage, and updates state.
  Future<void> generateNewIdentity() async {
    state = const AuthStateLoading(operation: 'generating');

    try {
      // Generate keypair
      final keypair = await Future(() => _keyService.generateKeypair());

      // Get bech32 formats (already generated in keypair)
      final nsec = keypair.privateKeyBech32!;
      final npub = keypair.publicKeyBech32!;

      // Save to secure storage
      final saved = await _storageService.saveKeypair(
        privateKey: keypair.privateKey!,
        publicKey: keypair.publicKey,
        nsec: nsec,
        npub: npub,
      );

      if (!saved && !kIsWeb) {
        throw Exception('Failed to save keypair to secure storage');
      }

      // Update state
      state = AuthStateAuthenticated(
        keypair: keypair,
        nsec: nsec,
        npub: npub,
      );

      debugPrint('Generated new identity: $npub');
    } catch (e, stackTrace) {
      debugPrint('Error generating identity: $e\n$stackTrace');
      state = AuthStateError(
        message: 'Failed to generate new identity: ${e.toString()}',
        previousState: const AuthStateUnauthenticated(),
      );
    }
  }

  /// Import an existing identity from nsec key.
  ///
  /// Validates the nsec, imports the keypair, saves to storage, and updates state.
  Future<void> importFromNsec(String nsec) async {
    state = const AuthStateLoading(operation: 'importing');

    try {
      // Import and validate
      final keypair = await Future(() => _keyService.importFromNsec(nsec));

      // Get bech32 formats (already in keypair)
      final npub = keypair.publicKeyBech32!;

      // Save to secure storage
      final saved = await _storageService.saveKeypair(
        privateKey: keypair.privateKey!,
        publicKey: keypair.publicKey,
        nsec: nsec,
        npub: npub,
      );

      if (!saved && !kIsWeb) {
        throw Exception('Failed to save keypair to secure storage');
      }

      // Update state
      state = AuthStateAuthenticated(
        keypair: keypair,
        nsec: nsec,
        npub: npub,
      );

      debugPrint('Imported identity from nsec: $npub');
    } catch (e, stackTrace) {
      debugPrint('Error importing from nsec: $e\n$stackTrace');
      state = AuthStateError(
        message: 'Failed to import key: ${e.toString()}',
        previousState: const AuthStateUnauthenticated(),
      );
    }
  }

  /// Import an existing identity from hex private key.
  ///
  /// Validates the hex key, imports the keypair, saves to storage, and updates state.
  Future<void> importFromHex(String privateKeyHex) async {
    state = const AuthStateLoading(operation: 'importing');

    try {
      // Import and validate
      final keypair = await Future(() => _keyService.importFromHex(privateKeyHex));

      // Get bech32 formats (already in keypair)
      final nsec = keypair.privateKeyBech32!;
      final npub = keypair.publicKeyBech32!;

      // Save to secure storage
      final saved = await _storageService.saveKeypair(
        privateKey: keypair.privateKey!,
        publicKey: keypair.publicKey,
        nsec: nsec,
        npub: npub,
      );

      if (!saved && !kIsWeb) {
        throw Exception('Failed to save keypair to secure storage');
      }

      // Update state
      state = AuthStateAuthenticated(
        keypair: keypair,
        nsec: nsec,
        npub: npub,
      );

      debugPrint('Imported identity from hex: $npub');
    } catch (e, stackTrace) {
      debugPrint('Error importing from hex: $e\n$stackTrace');
      state = AuthStateError(
        message: 'Failed to import key: ${e.toString()}',
        previousState: const AuthStateUnauthenticated(),
      );
    }
  }

  /// Logout the current user.
  ///
  /// Deletes the keypair from secure storage and resets to unauthenticated state.
  Future<void> logout() async {
    try {
      // Delete from secure storage
      await _storageService.deleteKeypair();

      // Reset state
      state = const AuthStateUnauthenticated();

      debugPrint('User logged out');
    } catch (e) {
      debugPrint('Error logging out: $e');
      // Even if delete fails, reset state
      state = const AuthStateUnauthenticated();
    }
  }

  /// Clear error state and return to previous state or unauthenticated.
  void clearError() {
    if (state is AuthStateError) {
      final errorState = state as AuthStateError;
      state = errorState.previousState ?? const AuthStateUnauthenticated();
    }
  }

  /// Check if user is currently authenticated.
  bool get isAuthenticated => state is AuthStateAuthenticated;

  /// Get the current user's npub (if authenticated).
  String? get currentNpub {
    final currentState = state;
    if (currentState is AuthStateAuthenticated) {
      return currentState.npub;
    }
    return null;
  }

  /// Get the current user's public key in hex (if authenticated).
  String? get currentPublicKey {
    final currentState = state;
    if (currentState is AuthStateAuthenticated) {
      return currentState.keypair.publicKey;
    }
    return null;
  }
}
