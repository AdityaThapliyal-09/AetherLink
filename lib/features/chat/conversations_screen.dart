// Conversations list screen

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../presentation/theme/aether_theme.dart';
import '../../presentation/widgets/widgets.dart';
import '../home/aether_provider.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherTheme.bg,
      appBar: AetherAppBar(
        title: 'Secure Chats',
        trailing: const Icon(Icons.lock_outline, color: AetherTheme.teal, size: 18),
      ),
      body: Consumer<AetherProvider>(
        builder: (ctx, provider, _) {
          final convs = provider.conversations;
          if (convs.isEmpty) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No secure conversations yet',
              subtitle: 'Discover a nearby AetherLink node and start a secure encrypted chat.',
              action: ElevatedButton.icon(
                onPressed: () => ctx.goNamed('home'),
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('Find Peers'),
              ),
            );
          }
          return ListView.builder(
            itemCount: convs.length,
            itemBuilder: (ctx, i) {
              final conv = convs[i];
              return _ConversationTile(
                conv: conv,
                onTap: () => ctx.pushNamed('chat',
                    pathParameters: {'peerId': conv.peerId},
                    queryParameters: {'name': conv.peerName}),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final dynamic conv;
  final VoidCallback onTap;
  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = conv.peerName as String;
    final lastMsg = conv.lastMessageText as String?;
    final lastTime = conv.lastMessageTime as DateTime?;
    final unread = conv.unreadCount as int;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AetherTheme.border, width: 1)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AetherTheme.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AetherTheme.borderTeal, width: 1),
              ),
              child: Center(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AetherTheme.teal,
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                color: AetherTheme.textPrimary,
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      if (lastTime != null)
                        Text(_formatTime(lastTime),
                            style: const TextStyle(
                                color: AetherTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg ?? 'Start a secure conversation',
                          style: TextStyle(
                            color: unread > 0
                                ? AetherTheme.textPrimary
                                : AetherTheme.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AetherTheme.teal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: AetherTheme.bg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
