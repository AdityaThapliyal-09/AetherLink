// AetherLink AODV Routing Manager.
// Implements a simplified version of AODV (RFC 3561) for Bluetooth mesh routing.
//
// Key concepts:
// - RREQ (Route Request): broadcast when no route is known to destination
// - RREP (Route Reply): unicast reply from destination or intermediate node
// - RERR (Route Error): sent when a previously valid route breaks
// - Routing Table: maps destination → {nextHop, hopCount, seqNum, state}
// - Sequence numbers: ensure freshness of routing information
// - Reverse path: RREQ establishes reverse routes as it propagates
//
// Simplifications vs. RFC 3561:
// - No RREQ retransmission timer (simplified retry)
// - No expanding ring search
// - Route discovery timeout simplified

import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/errors/aether_errors.dart';
import '../../core/logging/logger.dart';
import '../../core/utils/utils.dart';
import '../../data/database/daos.dart';
import '../../domain/entities/aether_packet.dart';
import '../../domain/entities/route_entry.dart';

/// Callback for when a packet needs to be forwarded/sent to a specific peer.
typedef PacketSender = Future<void> Function(String peerId, AetherPacket packet);

/// Callback for broadcasting a packet to all directly connected peers.
typedef PacketBroadcaster = Future<void> Function(AetherPacket packet, {String? excludePeer});

class AodvManager {
  final RoutingTableDao _routingDao;
  final String localNodeId;

  PacketSender? _sendTo;
  PacketBroadcaster? _broadcast;

  // In-memory routing table (mirrors SQLite, faster access)
  final Map<String, RouteEntry> _routes = {};

  // Seen RREQ broadcast IDs to prevent re-processing: key = "srcId:broadcastId"
  final Map<String, DateTime> _seenRreqs = {};

  // Pending route discoveries: destinationId → completer
  final Map<String, Completer<RouteEntry>> _pendingDiscoveries = {};

  // RREQ sequence number (incremented per RREQ we originate)
  int _rreqSeqNum = 0;

  AodvManager({
    required this.localNodeId,
    required RoutingTableDao routingDao,
  })  : _routingDao = routingDao;

  void configure({
    required PacketSender sendTo,
    required PacketBroadcaster broadcast,
  }) {
    _sendTo = sendTo;
    _broadcast = broadcast;
  }

  // ---------------------------------------------------------------------------
  // Route Lookup
  // ---------------------------------------------------------------------------

  /// Returns a usable route to [destinationId], or null if none exists.
  RouteEntry? getRoute(String destinationId) {
    final route = _routes[destinationId];
    if (route == null) return null;
    if (!route.isUsable) return null;
    return route;
  }

  /// Returns true if we have a usable route to [destinationId].
  bool hasRoute(String destinationId) => getRoute(destinationId) != null;

  List<RouteEntry> getAllRoutes() => List.unmodifiable(_routes.values.toList());

  // ---------------------------------------------------------------------------
  // Route Installation (from RREP or direct connection)
  // ---------------------------------------------------------------------------

  /// Installs a direct route when we connect directly to a peer.
  Future<void> installDirectRoute(String peerId) async {
    final now = DateTime.now();
    final route = RouteEntry(
      destinationId: peerId,
      nextHopId: peerId, // Direct: next hop IS the destination
      hopCount: 0,
      sequenceNumber: generateSequenceNumber(),
      state: RouteState.active,
      lastUpdated: now,
      expiresAt: now.add(const Duration(seconds: AppConstants.routeExpirySeconds)),
    );
    await _upsertRoute(route);
    logger.routing('Direct route installed: $peerId → $peerId (0 hops)');
  }

  /// Invalidates a route when a link breaks.
  Future<void> invalidateRoute(String destinationId) async {
    final existing = _routes[destinationId];
    if (existing == null) return;

    final invalid = existing.invalidate();
    _routes[destinationId] = invalid;
    await _routingDao.invalidateRoute(destinationId);

    logger.routing('Route invalidated: $destinationId', level: LogLevel.warning);

    // Notify pending discovery completers that the route failed
    _pendingDiscoveries[destinationId]?.completeError(NoRouteError(destinationId));
    _pendingDiscoveries.remove(destinationId);
  }

