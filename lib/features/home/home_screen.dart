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
                final unread = provider.getUnreadForPeer(peer.nodeId);
                return PeerCard(
                  peer: peer,
                  unreadCount: unread,
                  onTap: () => ctx.pushNamed('peerDetail',
                      pathParameters: {'peerId': peer.nodeId}),
                  onChat: (peer.connectionState == PeerConnectionState.ready ||
                           peer.connectionState == PeerConnectionState.connected ||
                           provider.hasSessionKey(peer.nodeId))
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo (Circular Spotify style)
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AetherTheme.bgSurface,
                  shape: BoxShape.circle,
                  boxShadow: AetherTheme.shadowHeavy,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AetherTheme.bgElevated,
                      child: const Icon(Icons.hub, color: AetherTheme.teal, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AetherLink',
                          style: TextStyle(
                            color: AetherTheme.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AetherTheme.bgElevated,
                            borderRadius: BorderRadius.circular(9999), // Spotify full pill
                            border: Border.all(color: AetherTheme.borderLight, width: 0.8),
                          ),
                          child: const Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: AetherTheme.teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (identity != null)
                      Text(
                        identity.nodeId,
                        style: const TextStyle(
                          color: AetherTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
        subtitle: 'Ensure nearby devices have AetherLink open with Bluetooth and Location (GPS) turned ON in Android Quick Settings.',
        action: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AetherTheme.tealFaint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AetherTheme.borderTeal, width: 1),
          ),
          child: const Text('Turn on Bluetooth & Location (GPS)',
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
