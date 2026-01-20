import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage service with SharedPreferences fallback for macOS.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  SharedPreferences? _fallbackPrefs;
  bool _useFallback = false;
  bool _initializingFallback = false;
  static const String _fallbackPrefix = 'nostr_secure_';

  // Storage keys
  static const String keyPrivateKey = 'nostr_private_key';
  static const String keyPublicKey = 'nostr_public_key';
  static const String keyNsec = 'nostr_nsec';
  static const String keyNpub = 'nostr_npub';

  /// Initialize fallback if Keychain doesn't work (macOS without certificate)
  Future<void> _initFallbackIfNeeded() async {
    if (_fallbackPrefs != null || _initializingFallback) return;
    if (!Platform.isMacOS && !Platform.isLinux) return;

    _initializingFallback = true;
    try {
      // Test if secure storage works
      await _storage.write(key: '_test', value: 'test');
      await _storage.delete(key: '_test');
    } catch (e) {
      debugPrint('[SecureStorage] Keychain failed, using SharedPreferences fallback');
      _useFallback = true;
      _fallbackPrefs = await SharedPreferences.getInstance();
    } finally {
      _initializingFallback = false;
    }
  }

  Future<String?> read({required String key}) async {
    if (kIsWeb) return null;
    await _initFallbackIfNeeded();

    if (_useFallback && _fallbackPrefs != null) {
      return _fallbackPrefs!.getString('$_fallbackPrefix$key');
    }

    try {
      return await _storage.read(key: key);
    } catch (e) {
      return null;
    }
  }

  Future<bool> write({required String key, required String value}) async {
    if (kIsWeb) return false;
    await _initFallbackIfNeeded();

    if (_useFallback && _fallbackPrefs != null) {
      return await _fallbackPrefs!.setString('$_fallbackPrefix$key', value);
    }

    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      // Try fallback on error
      _useFallback = true;
      _fallbackPrefs ??= await SharedPreferences.getInstance();
      return await _fallbackPrefs!.setString('$_fallbackPrefix$key', value);
    }
  }

  Future<bool> delete({required String key}) async {
    if (kIsWeb) return false;
    await _initFallbackIfNeeded();

    if (_useFallback && _fallbackPrefs != null) {
      return await _fallbackPrefs!.remove('$_fallbackPrefix$key');
    }

    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> containsKey({required String key}) async {
    if (kIsWeb) return false;
    await _initFallbackIfNeeded();

    if (_useFallback && _fallbackPrefs != null) {
      return _fallbackPrefs!.containsKey('$_fallbackPrefix$key');
    }

    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveKeypair({
    required String privateKey,
    required String publicKey,
    required String nsec,
    required String npub,
  }) async {
    if (kIsWeb) return false;

    final r1 = await write(key: keyPrivateKey, value: privateKey);
    final r2 = await write(key: keyPublicKey, value: publicKey);
    final r3 = await write(key: keyNsec, value: nsec);
    final r4 = await write(key: keyNpub, value: npub);

    return r1 && r2 && r3 && r4;
  }

  Future<Map<String, String>?> loadKeypair() async {
    if (kIsWeb) return null;

    final privateKey = await read(key: keyPrivateKey);
    final publicKey = await read(key: keyPublicKey);

    if (privateKey == null || publicKey == null) return null;

    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
      'nsec': await read(key: keyNsec) ?? '',
      'npub': await read(key: keyNpub) ?? '',
    };
  }

  Future<bool> deleteKeypair() async {
    if (kIsWeb) return false;

    await delete(key: keyPrivateKey);
    await delete(key: keyPublicKey);
    await delete(key: keyNsec);
    await delete(key: keyNpub);
    return true;
  }

  Future<bool> hasKeypair() async {
    if (kIsWeb) return false;
    return await containsKey(key: keyPrivateKey);
  }
}
