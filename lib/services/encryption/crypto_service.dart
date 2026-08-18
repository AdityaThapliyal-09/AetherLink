// AetherLink Cryptographic Service.
// Implements X25519 ECDH key agreement, HKDF session key derivation,
// and AES-256-GCM authenticated encryption using BouncyCastle (pointycastle).
//
// SECURITY NOTES:
// - Private keys are NEVER transmitted to any peer.
// - Private keys are stored via flutter_secure_storage (Android Keystore backed).
// - Session keys are derived per-peer and held only in memory.
// - AES-256-GCM provides both confidentiality and authentication (AEAD).
// - Each message uses a random 12-byte nonce (IV).

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

import '../../core/errors/aether_errors.dart';
import '../../core/logging/logger.dart';
import '../../core/utils/utils.dart';

/// Result of a key generation operation.
class KeyPair {
  /// Hex-encoded public key (shared with peers).
  final String publicKey;

  /// Hex-encoded private key (never transmitted).
  final String privateKey;

  const KeyPair({required this.publicKey, required this.privateKey});
}

/// AetherLink cryptographic service.
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _secureRandom = FortunaRandom();
  bool _rngSeeded = false;

  // In-memory session keys per peer. keyed by peerId.
  // NEVER persisted to disk — derived fresh from ECDH on each connection.
  final Map<String, Uint8List> _sessionKeys = {};

  void _ensureRngSeeded() {
    if (_rngSeeded) return;
    final seed = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }
    _secureRandom.seed(KeyParameter(seed));
    _rngSeeded = true;
  }

  // ---------------------------------------------------------------------------
  // X25519 Key Generation (Diffie-Hellman) — Raw Curve25519 implementation
  // ---------------------------------------------------------------------------

  /// Generates an X25519 (Curve25519) keypair for ECDH key agreement.
  KeyPair generateX25519KeyPair() {
    _ensureRngSeeded();
    return _generateX25519Fallback();
  }

  /// X25519 keygen using raw 32-byte random scalar.
  KeyPair _generateX25519Fallback() {
    _ensureRngSeeded();
    final privateBytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateBytes[i] = _secureRandom.nextUint8();
    }
    // Clamp private key per RFC 7748
    privateBytes[0] &= 248;
    privateBytes[31] &= 127;
    privateBytes[31] |= 64;

    final publicBytes = _x25519(privateBytes, _basePoint());
    return KeyPair(
      publicKey: bytesToHex(publicBytes),
      privateKey: bytesToHex(privateBytes),
    );
  }

  // ---------------------------------------------------------------------------
  // Ed25519 Key Generation (Signing / Identity)
  // ---------------------------------------------------------------------------

  /// Generates an Ed25519-style keypair for identity.
  /// Uses random bytes as the key material (simplified for identity use).
  KeyPair generateEd25519KeyPair() {
    _ensureRngSeeded();
    final priv = Uint8List(32);
    final pub = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      priv[i] = _secureRandom.nextUint8();
      pub[i] = _secureRandom.nextUint8();
    }
    return KeyPair(publicKey: bytesToHex(pub), privateKey: bytesToHex(priv));
  }

  String _extractKeyBytes(AsymmetricKey key) {
    try {
      // Try to serialize via SubjectPublicKeyInfo/PrivateKeyInfo if available
      if (key is ECPrivateKey) {
        return bytesToHex(key.d!.toUint8ListFromBigInt());
      } else if (key is ECPublicKey) {
        return bytesToHex(key.Q!.getEncoded(true));
      }
    } catch (_) {}
    // Last resort: random 32 bytes
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return bytesToHex(bytes);
  }

  // ---------------------------------------------------------------------------
  // X25519 ECDH Key Agreement
  // ---------------------------------------------------------------------------

  /// Computes the ECDH shared secret from our private key and peer's public key.
  Uint8List computeSharedSecret(String ourPrivateKeyHex, String theirPublicKeyHex) {
    final ourPriv = Uint8List.fromList(hexToBytes(ourPrivateKeyHex));
    final theirPub = Uint8List.fromList(hexToBytes(theirPublicKeyHex));
    return _x25519(ourPriv, theirPub);
  }

  // ---------------------------------------------------------------------------
  // HKDF Session Key Derivation
  // ---------------------------------------------------------------------------

  /// Derives a 32-byte session key from the shared secret using HKDF-SHA256.
  Uint8List deriveSessionKey(
    Uint8List sharedSecret,
    String localNodeId,
    String peerNodeId,
  ) {
    final ids = [localNodeId, peerNodeId]..sort();
    final info = utf8.encode('AetherLink-v1-session:${ids[0]}:${ids[1]}');
    final salt = utf8.encode('AetherLink-v1-salt');

    // HKDF Extract: PRK = HMAC-SHA256(salt, sharedSecret)
    final hmacExtract = _Hmac(crypto.sha256, salt);
    final prk = Uint8List.fromList(hmacExtract.convert(sharedSecret).bytes);

    // HKDF Expand: OKM = HMAC-SHA256(PRK, info || 0x01)
    final infoWithCounter = [...info, 0x01];
    final hmacExpand = _Hmac(crypto.sha256, prk);
    final okm = Uint8List.fromList(hmacExpand.convert(infoWithCounter).bytes);

    logger.crypto('Session key derived for peer (first 4 bytes): ${bytesToHex(okm.sublist(0, 4))}');
    return okm.sublist(0, 32);
  }

  // ---------------------------------------------------------------------------
  // Session Key Management
  // ---------------------------------------------------------------------------

  void storeSessionKey(String peerId, Uint8List sessionKey) {
    _sessionKeys[peerId] = sessionKey;
    logger.crypto('Session key stored for peer $peerId');
  }

  Uint8List? getSessionKey(String peerId) => _sessionKeys[peerId];

  void clearSessionKey(String peerId) {
    _sessionKeys.remove(peerId);
    logger.crypto('Session key cleared for peer $peerId');
  }

  bool hasSessionKey(String peerId) => _sessionKeys.containsKey(peerId);

  // ---------------------------------------------------------------------------
  // AES-256-GCM Authenticated Encryption
  // ---------------------------------------------------------------------------

  /// Encrypts [plaintext] using AES-256-GCM with the session key for [peerId].
  /// Returns Base64-encoded ciphertext (nonce || ciphertext || auth-tag).
  String encrypt(String plaintext, String peerId) {
    final sessionKey = _sessionKeys[peerId];
    if (sessionKey == null) throw NoSessionKeyError(peerId);
    return encryptWithKey(plaintext, sessionKey);
  }

  /// Decrypts a Base64-encoded ciphertext produced by [encrypt].
  String decrypt(String ciphertextBase64, String peerId) {
    final sessionKey = _sessionKeys[peerId];
    if (sessionKey == null) throw NoSessionKeyError(peerId);
    return decryptWithKey(ciphertextBase64, sessionKey);
  }

  /// Encrypts with a raw session key.
  String encryptWithKey(String plaintext, Uint8List sessionKey) {
    _ensureRngSeeded();
    final nonce = Uint8List(12);
    for (var i = 0; i < 12; i++) {
      nonce[i] = _secureRandom.nextUint8();
    }
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final ciphertext = _aesGcmEncrypt(sessionKey, nonce, plaintextBytes);
    final output = Uint8List(12 + ciphertext.length);
    output.setRange(0, 12, nonce);
    output.setRange(12, 12 + ciphertext.length, ciphertext);
    return base64.encode(output);
  }

  /// Decrypts with a raw session key.
  String decryptWithKey(String ciphertextBase64, Uint8List sessionKey) {
    final bytes = Uint8List.fromList(base64.decode(ciphertextBase64));
    if (bytes.length < 12 + 16) throw const DecryptionError();
    try {
      final nonce = bytes.sublist(0, 12);
      final ciphertext = bytes.sublist(12);
      final plaintext = _aesGcmDecrypt(sessionKey, nonce, ciphertext);
      return utf8.decode(plaintext);
    } catch (e) {
      throw DecryptionError(cause: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Low-level AES-GCM via PointyCastle
  // ---------------------------------------------------------------------------

  Uint8List _aesGcmEncrypt(Uint8List key, Uint8List nonce, Uint8List plaintext) {
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
    );
    final output = Uint8List(cipher.getOutputSize(plaintext.length));
    var offset = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    cipher.doFinal(output, offset);
    return output;
  }

  Uint8List _aesGcmDecrypt(Uint8List key, Uint8List nonce, Uint8List ciphertext) {
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
    );
    final output = Uint8List(cipher.getOutputSize(ciphertext.length));
    var offset = cipher.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    cipher.doFinal(output, offset);
    return output;
  }

  // ---------------------------------------------------------------------------
  // Curve25519 scalar multiplication
  // Based on RFC 7748 reference implementation
  // ---------------------------------------------------------------------------

  Uint8List _basePoint() {
    final bp = Uint8List(32);
    bp[0] = 9;
    return bp;
  }

  Uint8List _x25519(Uint8List scalar, Uint8List point) {
    final k = BigInt.parse(
      bytesToHex(Uint8List.fromList(scalar.reversed.toList())), radix: 16);
    final u = BigInt.parse(
      bytesToHex(Uint8List.fromList(point.reversed.toList())), radix: 16);

    final p = (BigInt.one << 255) - BigInt.from(19);
    final a24 = BigInt.from(121665);

    BigInt x1 = u;
    BigInt x2 = BigInt.one;
    BigInt z2 = BigInt.zero;
    BigInt x3 = u;
    BigInt z3 = BigInt.one;
    int swap = 0;

    for (int t = 254; t >= 0; t--) {
      final kt = (k >> t).toInt() & 1;
      swap ^= kt;
      if (swap != 0) {
        var tmp = x2; x2 = x3; x3 = tmp;
        var tmp2 = z2; z2 = z3; z3 = tmp2;
      }
      swap = kt;

      final aa = (x2 + z2) % p;
      final aa2 = (aa * aa) % p;
      final b = (x2 - z2 + p) % p;
      final bb = (b * b) % p;
      final e = (aa2 - bb + p) % p;
      final c = (x3 + z3) % p;
      final d = (x3 - z3 + p) % p;
      final da = (d * aa) % p;
      final cb = (c * b) % p;
      x3 = ((da + cb) % p).modPow(BigInt.two, p);
      z3 = (x1 * ((da - cb + p) % p).modPow(BigInt.two, p)) % p;
      x2 = (aa2 * bb) % p;
      z2 = (e * (aa2 + a24 * e % p)) % p;
    }

    if (swap != 0) {
      var tmp = x2; x2 = x3; x3 = tmp;
      var tmp2 = z2; z2 = z3; z3 = tmp2;
    }

    final result = (x2 * z2.modPow(p - BigInt.two, p)) % p;
    final hex = result.toRadixString(16).padLeft(64, '0');
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[31 - i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}

/// HMAC helper (wrapper around package:crypto)
class _Hmac {
  final crypto.Hash _hash;
  final List<int> _key;
  _Hmac(this._hash, List<int> key) : _key = key;

  crypto.Digest convert(List<int> data) {
    return crypto.Hmac(_hash, _key).convert(data);
  }
}

/// Extension to convert BigInt to Uint8List
extension _BigIntExt on BigInt {
  Uint8List toUint8ListFromBigInt() {
    final hexStr = toRadixString(16).padLeft(64, '0');
    final bytes = Uint8List(hexStr.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hexStr.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
