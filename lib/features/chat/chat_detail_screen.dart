// Chat Detail Screen — encrypted conversation view with a specific peer.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/message.dart';
import '../../domain/entities/peer_node.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  const ChatDetailScreen({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<AetherMessage> _messages = [];
  StreamSubscription? _msgSub;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final provider = context.read<AetherProvider>();
    final msgs = await provider.messagesDao.getMessages(widget.peerId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    }

    // Subscribe to new messages
    _msgSub = provider.networkManager.messageUpdates.listen((msg) {
      if (msg.conversationId == widget.peerId && mounted) {
        final idx = _messages.indexWhere((m) => m.messageId == msg.messageId);
        setState(() {
          if (idx >= 0) {
            _messages[idx] = msg; // Update existing (status change)
          } else {
            _messages = [..._messages, msg]; // New message
          }
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await context.read<AetherProvider>().sendMessage(widget.peerId, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'),
              backgroundColor: AetherTheme.sosRedDim),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AetherProvider>();
    final peer = provider.peers.where((p) => p.nodeId == widget.peerId).firstOrNull;
    final localId = provider.identity?.nodeId ?? '';

    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: _ChatAppBar(peer: peer, peerName: widget.peerName),
      body: Column(
        children: [
          // E2E encryption banner
          _EncryptionBanner(peer: peer),

          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: AetherTheme.teal, strokeWidth: 2))
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.lock_outline,
                        title: 'Start a secure conversation',
                        subtitle: 'Messages are end-to-end encrypted. Only you and '
                            'the recipient can read them.',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isOut = msg.senderId == localId;
                          return MessageBubble(
                            message: msg,
                            isOutgoing: isOut,
                          );
                        },
                      ),
          ),

          // Input area
          _MessageInput(
            controller: _controller,
            sending: _sending,
            peerReady: peer?.connectionState == PeerConnectionState.ready,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PeerNode? peer;
  final String peerName;
  const _ChatAppBar({required this.peer, required this.peerName});

  @override
  Widget build(BuildContext context) {
    final state = peer?.connectionState ?? PeerConnectionState.disconnected;
    final stateColor = switch (state) {
      PeerConnectionState.ready         => AetherTheme.statusGreen,
      PeerConnectionState.connected ||
      PeerConnectionState.authenticating => AetherTheme.statusYellow,
      _                                 => AetherTheme.statusGray,
    };

    return AppBar(
      backgroundColor: AetherTheme.bgSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: AetherTheme.textPrimary, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Stack(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AetherTheme.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AetherTheme.border),
              ),
              child: Center(
                child: Text(
                  peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AetherTheme.teal,
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Positioned(
              bottom: 1, right: 1,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: stateColor, shape: BoxShape.circle,
                  border: Border.all(color: AetherTheme.bgSurface, width: 1.5),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(peerName,
                  style: const TextStyle(
                      color: AetherTheme.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text(
                peer != null
                    ? '${state.label}${peer!.hopCount > 0 ? ' · ${peer!.hopCount} hops' : ''}'
                    : 'Offline',
                style: TextStyle(color: stateColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: AetherTheme.textTertiary),
          onPressed: () {
            if (peer != null) {
              // Navigate to peer detail
            }
          },
        ),
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

class _EncryptionBanner extends StatelessWidget {
  final PeerNode? peer;
  const _EncryptionBanner({required this.peer});

  @override
  Widget build(BuildContext context) {
    if (peer == null) return const SizedBox.shrink();
    final hasKey = peer!.hasPublicKey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: hasKey ? AetherTheme.tealFaint : AetherTheme.sosSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasKey ? Icons.lock : Icons.lock_open,
            size: 12,
            color: hasKey ? AetherTheme.teal : AetherTheme.statusYellow,
          ),
          const SizedBox(width: 6),
          Text(
            hasKey
                ? 'End-to-end encrypted · ${peer!.keyFingerprint}'
                : 'Key exchange pending...',
            style: TextStyle(
              color: hasKey ? AetherTheme.tealDim : AetherTheme.statusYellow,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool peerReady;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.sending,
    required this.peerReady,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 10,
      ),
      decoration: const BoxDecoration(
        color: AetherTheme.bgSurface,
        border: Border(top: BorderSide(color: AetherTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: peerReady,
              style: const TextStyle(color: AetherTheme.textPrimary),
              decoration: InputDecoration(
                hintText: peerReady
                    ? 'Send encrypted message...'
                    : 'Peer not ready — waiting for key exchange...',
                hintStyle: const TextStyle(color: AetherTheme.textTertiary),
                filled: true,
                fillColor: AetherTheme.bgElevated,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AetherTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AetherTheme.teal, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: peerReady ? AetherTheme.teal : AetherTheme.bgElevated,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AetherTheme.bg),
                    )
                  : Icon(Icons.send_rounded,
                      color: peerReady ? AetherTheme.bg : AetherTheme.textTertiary,
                      size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
