// AetherLink shared widget library.
// Common components used across multiple screens.

import 'package:flutter/material.dart';
import '../../domain/entities/peer_node.dart';
import '../../domain/entities/message.dart';
import '../../services/bluetooth/network_manager.dart';
import '../theme/aether_theme.dart';

// ── Network Status Badge ─────────────────────────────────────────────────────

class NetworkStatusBadge extends StatelessWidget {
  final NetworkState state;
  final int? peerCount;
  const NetworkStatusBadge({super.key, required this.state, this.peerCount});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (state) {
      NetworkState.connected       => (AetherTheme.statusGreen, Icons.wifi_tethering, 'Mesh Active'),
      NetworkState.scanning        => (AetherTheme.statusYellow, Icons.wifi_find, 'Scanning'),
      NetworkState.bluetoothOff    => (AetherTheme.statusRed, Icons.bluetooth_disabled, 'BT Disabled'),
      NetworkState.permissionRequired => (AetherTheme.statusRed, Icons.lock_outline, 'Permission Needed'),
      NetworkState.error           => (AetherTheme.statusRed, Icons.error_outline, 'Error'),
      NetworkState.idle            => (AetherTheme.statusGray, Icons.radio_button_unchecked, 'Idle'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AetherRadius.full),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == NetworkState.scanning)
            _PulsingDot(color: color)
          else
            Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            peerCount != null && state == NetworkState.connected
                ? '$label · $peerCount peer${peerCount == 1 ? '' : 's'}'
                : label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Peer Card ────────────────────────────────────────────────────────────────

class PeerCard extends StatelessWidget {
  final PeerNode peer;
  final VoidCallback? onTap;
  final VoidCallback? onChat;

  const PeerCard({super.key, required this.peer, this.onTap, this.onChat});

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor(peer.connectionState);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AetherTheme.bgCard,
          borderRadius: BorderRadius.circular(AetherRadius.lg),
          border: Border.all(color: AetherTheme.border, width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            _PeerAvatar(peer: peer, stateColor: stateColor),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(peer.displayName,
                            style: const TextStyle(
                                color: AetherTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (peer.rssi != null)
                        _RssiIndicator(rssi: peer.rssi!),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(peer.shortId,
                          style: const TextStyle(
                              color: AetherTheme.textTertiary,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stateColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          peer.isDirect
                              ? peer.connectionState.label
                              : '${peer.connectionState.label} • ${peer.hopCount} hops',
                          style: TextStyle(color: stateColor, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chat button
            if (peer.connectionState == PeerConnectionState.ready && onChat != null)
              GestureDetector(
                onTap: onChat,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AetherTheme.tealFaint,
                    borderRadius: BorderRadius.circular(AetherRadius.md),
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: AetherTheme.teal, size: 20),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: AetherTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Color _stateColor(PeerConnectionState state) {
    return switch (state) {
      PeerConnectionState.ready         => AetherTheme.statusGreen,
      PeerConnectionState.connected ||
      PeerConnectionState.authenticating => AetherTheme.statusYellow,
      PeerConnectionState.discovering ||
      PeerConnectionState.connecting    => AetherTheme.teal,
      PeerConnectionState.retrying      => AetherTheme.statusYellow,
      PeerConnectionState.error         => AetherTheme.statusRed,
      PeerConnectionState.disconnected  => AetherTheme.statusGray,
    };
  }
}

class _PeerAvatar extends StatelessWidget {
  final PeerNode peer;
  final Color stateColor;
  const _PeerAvatar({required this.peer, required this.stateColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: AetherTheme.bgElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AetherTheme.border, width: 1),
          ),
          child: Center(
            child: Text(
              peer.displayName.isNotEmpty
                  ? peer.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AetherTheme.teal,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Positioned(
          bottom: 1, right: 1,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: stateColor,
              shape: BoxShape.circle,
              border: Border.all(color: AetherTheme.bgCard, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _RssiIndicator extends StatelessWidget {
  final int rssi;
  const _RssiIndicator({required this.rssi});

  @override
  Widget build(BuildContext context) {
    final bars = rssi >= -50 ? 4 : rssi >= -65 ? 3 : rssi >= -75 ? 2 : 1;
    return Row(
      children: List.generate(4, (i) => Container(
        width: 3,
        height: 5.0 + (i * 3.0),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: i < bars ? AetherTheme.statusGreen : AetherTheme.textTertiary,
          borderRadius: BorderRadius.circular(1),
        ),
      )),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class MessageBubble extends StatelessWidget {
  final AetherMessage message;
  final bool isOutgoing;

  const MessageBubble({
      super.key, required this.message, required this.isOutgoing});

  @override
  Widget build(BuildContext context) {
    final text = message.plaintext ?? '[Encrypted — key exchange pending]';
    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: EdgeInsets.only(
          left: isOutgoing ? 64 : 16,
          right: isOutgoing ? 16 : 64,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: isOutgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOutgoing ? AetherTheme.bubbleOut : AetherTheme.bubbleIn,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                  bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                ),
                border: Border.all(
                  color: isOutgoing
                      ? AetherTheme.borderTeal
                      : AetherTheme.border,
                  width: 1,
                ),
              ),
              child: Text(text,
                  style: const TextStyle(
                      color: AetherTheme.textPrimary,
                      fontSize: 15,
                      height: 1.4)),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(
                      color: AetherTheme.textTertiary, fontSize: 11),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 6),
                  _StatusIcon(status: message.status),
                  if (message.hopCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '↗ ${message.hopCount} hop${message.hopCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AetherTheme.tealDim, fontSize: 11),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.sending   => const SizedBox(width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AetherTheme.textTertiary)),
      MessageStatus.sent      => const Icon(Icons.check, size: 14, color: AetherTheme.textTertiary),
      MessageStatus.relayed   => const Icon(Icons.call_made, size: 14, color: AetherTheme.tealDim),
      MessageStatus.delivered => const Icon(Icons.done_all, size: 14, color: AetherTheme.teal),
      MessageStatus.failed    => const Icon(Icons.error_outline, size: 14, color: AetherTheme.statusRed),
      MessageStatus.pending   => const Icon(Icons.schedule, size: 14, color: AetherTheme.statusYellow),
    };
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: AetherTheme.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AetherSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AetherTheme.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AetherTheme.border, width: 1),
              ),
              child: Icon(icon, color: AetherTheme.textTertiary, size: 32),
            ),
            const SizedBox(height: AetherSpacing.md),
            Text(title,
                style: const TextStyle(
                    color: AetherTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: AetherTheme.textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AetherSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AetherTheme.teal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AetherTheme.bgCard,
        borderRadius: BorderRadius.circular(AetherRadius.md),
        border: Border.all(color: AetherTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: c, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AetherTheme.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── AetherLink App Bar ────────────────────────────────────────────────────────

class AetherAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final bool showBack;

  const AetherAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AetherTheme.bgSurface,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AetherTheme.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AetherTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        if (trailing != null) trailing!,
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AetherTheme.border, height: 1),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
