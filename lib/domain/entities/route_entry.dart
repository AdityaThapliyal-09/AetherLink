// AetherLink AODV routing table entry entity.

import 'package:equatable/equatable.dart';

/// State of a routing table entry.
enum RouteState {
  /// Route is current and usable.
  active,

  /// Route was valid but not confirmed recently.
  stale,

  /// Route is known to be broken (RERR received).
  invalid,

  /// Route is being discovered (RREQ sent, waiting for RREP).
  discovering,
}

extension RouteStateExtension on RouteState {
  String get label {
    switch (this) {
      case RouteState.active:      return 'ACTIVE';
      case RouteState.stale:       return 'STALE';
      case RouteState.invalid:     return 'INVALID';
      case RouteState.discovering: return 'DISCOVERING';
    }
  }

  bool get isUsable => this == RouteState.active;
}

/// A single entry in the AetherLink routing table.
/// Inspired by RFC 3561 (AODV) but simplified for Bluetooth mesh.
class RouteEntry extends Equatable {
  /// The destination node ID.
  final String destinationId;

  /// The next hop node ID to reach the destination.
  final String nextHopId;

  /// Number of hops to reach the destination.
  final int hopCount;

  /// Destination sequence number (AODV freshness metric).
  final int sequenceNumber;

  /// Current state of this route.
  final RouteState state;

  /// When this route was last confirmed valid.
  final DateTime lastUpdated;

  /// When this route expires (if not refreshed).
  final DateTime expiresAt;

  /// List of node IDs that use this node as next-hop to reach the destination.
  /// Needed to send RERR to affected nodes when route breaks.
  final List<String> precursors;

  const RouteEntry({
    required this.destinationId,
    required this.nextHopId,
    required this.hopCount,
    required this.sequenceNumber,
    required this.state,
    required this.lastUpdated,
    required this.expiresAt,
    this.precursors = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isUsable => state.isUsable && !isExpired;

  RouteEntry copyWith({
    String? nextHopId,
    int? hopCount,
    int? sequenceNumber,
    RouteState? state,
    DateTime? lastUpdated,
    DateTime? expiresAt,
    List<String>? precursors,
  }) {
    return RouteEntry(
      destinationId: destinationId,
      nextHopId: nextHopId ?? this.nextHopId,
      hopCount: hopCount ?? this.hopCount,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      state: state ?? this.state,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiresAt: expiresAt ?? this.expiresAt,
      precursors: precursors ?? this.precursors,
    );
  }

  RouteEntry invalidate() => copyWith(state: RouteState.invalid);
  RouteEntry refresh(DateTime expiry) => copyWith(
    state: RouteState.active,
    lastUpdated: DateTime.now(),
    expiresAt: expiry,
  );

  @override
  List<Object?> get props => [destinationId, nextHopId, hopCount, sequenceNumber, state, lastUpdated];

  @override
  String toString() =>
      'RouteEntry($destinationId → $nextHopId, hops=$hopCount, seq=$sequenceNumber, state=${state.label})';
}

/// A pending RREQ (Route Request) in-flight.
/// Stored to avoid re-processing the same RREQ broadcast.
class PendingRouteRequest {
  final String requestId;
  final String sourceId;
  final String destinationId;
  final DateTime createdAt;
  final int broadcastId;

  const PendingRouteRequest({
    required this.requestId,
    required this.sourceId,
    required this.destinationId,
    required this.createdAt,
    required this.broadcastId,
  });

  bool get isExpired => DateTime.now().difference(createdAt).inSeconds > 30;
}
