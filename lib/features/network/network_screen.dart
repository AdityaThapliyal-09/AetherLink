// Network Topology Screen — visual mesh network graph.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/peer_node.dart';
import '../../domain/entities/route_entry.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: AetherAppBar(
        title: 'Network Topology',
        trailing: const Icon(Icons.device_hub, color: AetherTheme.teal, size: 20),
      ),
      body: Consumer<AetherProvider>(
        builder: (ctx, provider, _) {
          final peers = provider.activePeers;
          final routes = provider.getRoutingTable();
          final identity = provider.identity;

          return Column(
            children: [
              // Topology canvas
              SizedBox(
                height: 280,
                child: peers.isEmpty
                    ? const EmptyState(
                        icon: Icons.device_hub_outlined,
                        title: 'No topology data',
                        subtitle: 'Connect to peers to visualize the mesh network.',
                      )
                    : _TopologyCanvas(
                        peers: peers,
                        routes: routes,
                        localNodeId: identity?.nodeId ?? '',
                        localName: identity?.displayName ?? 'You',
                      ),
              ),

              Container(height: 1, color: AetherTheme.border),

              // Route table
              Expanded(
                child: _RouteTable(routes: routes),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopologyCanvas extends StatelessWidget {
  final List<PeerNode> peers;
  final List<RouteEntry> routes;
  final String localNodeId;
  final String localName;

  const _TopologyCanvas({
    required this.peers,
    required this.routes,
    required this.localNodeId,
    required this.localName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _TopologyPainter(
          peers: peers,
          routes: routes,
          localNodeId: localNodeId,
          localName: localName,
          canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
        ),
      );
    });
  }
}

class _TopologyPainter extends CustomPainter {
  final List<PeerNode> peers;
  final List<RouteEntry> routes;
  final String localNodeId;
  final String localName;
  final Size canvasSize;

  _TopologyPainter({
    required this.peers,
    required this.routes,
    required this.localNodeId,
    required this.localName,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(size.width, size.height) * 0.32;

    // Compute node positions in a circle
    final positions = <String, Offset>{};
    positions[localNodeId] = Offset(centerX, centerY);

    final direct = peers.where((p) => p.isDirect).toList();
    final relay  = peers.where((p) => !p.isDirect).toList();

    for (var i = 0; i < direct.length; i++) {
      final angle = (2 * pi * i / max(direct.length, 1)) - pi / 2;
      positions[direct[i].nodeId] = Offset(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
      );
    }

    for (var i = 0; i < relay.length; i++) {
      final angle = (2 * pi * i / max(relay.length, 1)) + pi / 4;
      positions[relay[i].nodeId] = Offset(
        centerX + radius * 1.5 * cos(angle),
        centerY + radius * 1.5 * sin(angle),
      );
    }

    // Draw edges (connections)
    final edgePaint = Paint()
      ..color = AetherTheme.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = AetherTheme.teal.withAlpha(120)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Direct connections
    for (final peer in direct) {
      final from = positions[localNodeId]!;
      final to = positions[peer.nodeId];
      if (to == null) continue;
      final isReady = peer.connectionState == PeerConnectionState.ready;
      canvas.drawLine(from, to, isReady ? activePaint : edgePaint);
    }

    // Relay routes
    for (final route in routes) {
      final from = positions[route.nextHopId];
      final to = positions[route.destinationId];
      if (from == null || to == null) continue;
      if (route.state == RouteState.active) {
        canvas.drawLine(from, to, activePaint);
      }
    }

    // Draw nodes
    _drawNode(canvas, positions[localNodeId]!, localName, isLocal: true);
    for (final peer in peers) {
      final pos = positions[peer.nodeId];
      if (pos == null) continue;
      _drawNode(canvas, pos, peer.displayName,
          isReady: peer.connectionState == PeerConnectionState.ready,
          isDirect: peer.isDirect);
    }
  }

  void _drawNode(Canvas canvas, Offset center, String name,
      {bool isLocal = false, bool isReady = false, bool isDirect = true}) {
    final r = isLocal ? 22.0 : 18.0;

    // Node circle
    final bgPaint = Paint()
      ..color = isLocal ? AetherTheme.tealFaint : AetherTheme.bgCard
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isLocal
          ? AetherTheme.teal
          : isReady
              ? AetherTheme.statusGreen
              : AetherTheme.border
      ..strokeWidth = isLocal ? 2 : 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, r, bgPaint);
    canvas.drawCircle(center, r, borderPaint);

    // Node label
    final textPainter = TextPainter(
      text: TextSpan(
        text: name.length > 6 ? name.substring(0, 6) : name,
        style: TextStyle(
          color: isLocal ? AetherTheme.teal : AetherTheme.textPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: r * 2);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_TopologyPainter old) =>
      old.peers != peers || old.routes != routes;
}

class _RouteTable extends StatelessWidget {
  final List<RouteEntry> routes;
  const _RouteTable({required this.routes});

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const Center(
        child: Text('No routing table entries',
            style: TextStyle(color: AetherTheme.textTertiary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Routing Table'),
        Expanded(
          child: ListView.builder(
            itemCount: routes.length,
            padding: EdgeInsets.zero,
            itemBuilder: (ctx, i) {
              final r = routes[i];
              final isActive = r.state == RouteState.active;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(
                      color: AetherTheme.border, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.destinationId,
                              style: const TextStyle(
                                  color: AetherTheme.textPrimary,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('via ${r.nextHopId}',
                              style: const TextStyle(
                                  color: AetherTheme.textTertiary,
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AetherTheme.statusGreen.withAlpha(25)
                                : AetherTheme.bgElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(r.state.label,
                              style: TextStyle(
                                  color: isActive
                                      ? AetherTheme.statusGreen
                                      : AetherTheme.textTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 2),
                        Text('${r.hopCount} hops · seq ${r.sequenceNumber}',
                            style: const TextStyle(
                                color: AetherTheme.textTertiary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
