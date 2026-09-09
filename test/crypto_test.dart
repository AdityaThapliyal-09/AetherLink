import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink/services/encryption/crypto_service.dart';

void main() {
  group('CryptoService Tests', () {
    late CryptoService crypto;

    setUp(() {
      crypto = CryptoService();
    });

    test('ECDH key agreement and AES-GCM encryption/decryption', () {
      final pairA = crypto.generateX25519KeyPair();
      final pairB = crypto.generateX25519KeyPair();

      final secretA = crypto.computeSharedSecret(pairA.privateKey, pairB.publicKey);
      final secretB = crypto.computeSharedSecret(pairB.privateKey, pairA.publicKey);

      expect(secretA, equals(secretB), reason: 'Shared secrets must match');

      final keyA = crypto.deriveSessionKey(secretA, 'AETH-AAAA', 'AETH-BBBB');
      final keyB = crypto.deriveSessionKey(secretB, 'AETH-BBBB', 'AETH-AAAA');

      expect(keyA, equals(keyB), reason: 'Derived session keys must match');

      final testMessages = [
        'hi',
        'Hello AetherLink!',
        'A very long message with unicode emojis 🚀🔥🛡️ and symbols: ~!@#\$%^&*()_+=-`{}|[]\\:";\'<>?,./',
        'Testing 123 456 789 0',
      ];

      for (final msg in testMessages) {
        final encrypted = crypto.encryptWithKey(msg, keyA);
        final decrypted = crypto.decryptWithKey(encrypted, keyB);
        expect(decrypted, equals(msg), reason: 'Decrypted message must match original for: $msg');
      }
    });

    test('Session key storage and encrypt/decrypt methods', () {
      final pairA = crypto.generateX25519KeyPair();
      final pairB = crypto.generateX25519KeyPair();

      final secret = crypto.computeSharedSecret(pairA.privateKey, pairB.publicKey);
      final key = crypto.deriveSessionKey(secret, 'AETH-NODE1', 'AETH-NODE2');

      crypto.storeSessionKey('AETH-NODE2', key);
      expect(crypto.hasSessionKey('AETH-NODE2'), isTrue);

      final ciphertext = crypto.encrypt('Direct session test message', 'AETH-NODE2');
      final decrypted = crypto.decrypt(ciphertext, 'AETH-NODE2');
      expect(decrypted, equals('Direct session test message'));
    });
  });
}
