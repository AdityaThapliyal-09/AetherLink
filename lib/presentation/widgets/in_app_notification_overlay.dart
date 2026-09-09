import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/message.dart';
import '../../features/home/aether_provider.dart';
import '../theme/aether_theme.dart';

/// Wraps the root navigation scaffold to display real-time dropdown
/// heads-up banners when messages arrive while outside that specific chat.
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AetherMessage>? _sub;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  AetherMessage? _currentMessage;
  String _currentSenderName = '';
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AetherProvider>();
      _sub = provider.inAppNotifications.listen(_onMessageReceived);
    });
  }

  void _onMessageReceived(AetherMessage msg) {
    if (!mounted) return;

    final provider = context.read<AetherProvider>();
    String senderName = msg.senderId;
    for (final p in provider.peers) {
      if (p.nodeId == msg.senderId) {
        senderName = p.displayName;
        break;
      }
    }
    for (final c in provider.conversations) {
      if (c.peerId == msg.senderId && c.peerName.isNotEmpty) {
        senderName = c.peerName;
        break;
      }
    }

    _dismissTimer?.cancel();
    setState(() {
      _currentMessage = msg;
      _currentSenderName = senderName;
    });

    _animController.forward(from: 0.0);

    _dismissTimer = Timer(const Duration(milliseconds: 3800), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentMessage = null;
        });
      }
    });
  }

  void _onTapBanner() {
    final msg = _currentMessage;
    if (msg == null) return;
    _dismiss();
    context.pushNamed(
      'chat',
      pathParameters: {'peerId': msg.conversationId},
      queryParameters: {'name': _currentSenderName},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: _onTapBanner,
                        onVerticalDragUpdate: (details) {
                          if (details.primaryDelta != null && details.primaryDelta! < -4) {
                            _dismiss();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AetherTheme.bgElevated, // #1F1F1F
                            borderRadius: BorderRadius.circular(8), // Spotify 8px
                            border: Border.all(
                              color: AetherTheme.borderLight,
                              width: 0.8,
                            ),
                            boxShadow: AetherTheme.shadowHeavy,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: AetherTheme.teal, // Spotify Green
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.chat_bubble_rounded,
                                    color: Color(0xFF000000),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _currentSenderName,
                                            style: const TextStyle(
                                              color: AetherTheme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Text(
                                          'now',
                                          style: TextStyle(
                                            color: AetherTheme.tealDim,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _currentMessage?.plaintext ?? '[Encrypted message]',
                                      style: const TextStyle(
                                        color: AetherTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _dismiss,
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.close,
                                    color: AetherTheme.textTertiary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
