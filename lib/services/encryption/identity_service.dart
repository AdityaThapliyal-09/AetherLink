// AetherLink Identity Service.
// Manages the local node's cryptographic identity:
// - Node ID generation and persistence
// - Ed25519 + X25519 keypair generation
// - flutter_secure_storage for private key protection
// - Display name management

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/logging/logger.dart';
import '../../core/utils/utils.dart';
import '../../data/database/daos.dart';
import '../../domain/entities/local_identity.dart';
import 'crypto_service.dart';

class IdentityService {
  static final IdentityService _instance = IdentityService._internal();
  factory IdentityService() => _instance;
  IdentityService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Uses Android Keystore — keys survive app reinstall only if backed up
    ),
  );

  // Storage keys for flutter_secure_storage
  static const _kNodeId = 'aetherlink_node_id';
  static const _kEdPrivKey = 'aetherlink_ed_priv';
  static const _kEdPubKey = 'aetherlink_ed_pub';
  static const _kDhPrivKey = 'aetherlink_dh_priv';
  static const _kDhPubKey = 'aetherlink_dh_pub';
  static const _kDisplayName = 'aetherlink_display_name';
  static const _kCreatedAt = 'aetherlink_created_at';

  late IdentityDao _identityDao;
  LocalIdentity? _cachedIdentity;

  void configure(IdentityDao identityDao) {
    _identityDao = identityDao;
  }

  /// Returns the local identity, creating it if this is the first launch.
  Future<LocalIdentity> getOrCreateIdentity() async {
    if (_cachedIdentity != null) return _cachedIdentity!;

    // Check secure storage first (fastest path)
    final storedNodeId = await _storage.read(key: _kNodeId);
    if (storedNodeId != null) {
      final identity = await _loadFromStorage(storedNodeId);
      _cachedIdentity = identity;
      logger.crypto('Identity loaded: ${identity.nodeId}');
      return identity;
    }

    // First launch — generate new identity
    return _createNewIdentity();
  }

  Future<LocalIdentity> _loadFromStorage(String nodeId) async {
    final edPub  = await _storage.read(key: _kEdPubKey) ?? '';
    final edPriv = await _storage.read(key: _kEdPrivKey) ?? '';
    final dhPub  = await _storage.read(key: _kDhPubKey) ?? '';
    final dhPriv = await _storage.read(key: _kDhPrivKey) ?? '';
    final name   = await _storage.read(key: _kDisplayName) ?? 'AetherNode';
    final createdAtMs = int.tryParse(
        await _storage.read(key: _kCreatedAt) ?? '0') ?? 0;

    return LocalIdentity(
      nodeId: nodeId,
      displayName: name,
      edPublicKey: edPub,
      edPrivateKeyRef: edPriv, // stored value IS the private key (Keystore-protected)
      dhPublicKey: dhPub,
      dhPrivateKeyRef: dhPriv,
      createdAt: createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
    );
  }

  Future<LocalIdentity> _createNewIdentity() async {
    logger.crypto('Generating new AetherLink identity...');
    final crypto = CryptoService();

    final nodeId = generateNodeId();
    final edPair = crypto.generateEd25519KeyPair();
    final dhPair = crypto.generateX25519KeyPair();
    final now = DateTime.now();

    // Persist all values to Android Keystore-backed secure storage
    await _storage.write(key: _kNodeId, value: nodeId);
    await _storage.write(key: _kEdPubKey, value: edPair.publicKey);
    await _storage.write(key: _kEdPrivKey, value: edPair.privateKey);
    await _storage.write(key: _kDhPubKey, value: dhPair.publicKey);
    await _storage.write(key: _kDhPrivKey, value: dhPair.privateKey);
    await _storage.write(key: _kDisplayName, value: 'AetherNode');
    await _storage.write(key: _kCreatedAt, value: now.millisecondsSinceEpoch.toString());

    final identity = LocalIdentity(
      nodeId: nodeId,
      displayName: 'AetherNode',
      edPublicKey: edPair.publicKey,
      edPrivateKeyRef: edPair.privateKey,
      dhPublicKey: dhPair.publicKey,
      dhPrivateKeyRef: dhPair.privateKey,
      createdAt: now,
    );

    // Also save to SQLite for UI queries
    await _identityDao.saveIdentity(identity);

    _cachedIdentity = identity;
    logger.crypto('New identity created: $nodeId');
    logger.crypto('Ed25519 public key: ${edPair.publicKey.substring(0, 16)}...');
    return identity;
  }

  /// Updates the display name and persists it.
  Future<void> updateDisplayName(String newName) async {
    final identity = await getOrCreateIdentity();
    await _storage.write(key: _kDisplayName, value: newName);
    await _identityDao.updateDisplayName(identity.nodeId, newName);
    _cachedIdentity = identity.copyWith(displayName: newName);
    logger.system('Display name updated to: $newName');
  }

  /// Returns the DH private key for ECDH computation.
  /// Called only during key exchange — never transmitted.
  Future<String> getDhPrivateKey() async {
    if (_cachedIdentity?.dhPrivateKeyRef != null &&
        _cachedIdentity!.dhPrivateKeyRef.isNotEmpty) {
      return _cachedIdentity!.dhPrivateKeyRef;
    }
    return await _storage.read(key: _kDhPrivKey) ?? '';
  }

  /// Clears all identity data. Requires user confirmation before calling.
  Future<void> deleteIdentity() async {
    logger.crypto('Identity deletion requested — clearing all keys', level: LogLevel.warning);
    await _storage.deleteAll();
    _cachedIdentity = null;
  }

  LocalIdentity? get cachedIdentity => _cachedIdentity;
}
