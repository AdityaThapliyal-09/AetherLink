// AetherLink local node identity entity.

import 'package:equatable/equatable.dart';

/// The local AetherLink node identity.
/// Generated once on first launch and persisted securely.
class LocalIdentity extends Equatable {
  /// Unique node ID: AETH-XXXXXXXX format.
  final String nodeId;

  /// User-chosen display name.
  final String displayName;

  /// Ed25519 public key (hex-encoded) — shared with peers.
  final String edPublicKey;

  /// Ed25519 private key reference — NEVER transmitted, stored in Keystore.
  /// This is a keystore alias or a securely-stored value, not the raw key bytes.
  final String edPrivateKeyRef;

  /// X25519 public key (hex-encoded) — shared for ECDH key agreement.
  final String dhPublicKey;

  /// X25519 private key reference — NEVER transmitted.
  final String dhPrivateKeyRef;

  /// When this identity was first created.
  final DateTime createdAt;

  const LocalIdentity({
    required this.nodeId,
    required this.displayName,
    required this.edPublicKey,
    required this.edPrivateKeyRef,
    required this.dhPublicKey,
    required this.dhPrivateKeyRef,
    required this.createdAt,
  });

  /// Public key fingerprint — first 16 hex characters of edPublicKey.
  String get keyFingerprint => edPublicKey.length >= 16
      ? '${edPublicKey.substring(0, 4)}:${edPublicKey.substring(4, 8)}:'
        '${edPublicKey.substring(8, 12)}:${edPublicKey.substring(12, 16)}'.toUpperCase()
      : edPublicKey.toUpperCase();

  LocalIdentity copyWith({String? displayName}) {
    return LocalIdentity(
      nodeId: nodeId,
      displayName: displayName ?? this.displayName,
      edPublicKey: edPublicKey,
      edPrivateKeyRef: edPrivateKeyRef,
      dhPublicKey: dhPublicKey,
      dhPrivateKeyRef: dhPrivateKeyRef,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [nodeId, displayName, edPublicKey, dhPublicKey];
}
