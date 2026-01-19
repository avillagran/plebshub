import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';
import 'package:ndk/shared/nips/nip19/nip19.dart';

/// Service for managing Nostr keypairs.
///
/// This service provides methods for:
/// - Generating new Nostr keypairs
/// - Validating and importing keys (nsec/hex formats)
/// - Converting between key formats
/// - Deriving public keys from private keys
///
/// Example:
/// ```dart
/// final keyService = KeyService();
///
/// // Generate new keypair
/// final keypair = keyService.generateKeypair();
///
/// // Import from nsec
/// final keypair = keyService.importFromNsec('nsec1...');
///
/// // Convert to bech32 formats
/// final nsec = keyService.privateKeyToNsec(keypair.privateKey);
/// final npub = keyService.publicKeyToNpub(keypair.publicKey);
/// ```
class KeyService {
  /// Generate a new Nostr keypair.
  ///
  /// Returns a [KeyPair] with generated private and public keys.
  KeyPair generateKeypair() {
    return Bip340.generatePrivateKey();
  }

  /// Import a keypair from an nsec (bech32-encoded private key).
  ///
  /// Throws [FormatException] if the nsec format is invalid.
  /// Throws [ArgumentError] if the decoded key is invalid.
  KeyPair importFromNsec(String nsec) {
    if (nsec.isEmpty) {
      throw ArgumentError('nsec cannot be empty');
    }

    if (!nsec.startsWith('nsec1')) {
      throw FormatException('Invalid nsec format: must start with nsec1');
    }

    try {
      final privateKeyHex = Nip19.decode(nsec);
      return _keypairFromPrivateKey(privateKeyHex);
    } catch (e) {
      throw FormatException('Invalid nsec key: $e');
    }
  }

  /// Import a keypair from a hex-encoded private key.
  ///
  /// Throws [FormatException] if the hex format is invalid.
  /// Throws [ArgumentError] if the key length is invalid.
  KeyPair importFromHex(String privateKeyHex) {
    if (privateKeyHex.isEmpty) {
      throw ArgumentError('Private key cannot be empty');
    }

    // Remove any whitespace
    final cleaned = privateKeyHex.replaceAll(RegExp(r'\s+'), '');

    // Validate hex format
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned)) {
      throw FormatException('Invalid hex format: must contain only hex characters');
    }

    // Nostr private keys should be 64 hex characters (32 bytes)
    if (cleaned.length != 64) {
      throw ArgumentError('Invalid private key length: expected 64 hex characters, got ${cleaned.length}');
    }

    try {
      return _keypairFromPrivateKey(cleaned.toLowerCase());
    } catch (e) {
      throw FormatException('Invalid private key: $e');
    }
  }

  /// Convert a private key (hex) to nsec format (bech32).
  String privateKeyToNsec(String privateKeyHex) {
    if (privateKeyHex.isEmpty) {
      throw ArgumentError('Private key cannot be empty');
    }
    return Nip19.encodePrivateKey(privateKeyHex);
  }

  /// Convert a public key (hex) to npub format (bech32).
  String publicKeyToNpub(String publicKeyHex) {
    if (publicKeyHex.isEmpty) {
      throw ArgumentError('Public key cannot be empty');
    }
    return Nip19.encodePubKey(publicKeyHex);
  }

  /// Convert npub to hex public key.
  ///
  /// Throws [FormatException] if the npub format is invalid.
  String npubToPublicKey(String npub) {
    if (npub.isEmpty) {
      throw ArgumentError('npub cannot be empty');
    }

    if (!npub.startsWith('npub1')) {
      throw FormatException('Invalid npub format: must start with npub1');
    }

    try {
      return Nip19.decode(npub);
    } catch (e) {
      throw FormatException('Invalid npub key: $e');
    }
  }

  /// Validate if a string is a valid nsec key.
  bool isValidNsec(String nsec) {
    try {
      importFromNsec(nsec);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validate if a string is a valid hex private key.
  bool isValidHexPrivateKey(String hex) {
    try {
      importFromHex(hex);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validate if a string is a valid npub key.
  bool isValidNpub(String npub) {
    try {
      npubToPublicKey(npub);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create a keypair from a private key hex string.
  ///
  /// This derives the public key from the private key.
  KeyPair _keypairFromPrivateKey(String privateKeyHex) {
    // Use NDK's method to derive public key from private key
    final publicKeyHex = Bip340.getPublicKey(privateKeyHex);
    final nsec = Nip19.encodePrivateKey(privateKeyHex);
    final npub = Nip19.encodePubKey(publicKeyHex);
    return KeyPair(privateKeyHex, publicKeyHex, nsec, npub);
  }
}
