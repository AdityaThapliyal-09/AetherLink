// SOS Screen — Emergency alert system with press-and-hold activation.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/message.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  bool _sosActive = false;
  bool _holding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  Timer? _progressTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final _broadcastController = TextEditingController();

  static const _holdMs = AppConstants.sosHoldDurationMs;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progressTimer?.cancel();
    _pulseCtrl.dispose();
    _broadcastController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    if (_sosActive) return;
    setState(() { _holding = true; _holdProgress = 0.0; });
    HapticFeedback.mediumImpact();

    const interval = Duration(milliseconds: 50);
    const total = _holdMs;
    int elapsed = 0;

    _progressTimer = Timer.periodic(interval, (t) {
      elapsed += 50;
      setState(() { _holdProgress = (elapsed / total).clamp(0.0, 1.0); });
    });

    _holdTimer = Timer(const Duration(milliseconds: _holdMs), () {
      _activateSos();
    });
  }

  void _onHoldEnd() {
    if (_sosActive) return;
    _holdTimer?.cancel();
    _progressTimer?.cancel();
    setState(() { _holding = false; _holdProgress = 0.0; });
  }

  Future<void> _activateSos() async {
    _progressTimer?.cancel();
    _holdTimer?.cancel();
    HapticFeedback.heavyImpact();

    setState(() {
      _sosActive = true;
      _holding = false;
      _holdProgress = 1.0;
    });

    try {
      await context.read<AetherProvider>().sendSos(
          'SOS — I NEED HELP. This is an emergency alert from AetherLink.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SOS send failed: $e'),
              backgroundColor: AetherTheme.sosRedDim),
        );
      }
    }
  }

  void _cancelSos() {
    HapticFeedback.mediumImpact();
    setState(() { _sosActive = false; _holdProgress = 0.0; });
  }

  Future<void> _sendBroadcast() async {
    final text = _broadcastController.text.trim();
    if (text.isEmpty) return;
    try {
      await context.read<AetherProvider>().sendBroadcast(text);
      _broadcastController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast sent to network')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast failed: $e'),
              backgroundColor: AetherTheme.sosRedDim),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AetherProvider>();
    final peerCount = provider.activePeers.length;

    return Scaffold(
      backgroundColor: _sosActive ? AetherTheme.sosSurface : AetherTheme.bg,
      appBar: AetherAppBar(
        title: _sosActive ? 'SOS ACTIVE' : 'Emergency / Broadcast',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SOS Button
              _SosButton(
                active: _sosActive,
                holding: _holding,
                progress: _holdProgress,
                pulseAnim: _pulseAnim,
                onHoldStart: _onHoldStart,
                onHoldEnd: _onHoldEnd,
                onCancel: _cancelSos,
              ),
              const SizedBox(height: 16),

              // Network reach info
              _NetworkReachCard(peerCount: peerCount),
              const SizedBox(height: 24),

              // Received alerts
              _AlertsSection(alerts: provider.alerts),

              const SizedBox(height: 24),

              // Broadcast panel
              _BroadcastPanel(
                controller: _broadcastController,
                onSend: _sendBroadcast,
                enabled: peerCount > 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  final bool active;
  final bool holding;
  final double progress;
  final Animation<double> pulseAnim;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onCancel;

  const _SosButton({
    required this.active,
    required this.holding,
    required this.progress,
    required this.pulseAnim,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The button
        ScaleTransition(
          scale: active ? pulseAnim : const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onTapDown: (_) => onHoldStart(),
            onTapUp: (_) => onHoldEnd(),
            onTapCancel: onHoldEnd,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AetherTheme.sosRed
                    : holding
                        ? AetherTheme.sosRedDim
                        : AetherTheme.sosSurface,
                border: Border.all(
                  color: active ? AetherTheme.sosRed : AetherTheme.sosRedDim,
                  width: 3,
                ),
                boxShadow: active
                    ? [BoxShadow(
                        color: AetherTheme.sosRed.withAlpha(100),
                        blurRadius: 40, spreadRadius: 10)]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring
                  if (holding || (active && progress > 0))
                    SizedBox(
                      width: 190, height: 190,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        color: Colors.white,
                        backgroundColor: Colors.white.withAlpha(30),
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency,
                          color: Colors.white,
                          size: active ? 56 : 48),
                      const SizedBox(height: 8),
                      Text(
                        active ? 'SOS ACTIVE' : holding ? 'HOLD...' : 'SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      if (!active && !holding)
                        const Text(
                          'Press & Hold',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (active)
          Column(
            children: [
              const Text('SOS ALERT PROPAGATING THROUGH NETWORK',
                  style: TextStyle(
                      color: AetherTheme.sosRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AetherTheme.textSecondary,
                  side: const BorderSide(color: AetherTheme.textTertiary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                ),
                child: const Text('Cancel SOS'),
              ),
            ],
          )
        else
          const Text(
            'Press and hold for 2 seconds to activate emergency SOS.\nThis will alert all reachable nodes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AetherTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
      ],
    );
  }
}

class _NetworkReachCard extends StatelessWidget {
  final int peerCount;
  const _NetworkReachCard({required this.peerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AetherTheme.bgCard,
        borderRadius: BorderRadius.circular(8), // Spotify 8px
        border: Border.all(color: AetherTheme.border, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering, color: AetherTheme.teal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              peerCount > 0
                  ? 'SOS will reach $peerCount direct peer${peerCount == 1 ? '' : 's'} and propagate through the mesh'
                  : 'No peers reachable — SOS will activate when peers connect',
              style: const TextStyle(color: AetherTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  final List<NetworkAlert> alerts;
  const _AlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Network Alerts'),
        if (alerts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No alerts received',
                  style: TextStyle(color: AetherTheme.textTertiary)),
            ),
          )
        else
          ...alerts.take(10).map((alert) => _AlertTile(alert: alert)),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final NetworkAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isSos = alert.isSos;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSos ? AetherTheme.sosSurface : AetherTheme.bgCard,
        borderRadius: BorderRadius.circular(8), // Spotify 8px
        border: Border.all(
          color: isSos ? AetherTheme.sosRedDim : AetherTheme.border,
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isSos ? Icons.emergency : Icons.campaign,
              color: isSos ? AetherTheme.sosRed : AetherTheme.statusYellow,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(alert.originName,
                          style: TextStyle(
                              color: isSos
                                  ? AetherTheme.sosRed
                                  : AetherTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    Text('${alert.hopCount} hops',
                        style: const TextStyle(
                            color: AetherTheme.textTertiary, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(alert.content,
                    style: const TextStyle(
                        color: AetherTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastPanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const _BroadcastPanel({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Network Broadcast'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AetherTheme.bgCard,
            borderRadius: BorderRadius.circular(8), // Spotify 8px
            border: Border.all(color: AetherTheme.border, width: 0.8),
          ),
          child: Column(
            children: [
              TextField(
                controller: controller,
                enabled: enabled,
                style: const TextStyle(color: AetherTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'e.g. "Water available at Sector 4"'
                      : 'No peers connected',
                  hintStyle: const TextStyle(
                      color: AetherTheme.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AetherTheme.bgElevated,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AetherTheme.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AetherTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AetherTheme.teal, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: enabled ? onSend : null,
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Broadcast to Network'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AetherTheme.teal,
                    foregroundColor: const Color(0xFF000000),
                    disabledBackgroundColor: AetherTheme.bgElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
