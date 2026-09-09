import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink/domain/entities/message.dart';

void main() {
  group('Unread Calculation and Conversation Entity Tests', () {
    test('Unread count calculation sums across conversations correctly', () {
      final now = DateTime.now();
      final convs = [
        Conversation(
          conversationId: 'AETH-1',
          peerId: 'AETH-1',
          peerName: 'Alice',
          lastMessageText: 'Hello',
          lastMessageTime: now,
          unreadCount: 3,
        ),
        Conversation(
          conversationId: 'AETH-2',
          peerId: 'AETH-2',
          peerName: 'Bob',
          lastMessageText: 'SOS received',
          lastMessageTime: now,
          unreadCount: 2,
        ),
        Conversation(
          conversationId: 'AETH-3',
          peerId: 'AETH-3',
          peerName: 'Charlie',
          lastMessageText: 'OK',
          lastMessageTime: now,
          unreadCount: 0,
        ),
      ];

      final totalUnread = convs.fold<int>(0, (int sum, Conversation c) => sum + c.unreadCount);
      expect(totalUnread, equals(5));

      // Mark AETH-1 as read
      final updated = convs.map((c) {
        if (c.peerId == 'AETH-1') {
          return c.copyWith(unreadCount: 0);
        }
        return c;
      }).toList();

      final updatedTotal = updated.fold<int>(0, (int sum, Conversation c) => sum + c.unreadCount);
      expect(updatedTotal, equals(2));
    });
  });
}
