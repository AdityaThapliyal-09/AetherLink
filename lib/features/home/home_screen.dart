// AetherLink Home Screen — Network dashboard and peer discovery.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/peer_node.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import 'aether_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherTheme.bg,
      body: SafeArea(
        child: Consumer<AetherProvider>(
          builder: (ctx, provider, _) {
            if (!provider.initialized) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AetherTheme.teal, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Initializing AetherLink...',
                        style: TextStyle(color: AetherTheme.textSecondary)),
                  ],
                ),
              );
            }
            return _HomeContent(provider: provider);
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final AetherProvider provider;
  const _HomeContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final peers = provider.activePeers;
    final identity = provider.identity;
    final state = provider.networkState;
    final routes = provider.getRoutingTable();

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: _Header(
            identity: identity,
            state: state,
            peerCount: peers.length,
          ),
        ),

        // Network Summary
        SliverToBoxAdapter(
          child: _NetworkSummary(provider: provider),
        ),

        // Permission/BT error banners
        if (state.index <= 1)
          SliverToBoxAdapter(child: _PermissionBanner(provider: provider, state: state)),

        // Nearby Peers header
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Nearby Peers',
            trailing: Text('${peers.length} found',
                style: const TextStyle(color: AetherTheme.tealDim, fontSize: 13)),
          ),
        ),

        // Peer list or empty state
        if (peers.isEmpty)
          SliverToBoxAdapter(
            child: _ScanningEmptyState(state: state),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final peer = peers[i];
                return PeerCard(
                  peer: peer,
                  onTap: () => ctx.pushNamed('peerDetail',
                      pathParameters: {'peerId': peer.nodeId}),
                  onChat: peer.connectionState == PeerConnectionState.ready
                      ? () => ctx.pushNamed('chat',
                          pathParameters: {'peerId': peer.nodeId},
                          queryParameters: {'name': peer.displayName})
                      : null,
                );
              },
              childCount: peers.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final dynamic identity;
  final dynamic state;
  final int peerCount;
  const _Header({required this.identity, required this.state, required this.peerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AetherTheme.tealFaint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AetherTheme.borderTeal, width: 1),
                ),
                child: const Icon(Icons.hub, color: AetherTheme.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AetherLink',
                        style: TextStyle(
                            color: AetherTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                    if (identity != null)
                      Text(identity.nodeId,
                          style: const TextStyle(
                              color: AetherTheme.textTertiary,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                  ],
                ),
              ),
              NetworkStatusBadge(state: state, peerCount: peerCount),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AetherTheme.border),
        ],
      ),
    );
  }
}

class _NetworkSummary extends StatelessWidget {
  final AetherProvider provider;
  const _NetworkSummary({required this.provider});

  @override
  Widget build(BuildContext context) {
    final peers = provider.activePeers;
    final ready = provider.readyPeers.length;
    final routes = provider.getRoutingTable();
    final pending = provider.pendingMessages;
    final alerts = provider.alerts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Network Summary'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: [
              StatCard(label: 'Nearby', value: '${peers.length}',
                  icon: Icons.sensors, color: AetherTheme.teal),
              StatCard(label: 'Ready', value: '$ready',
                  icon: Icons.link, color: AetherTheme.statusGreen),
              StatCard(label: 'Routes', value: '${routes.length}',
                  icon: Icons.route, color: AetherTheme.tealDim),
              StatCard(label: 'Pending', value: '$pending',
                  icon: Icons.hourglass_empty,
                  color: pending > 0 ? AetherTheme.statusYellow : AetherTheme.statusGray),
              StatCard(label: 'Alerts', value: '$alerts',
                  icon: Icons.campaign, color: AetherTheme.statusYellow),
              StatCard(label: 'Net Health',
                  value: ready > 0 ? 'Good' : peers.isNotEmpty ? 'Fair' : 'None',
                  icon: Icons.favorite_border,
                  color: ready > 0 ? AetherTheme.statusGreen : AetherTheme.statusYellow),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanningEmptyState extends StatelessWidget {
  final dynamic state;
  const _ScanningEmptyState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: EmptyState(
        icon: Icons.radar,
        title: 'Scanning for AetherLink nodes',
        subtitle: 'Make sure other devices have AetherLink open with Bluetooth enabled. '
            'Discovery may take 30–60 seconds.',
        action: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AetherTheme.tealFaint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AetherTheme.borderTeal, width: 1),
          ),
          child: const Text('Keep Bluetooth enabled and stay nearby',
              style: TextStyle(color: AetherTheme.teal, fontSize: 13)),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final AetherProvider provider;
  final dynamic state;
  const _PermissionBanner({required this.provider, required this.state});

  @override
  Widget build(BuildContext context) {
    final isBluetooth = state.toString().contains('bluetoothOff');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AetherTheme.sosSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AetherTheme.sosRedDim, width: 1),
      ),
      child: Row(
        children: [
          Icon(isBluetooth ? Icons.bluetooth_disabled : Icons.lock_outline,
              color: AetherTheme.sosRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isBluetooth
                  ? 'Bluetooth is disabled. Enable Bluetooth to discover nearby AetherLink nodes.'
                  : 'Nearby-device permission is required for AetherLink networking.',
              style: const TextStyle(color: AetherTheme.textSecondary, fontSize: 13),
            ),
          ),
          if (!isBluetooth)
            TextButton(
              onPressed: () => provider.requestPermissions(),
              child: const Text('Grant', style: TextStyle(color: AetherTheme.teal)),
            ),
        ],
      ),
    );
  }
}
