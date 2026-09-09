// AetherLink message entities.

import 'package:equatable/equatable.dart';

/// Message delivery status — tracks end-to-end delivery state.
enum MessageStatus {
  /// Being encrypted and handed to the BLE layer.
  sending,

  /// Delivered to the first hop (or direct peer).
  sent,

  /// Being relayed through intermediate nodes.
  relayed,

  /// Destination confirmed receipt via ACK.
  delivered,

  /// Max retries exceeded or route permanently failed.
  failed,

  /// Awaiting route or peer reconnection (store-and-forward queue).
  pending,
}

extension MessageStatusExtension on MessageStatus {
  String get label {
    switch (this) {
      case MessageStatus.sending:   return 'Sending...';
      case MessageStatus.sent:      return 'Sent';
      case MessageStatus.relayed:   return 'Relayed';
      case MessageStatus.delivered: return 'Delivered';
      case MessageStatus.failed:    return 'Failed';
      case MessageStatus.pending:   return 'Pending';
    }
  }
}

/// Message type — determines UI rendering and routing behaviour.
enum MessageType {
  text,
  broadcast,
  sos,
  system,
}

/// A complete AetherLink message (sent or received).
class AetherMessage extends Equatable {
  /// Unique message ID (UUIDv4).
  final String messageId;

  /// Conversation this message belongs to (peerId of the other party).
  final String conversationId;

  /// Node ID of the sender.
  final String senderId;

  /// Node ID of the intended recipient.
  final String receiverId;

  /// Plaintext content — only populated after successful decryption.
  /// Null for messages we cannot decrypt (relay nodes).
  final String? plaintext;

  /// Encrypted payload (ciphertext, Base64) stored in DB.
  /// Never logged as plaintext.
  final String encryptedPayload;

  /// When the message was created (at origin).
  final DateTime timestamp;

  /// Current delivery status.
  final MessageStatus status;

  /// Number of hops this message traversed.
  final int hopCount;

  /// Message type (text, broadcast, SOS, etc.).
  final MessageType messageType;

  /// Number of delivery retry attempts made.
  final int retryCount;

  /// Whether this message was sent by the local node.
  final bool isOutgoing;

  /// Optional route description (e.g., "via AETH-A1B2").
  final String? routeDescription;

  const AetherMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.encryptedPayload,
    required this.timestamp,
    required this.status,
    required this.messageType,
    required this.isOutgoing,
    this.plaintext,
    this.hopCount = 0,
    this.retryCount = 0,
    this.routeDescription,
  });

  AetherMessage copyWith({
    String? plaintext,
    MessageStatus? status,
    int? hopCount,
    int? retryCount,
    String? routeDescription,
    String? encryptedPayload,
  }) {
    return AetherMessage(
      messageId: messageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      timestamp: timestamp,
      status: status ?? this.status,
      messageType: messageType,
      isOutgoing: isOutgoing,
      plaintext: plaintext ?? this.plaintext,
      hopCount: hopCount ?? this.hopCount,
      retryCount: retryCount ?? this.retryCount,
      routeDescription: routeDescription ?? this.routeDescription,
    );
  }

  @override
  List<Object?> get props => [messageId, conversationId, senderId, receiverId,
      timestamp, status, messageType, isOutgoing, hopCount, retryCount];
}

/// Represents an SOS or broadcast message received from the network.
class NetworkAlert extends Equatable {
  final String messageId;
  final String originId;
  final String originName;
  final MessageType alertType; // sos or broadcast
  final String content;
  final DateTime timestamp;
  final int hopCount;
  final int ttl;
  final bool isDuplicate;

  const NetworkAlert({
    required this.messageId,
    required this.originId,
    required this.originName,
    required this.alertType,
    required this.content,
    required this.timestamp,
    required this.hopCount,
    required this.ttl,
    this.isDuplicate = false,
  });

  bool get isSos => alertType == MessageType.sos;

  @override
  List<Object?> get props => [messageId, originId, alertType, timestamp];
}

/// A conversation between the local node and a peer.
class Conversation extends Equatable {
  final String conversationId; // == peerId
  final String peerId;
  final String peerName;
  final String? lastMessageText;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final MessageStatus? lastMessageStatus;

  const Conversation({
    required this.conversationId,
    required this.peerId,
    required this.peerName,
    this.lastMessageText,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.lastMessageStatus,
  });

  Conversation copyWith({
    String? conversationId,
    String? peerId,
    String? peerName,
    String? lastMessageText,
    DateTime? lastMessageTime,
    int? unreadCount,
    MessageStatus? lastMessageStatus,
  }) => Conversation(
    conversationId: conversationId ?? this.conversationId,
    peerId: peerId ?? this.peerId,
    peerName: peerName ?? this.peerName,
    lastMessageText: lastMessageText ?? this.lastMessageText,
    lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    unreadCount: unreadCount ?? this.unreadCount,
    lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
  );

  @override
  List<Object?> get props => [conversationId, peerId];
}