  /// Called when a peer disconnects — invalidates all routes through that peer.
  Future<void> onPeerDisconnected(String peerId) async {
    logger.routing('Peer disconnected: $peerId — invalidating affected routes');

    // Remove the direct route to this peer
    await invalidateRoute(peerId);

    // Invalidate any routes that use this peer as next hop
    final affectedRoutes = _routes.values
        .where((r) => r.nextHopId == peerId && r.destinationId != peerId)
        .toList();

    for (final route in affectedRoutes) {
      await invalidateRoute(route.destinationId);
      // Send RERR to precursors (nodes that route through us to this destination)
      await _sendRouteError(route.destinationId, route.precursors);
    }
  }

  // ---------------------------------------------------------------------------
  // Route Discovery (RREQ / RREP)
  // ---------------------------------------------------------------------------

  /// Initiates route discovery to [destinationId].
  /// Returns a Future that completes when a route is found, or throws [NoRouteError].
  Future<RouteEntry> discoverRoute(String destinationId) async {
    // If we already have a valid route, return it immediately
    final existing = getRoute(destinationId);
    if (existing != null) return existing;

    // If discovery is already in progress, wait for the same completer
    if (_pendingDiscoveries.containsKey(destinationId)) {
      return _pendingDiscoveries[destinationId]!.future;
    }

    final completer = Completer<RouteEntry>();
    _pendingDiscoveries[destinationId] = completer;

    // Mark route as discovering
    final discRoute = RouteEntry(
      destinationId: destinationId,
      nextHopId: '',
      hopCount: AppConstants.maxHopCount,
      sequenceNumber: 0,
      state: RouteState.discovering,
      lastUpdated: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    _routes[destinationId] = discRoute;

    // Send RREQ broadcast
    await _sendRreq(destinationId);

    // Timeout after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        _pendingDiscoveries.remove(destinationId);
        _routes.remove(destinationId);
        completer.completeError(NoRouteError(destinationId));
        logger.routing('Route discovery timeout for $destinationId', level: LogLevel.warning);
      }
    });

    return completer.future;
  }

  Future<void> _sendRreq(String destinationId) async {
    _rreqSeqNum++;
    final broadcastId = _rreqSeqNum;

    final rreq = AetherPacket(
      version: 1,
      type: PacketType.routeRequest,
      packetId: generateMessageId(),
      originId: localNodeId,
      destinationId: destinationId,
      previousHopId: localNodeId,
      ttl: AppConstants.defaultTtl,
      hopCount: 0,
      sequenceNumber: broadcastId,
      timestamp: nowMs(),
      routingMeta: {
        'bcast_id': broadcastId,
        'src_seq':  _rreqSeqNum,
        'dst_seq':  0,
      },
    );

    // Remember this RREQ to avoid processing our own
    final rreqKey = '$localNodeId:$broadcastId';
    _seenRreqs[rreqKey] = DateTime.now();

    logger.routing('RREQ sent: src=$localNodeId dst=$destinationId bcastId=$broadcastId');
    await _broadcast?.call(rreq);
  }

  // ---------------------------------------------------------------------------
  // Incoming Packet Processing
  // ---------------------------------------------------------------------------

  /// Processes an incoming packet from [fromPeerId].
  /// Returns true if the packet was handled (and should not be forwarded again by caller).
  Future<bool> processPacket(AetherPacket packet, String fromPeerId) async {
    switch (packet.type) {
      case PacketType.routeRequest:
        await _handleRreq(packet, fromPeerId);
        return true;
      case PacketType.routeReply:
        await _handleRrep(packet, fromPeerId);
        return true;
      case PacketType.routeError:
        await _handleRerr(packet, fromPeerId);
        return true;
      default:
        return false;
    }
  }

  Future<void> _handleRreq(AetherPacket rreq, String fromPeerId) async {
    final rm = rreq.routingMeta;
    final broadcastId = (rm?['bcast_id'] as num?)?.toInt() ?? 0;
    final rreqKey = '${rreq.originId}:$broadcastId';

    // Duplicate check
    if (_seenRreqs.containsKey(rreqKey)) {
      logger.routing('RREQ duplicate dropped: $rreqKey');
      return;
    }
    _seenRreqs[rreqKey] = DateTime.now();
    _cleanSeenRreqs();

    logger.routing('RREQ received: src=${rreq.originId} dst=${rreq.destinationId} '
        'hops=${rreq.hopCount} ttl=${rreq.ttl}');

    // Install/refresh reverse route to RREQ source via fromPeerId
    await _installReverseRoute(rreq.originId, fromPeerId, rreq.hopCount,
        (rm?['src_seq'] as num?)?.toInt() ?? 0);

    if (rreq.destinationId == localNodeId) {
      // We ARE the destination — send RREP back
      logger.routing('RREQ destination reached (we are $localNodeId) — sending RREP');
      await _sendRrep(rreq, fromPeerId);
      return;
    }

    // Check if we have a fresh route to the destination
    final existingRoute = getRoute(rreq.destinationId);
    if (existingRoute != null) {
      final dstSeq = (rm?['dst_seq'] as num?)?.toInt() ?? 0;
      if (existingRoute.sequenceNumber >= dstSeq) {
        logger.routing('RREQ — we have route to ${rreq.destinationId}, sending RREP');
        await _sendRrepFromIntermediate(rreq, existingRoute, fromPeerId);
        return;
      }
    }

    // Drop if TTL exhausted
    if (rreq.ttl <= 1) {
      logger.routing('RREQ TTL exhausted, dropping');
      return;
    }

    // Rebroadcast RREQ with decremented TTL and incremented hopCount
    final forwarded = rreq.relay(
      newPreviousHopId: localNodeId,
      newTtl: rreq.ttl - 1,
      newHopCount: rreq.hopCount + 1,
    );
    logger.routing('RREQ forwarded: dst=${rreq.destinationId} newHops=${forwarded.hopCount}');
    await _broadcast?.call(forwarded, excludePeer: fromPeerId);
  }

  Future<void> _handleRrep(AetherPacket rrep, String fromPeerId) async {
    logger.routing('RREP received: src=${rrep.originId} dst=${rrep.destinationId} hops=${rrep.hopCount}');

    // Install route to RREP origin (the destination we were looking for)
    await _installRoute(RouteEntry(
      destinationId: rrep.originId,
      nextHopId: fromPeerId,
      hopCount: rrep.hopCount,
      sequenceNumber: rrep.sequenceNumber,
      state: RouteState.active,
      lastUpdated: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: AppConstants.routeExpirySeconds)),
    ));

    if (rrep.destinationId == localNodeId) {
      // We are the original RREQ source — route discovery complete!
      final route = getRoute(rrep.originId);
      if (route != null) {
        final completer = _pendingDiscoveries.remove(rrep.originId);
        completer?.complete(route);
        logger.routing('Route discovery complete: ${rrep.originId} via $fromPeerId (${rrep.hopCount} hops)');
      }
      return;
    }

    // Forward RREP toward original RREQ source
    final route = getRoute(rrep.destinationId);
    if (route != null) {
      final forwarded = rrep.relay(
        newPreviousHopId: localNodeId,
        newTtl: rrep.ttl - 1,
        newHopCount: rrep.hopCount + 1,
      );
      await _sendTo?.call(route.nextHopId, forwarded);
      logger.routing('RREP forwarded to ${route.nextHopId}');
    } else {
      logger.routing('RREP: no route to forward to ${rrep.destinationId}', level: LogLevel.warning);
    }
  }

  Future<void> _handleRerr(AetherPacket rerr, String fromPeerId) async {
    final destId = rerr.routingMeta?['broken_dest'] as String? ?? rerr.originId;
    logger.routing('RERR received: broken route to $destId', level: LogLevel.warning);
    await invalidateRoute(destId);
  }

  // ---------------------------------------------------------------------------
  // RREP Generation
  // ---------------------------------------------------------------------------

  Future<void> _sendRrep(AetherPacket rreq, String towardSrc) async {
    final rrep = AetherPacket(
      version: 1,
      type: PacketType.routeReply,
      packetId: generateMessageId(),
      originId: localNodeId,       // RREP origin = the destination node
      destinationId: rreq.originId, // RREP destination = the RREQ source
      previousHopId: localNodeId,
      ttl: AppConstants.defaultTtl,
      hopCount: 0,
      sequenceNumber: _rreqSeqNum,
      timestamp: nowMs(),
    );
    await _sendTo?.call(towardSrc, rrep);
    logger.routing('RREP sent: src=$localNodeId dst=${rreq.originId} via $towardSrc');
  }

  Future<void> _sendRrepFromIntermediate(
      AetherPacket rreq, RouteEntry route, String towardSrc) async {
    final rrep = AetherPacket(
      version: 1,
      type: PacketType.routeReply,
      packetId: generateMessageId(),
      originId: rreq.destinationId,
      destinationId: rreq.originId,
      previousHopId: localNodeId,
      ttl: AppConstants.defaultTtl,
      hopCount: route.hopCount,
      sequenceNumber: route.sequenceNumber,
      timestamp: nowMs(),
    );
    await _sendTo?.call(towardSrc, rrep);
  }

  Future<void> _sendRouteError(String brokenDest, List<String> precursors) async {
    final rerr = AetherPacket(
      version: 1,
      type: PacketType.routeError,
      packetId: generateMessageId(),
      originId: localNodeId,
      destinationId: '*',
      previousHopId: localNodeId,
      ttl: 1,
      hopCount: 0,
      sequenceNumber: 0,
      timestamp: nowMs(),
      routingMeta: {'broken_dest': brokenDest},
    );
    for (final precursor in precursors) {
      await _sendTo?.call(precursor, rerr);
    }
  }

  // ---------------------------------------------------------------------------
  // Route Table Helpers
  // ---------------------------------------------------------------------------

  Future<void> _installRoute(RouteEntry route) async {
    final existing = _routes[route.destinationId];
    // Only update if new route is fresher or has fewer hops
    if (existing != null && existing.isUsable) {
      if (existing.sequenceNumber > route.sequenceNumber) return;
      if (existing.sequenceNumber == route.sequenceNumber &&
          existing.hopCount <= route.hopCount) {
        return;
      }
    }
    await _upsertRoute(route);
    logger.routing('Route installed: ${route.destinationId} via ${route.nextHopId} (${route.hopCount} hops)');
  }

  Future<void> _installReverseRoute(
      String sourceId, String fromPeerId, int hopCount, int seqNum) async {
    final route = RouteEntry(
      destinationId: sourceId,
      nextHopId: fromPeerId,
      hopCount: hopCount + 1,
      sequenceNumber: seqNum,
      state: RouteState.active,
      lastUpdated: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: AppConstants.routeExpirySeconds)),
    );
    await _installRoute(route);
  }

  Future<void> _upsertRoute(RouteEntry route) async {
    _routes[route.destinationId] = route;
    await _routingDao.upsertRoute(route);
  }

  /// Loads routes from SQLite on startup.
  Future<void> loadRoutesFromDatabase() async {
    final routes = await _routingDao.getAllRoutes();
    for (final route in routes) {
      if (route.isUsable) {
        _routes[route.destinationId] = route;
      }
    }
    logger.routing('Loaded ${_routes.length} routes from database');
  }

  /// Removes stale RREQ cache entries to prevent unbounded memory growth.
  void _cleanSeenRreqs() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _seenRreqs.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  /// Periodic route maintenance — removes expired routes.
  Future<void> performMaintenance() async {
    _routes.removeWhere((_, route) => route.isExpired);
    await _routingDao.deleteExpired();
    _cleanSeenRreqs();
  }
}
