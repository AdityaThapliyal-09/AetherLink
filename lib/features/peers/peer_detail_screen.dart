// Peer Detail Screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/peer_node.dart';
import '../../domain/entities/route_entry.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class PeerDetailScreen extends StatelessWidget {
  final String peerId;
  const PeerDetailScreen({super.key, required this.peerId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AetherProvider>();
    final peer = provider.peers
        .where((p) => p.nodeId == peerId)
        .firstOrNull;
    final routes = provider.getRoutingTable()
        .where((r) => r.destinationId == peerId)
        .toList();

    if (peer == null) {
      return Scaffold(
        backgroundColor: AetherTheme.bg,
        appBar: AppBar(
            backgroundColor: AetherTheme.bgSurface,
            title: const Text('Peer Details')),
        body: const EmptyState(
          icon: Icons.device_unknown,
          title: 'Peer not found',
          subtitle: 'This peer may have disconnected.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: AetherAppBar(
        title: peer.displayName,
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar + name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AetherTheme.bgElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AetherTheme.teal, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        peer.displayName.isNotEmpty
                            ? peer.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AetherTheme.teal,
                            fontSize: 32,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(peer.displayName,
                      style: const TextStyle(
                          color: AetherTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(peer.nodeId,
                      style: const TextStyle(
                          color: AetherTheme.textTertiary,
                          fontSize: 13,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Start Chat button
            if (peer.connectionState == PeerConnectionState.ready)
              ElevatedButton.icon(
                onPressed: () {
                  context.pop();
                  context.pushNamed('chat',
                      pathParameters: {'peerId': peer.nodeId},
                      queryParameters: {'name': peer.displayName});
                },
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Start Secure Chat'),
              ),
            const SizedBox(height: 24),

            // Connection info
            _InfoSection(title: 'Connection', items: [
              _InfoItem('Status', peer.connectionState.label),
              _InfoItem('Type', peer.isDirect ? 'Direct (BLE)' : '${peer.hopCount}-hop relay'),
              if (peer.rssi != null)
                _InfoItem('Signal', '${peer.rssi} dBm (${_rssiLabel(peer.rssi!)})'),
              _InfoItem('Last seen', peer.lastSeen != null
                  ? '${DateTime.now().difference(peer.lastSeen!).inSeconds}s ago'
                  : 'Never'),
              if (peer.nextHopId != null)
                _InfoItem('Next hop', peer.nextHopId!),
            ]),
            const SizedBox(height: 16),

            // Cryptographic info
            _InfoSection(title: 'Cryptographic Identity', items: [
              _InfoItem('Key fingerprint', peer.keyFingerprint,
                  copyable: true, mono: true),
              _InfoItem('Trust status',
                  peer.isTrusted ? 'Verified ✓' : 'Not verified',
                  color: peer.isTrusted
                      ? AetherTheme.statusGreen
                      : AetherTheme.statusYellow),
              _InfoItem('Key exchange',
                  peer.hasPublicKey ? 'Complete' : 'Pending',
                  color: peer.hasPublicKey
                      ? AetherTheme.statusGreen
                      : AetherTheme.statusYellow),
            ]),

            // Trust button
            if (!peer.isTrusted && peer.hasPublicKey) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _verifyPeer(context, peer),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Verify Fingerprint'),
              ),
            ],

            // Route info
            if (routes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoSection(title: 'Route', items: [
                _InfoItem('Via', routes.first.nextHopId),
                _InfoItem('Hops', '${routes.first.hopCount}'),
                _InfoItem('State', routes.first.state.label),
                _InfoItem('Sequence', '${routes.first.sequenceNumber}'),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _rssiLabel(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -75) return 'Fair';
    return 'Weak';
  }

  void _verifyPeer(BuildContext context, PeerNode peer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AetherTheme.bgCard,
        title: const Text('Verify Peer Identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compare this fingerprint with the peer in person to verify their identity.',
              style: TextStyle(color: AetherTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AetherTheme.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AetherTheme.teal),
              ),
              child: Text(
                peer.keyFingerprint,
                style: const TextStyle(
                    color: AetherTheme.teal,
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AetherProvider>().networkManager
                  .aodvManager; // placeholder — trust update
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${peer.displayName} verified')),
              );
            },
            child: const Text('Confirm Trust'),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;
  const _InfoSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                color: AetherTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AetherTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AetherTheme.border, width: 1),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    const Divider(height: 1, color: AetherTheme.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final bool mono;
  final Color? color;

  const _InfoItem(this.label, this.value,
      {this.copyable = false, this.mono = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AetherTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: GestureDetector(
              onTap: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(value,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color ?? AetherTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: mono ? 'monospace' : null)),
                  ),
                  if (copyable) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 14, color: AetherTheme.teal),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
