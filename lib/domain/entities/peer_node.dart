// AetherLink peer/node entity.

import 'package:equatable/equatable.dart';

/// Connection state of a discovered peer.
enum PeerConnectionState {
  /// Being scanned/discovered via BLE advertising.
  discovering,

  /// Initiating BLE GATT connection.
  connecting,

  /// GATT connection established.
  connected,

  /// Exchanging identity and cryptographic keys.
  authenticating,

  /// Key exchange complete — ready for encrypted messaging.
  ready,

  /// Connection lost.
  disconnected,

  /// Attempting to reconnect.
  retrying,

  /// Persistent connection failure.
  error,
}

extension PeerConnectionStateExtension on PeerConnectionState {
  String get label {
    switch (this) {
      case PeerConnectionState.discovering:   return 'Scanning';
      case PeerConnectionState.connecting:    return 'Connecting';
      case PeerConnectionState.connected:     return 'Connected';
      case PeerConnectionState.authenticating: return 'Authenticating';
      case PeerConnectionState.ready:         return 'Ready';
      case PeerConnectionState.disconnected:  return 'Disconnected';
      case PeerConnectionState.retrying:      return 'Retrying';
      case PeerConnectionState.error:         return 'Error';
    }
  }

  bool get isReachable =>
      this == PeerConnectionState.connected ||
      this == PeerConnectionState.authenticating ||
      this == PeerConnectionState.ready;
}

/// Represents a discovered AetherLink peer node.
class PeerNode extends Equatable {
  /// The peer's unique AetherLink node ID (e.g. AETH-A1B2C3D4).
  final String nodeId;

  /// Human-readable display name chosen by the peer.
  final String displayName;

  /// The peer's Ed25519 public key (hex-encoded) — null if not yet exchanged.
  final String? publicKey;

  /// The peer's X25519 public key for ECDH (hex-encoded) — null if not yet exchanged.
  final String? dhPublicKey;

  /// Current connection state.
  final PeerConnectionState connectionState;

  /// Latest RSSI value (signal strength in dBm) — null if not a direct peer.
  final int? rssi;

  /// Hop count to reach this peer (0 = direct connection, >0 = via relay).
  final int hopCount;

  /// Whether this peer has been cryptographically verified by fingerprint.
  final bool isTrusted;

  /// When we last received any packet from this peer.
  final DateTime? lastSeen;

  /// The node ID of the next hop to reach this peer (null if direct).
  final String? nextHopId;

  const PeerNode({
    required this.nodeId,
    required this.displayName,
    required this.connectionState,
    this.publicKey,
    this.dhPublicKey,
    this.rssi,
    this.hopCount = 0,
    this.isTrusted = false,
    this.lastSeen,
    this.nextHopId,
  });

  bool get isDirect => hopCount == 0;
  bool get isReady => connectionState == PeerConnectionState.ready;
  bool get hasPublicKey => publicKey != null;

  /// Short 4-char node ID for display (e.g. "A1B2").
  String get shortId => nodeId.length >= 4
      ? nodeId.substring(nodeId.length - 4).toUpperCase()
      : nodeId;

  /// Public key fingerprint (first 16 hex chars of public key).
  String get keyFingerprint => publicKey != null && publicKey!.length >= 16
      ? publicKey!.substring(0, 16).toUpperCase()
      : 'Not exchanged';

  PeerNode copyWith({
    String? displayName,
    String? publicKey,
    String? dhPublicKey,
    PeerConnectionState? connectionState,
    int? rssi,
    int? hopCount,
    bool? isTrusted,
    DateTime? lastSeen,
    String? nextHopId,
  }) {
    return PeerNode(
      nodeId: nodeId,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey ?? this.publicKey,
      dhPublicKey: dhPublicKey ?? this.dhPublicKey,
      connectionState: connectionState ?? this.connectionState,
      rssi: rssi ?? this.rssi,
      hopCount: hopCount ?? this.hopCount,
      isTrusted: isTrusted ?? this.isTrusted,
      lastSeen: lastSeen ?? this.lastSeen,
      nextHopId: nextHopId ?? this.nextHopId,
    );
  }

  @override
  List<Object?> get props => [nodeId, displayName, publicKey, dhPublicKey,
      connectionState, rssi, hopCount, isTrusted, lastSeen, nextHopId];
}
