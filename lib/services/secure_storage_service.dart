import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for platform-agnostic secure storage.
///
/// This service provides secure key-value storage:
/// - Mobile/Desktop: Uses flutter_secure_storage (encrypted keychain/keystore)
/// - Web: Returns null (web apps should use NIP-07 browser extensions)
///
/// Keys are stored encrypted on native platforms using:
/// - iOS/macOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Windows: DPAPI
/// - Linux: libsecret
///
/// Example:
/// ```dart
/// final storage = SecureStorageService();
///
/// // Write
/// await storage.write(key: 'private_key', value: 'nsec1...');
///
/// // Read
/// final key = await storage.read(key: 'private_key');
///
/// // Delete
/// await storage.delete(key: 'private_key');
/// ```
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // Storage keys
  static const String keyPrivateKey = 'nostr_private_key';
  static const String keyPublicKey = 'nostr_public_key';
  static const String keyNsec = 'nostr_nsec';
  static const String keyNpub = 'nostr_npub';

  /// Read a value from secure storage.
  ///
  /// Returns null if the key doesn't exist or on web platform.
  Future<String?> read({required String key}) async {
    if (kIsWeb) {
      // Web apps should not store private keys locally
      // They should use NIP-07 browser extensions instead
      return null;
    }

    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error reading from secure storage: $e');
      return null;
    }
  }

  /// Write a value to secure storage.
  ///
  /// On web platform, this is a no-op (returns false).
  Future<bool> write({required String key, required String value}) async {
    if (kIsWeb) {
      // Web apps should not store private keys locally
      debugPrint('Warning: Attempted to write to secure storage on web platform');
      return false;
    }

    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      debugPrint('Error writing to secure storage: $e');
      return false;
    }
  }

  /// Delete a value from secure storage.
  Future<bool> delete({required String key}) async {
    if (kIsWeb) {
      return false;
    }

    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      debugPrint('Error deleting from secure storage: $e');
      return false;
    }
  }

  /// Delete all values from secure storage.
  Future<bool> deleteAll() async {
    if (kIsWeb) {
      return false;
    }

    try {
      await _storage.deleteAll();
      return true;
    } catch (e) {
      debugPrint('Error deleting all from secure storage: $e');
      return false;
    }
  }

  /// Check if storage contains a key.
  Future<bool> containsKey({required String key}) async {
    if (kIsWeb) {
      return false;
    }

    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('Error checking key in secure storage: $e');
      return false;
    }
  }

  /// Read all keys from secure storage.
  Future<Map<String, String>> readAll() async {
    if (kIsWeb) {
      return {};
    }

    try {
      return await _storage.readAll();
    } catch (e) {
      debugPrint('Error reading all from secure storage: $e');
      return {};
    }
  }

  // Convenience methods for Nostr keys

  /// Save a complete keypair to secure storage.
  Future<bool> saveKeypair({
    required String privateKey,
    required String publicKey,
    required String nsec,
    required String npub,
  }) async {
    if (kIsWeb) {
      return false;
    }

    try {
      await Future.wait([
        write(key: keyPrivateKey, value: privateKey),
        write(key: keyPublicKey, value: publicKey),
        write(key: keyNsec, value: nsec),
        write(key: keyNpub, value: npub),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error saving keypair: $e');
      return false;
    }
  }

  /// Load the stored keypair.
  ///
  /// Returns a map with keys: privateKey, publicKey, nsec, npub.
  /// Returns null if no keypair is stored.
  Future<Map<String, String>?> loadKeypair() async {
    if (kIsWeb) {
      // TODO: Check for NIP-07 extension availability
      return null;
    }

    try {
      final results = await Future.wait([
        read(key: keyPrivateKey),
        read(key: keyPublicKey),
        read(key: keyNsec),
        read(key: keyNpub),
      ]);

      final privateKey = results[0];
      final publicKey = results[1];
      final nsec = results[2];
      final npub = results[3];

      if (privateKey == null || publicKey == null) {
        return null;
      }

      return {
        'privateKey': privateKey,
        'publicKey': publicKey,
        'nsec': nsec ?? '',
        'npub': npub ?? '',
      };
    } catch (e) {
      debugPrint('Error loading keypair: $e');
      return null;
    }
  }

  /// Delete the stored keypair.
  Future<bool> deleteKeypair() async {
    if (kIsWeb) {
      return false;
    }

    try {
      await Future.wait([
        delete(key: keyPrivateKey),
        delete(key: keyPublicKey),
        delete(key: keyNsec),
        delete(key: keyNpub),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error deleting keypair: $e');
      return false;
    }
  }

  /// Check if a keypair is stored.
  Future<bool> hasKeypair() async {
    if (kIsWeb) {
      // TODO: Check for NIP-07 extension
      return false;
    }

    return await containsKey(key: keyPrivateKey);
  }
}
