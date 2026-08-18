// AetherLink Data Access Objects (DAOs) for all database tables.
// Each DAO provides typed access to one table.

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/local_identity.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/peer_node.dart';
import '../../domain/entities/route_entry.dart';
import '../../core/logging/logger.dart';
import 'aether_database.dart';

// ---------------------------------------------------------------------------
// Identity DAO
// ---------------------------------------------------------------------------

class IdentityDao {
  final AetherDatabase _db;
  IdentityDao(this._db);

  Future<LocalIdentity?> getIdentity() async {
    final db = await _db.db;
    final rows = await db.query('identity', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return LocalIdentity(
      nodeId: r['node_id'] as String,
      displayName: r['display_name'] as String,
      edPublicKey: r['ed_public_key'] as String,
      edPrivateKeyRef: r['ed_private_key_ref'] as String,
      dhPublicKey: r['dh_public_key'] as String,
      dhPrivateKeyRef: r['dh_private_key_ref'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    );
  }

  Future<void> saveIdentity(LocalIdentity identity) async {
    final db = await _db.db;
    await db.insert('identity', {
      'node_id': identity.nodeId,
      'display_name': identity.displayName,
      'ed_public_key': identity.edPublicKey,
      'ed_private_key_ref': identity.edPrivateKeyRef,
      'dh_public_key': identity.dhPublicKey,
      'dh_private_key_ref': identity.dhPrivateKeyRef,
      'created_at': identity.createdAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    logger.database('Identity saved: ${identity.nodeId}');
  }

  Future<void> updateDisplayName(String nodeId, String name) async {
    final db = await _db.db;
    await db.update('identity', {'display_name': name},
        where: 'node_id = ?', whereArgs: [nodeId]);
  }
}

// ---------------------------------------------------------------------------
// Peers DAO
// ---------------------------------------------------------------------------

class PeersDao {
  final AetherDatabase _db;
  PeersDao(this._db);

  Future<List<PeerNode>> getAllPeers() async {
    final db = await _db.db;
    final rows = await db.query('peers', orderBy: 'last_seen DESC');
    return rows.map(_rowToPeer).toList();
  }

  Future<PeerNode?> getPeer(String nodeId) async {
    final db = await _db.db;
    final rows = await db.query('peers', where: 'node_id = ?', whereArgs: [nodeId]);
    if (rows.isEmpty) return null;
    return _rowToPeer(rows.first);
  }

  Future<void> upsertPeer(PeerNode peer) async {
    final db = await _db.db;
    await db.insert('peers', {
      'node_id': peer.nodeId,
      'display_name': peer.displayName,
      'ed_public_key': peer.publicKey,
      'dh_public_key': peer.dhPublicKey,
      'last_seen': peer.lastSeen?.millisecondsSinceEpoch,
      'connection_state': peer.connectionState.name,
      'rssi': peer.rssi,
      'hop_count': peer.hopCount,
      'is_trusted': peer.isTrusted ? 1 : 0,
      'next_hop_id': peer.nextHopId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateConnectionState(String nodeId, PeerConnectionState state) async {
    final db = await _db.db;
    await db.update('peers',
        {'connection_state': state.name, 'last_seen': DateTime.now().millisecondsSinceEpoch},
        where: 'node_id = ?', whereArgs: [nodeId]);
  }

  Future<void> updatePublicKeys(String nodeId, {String? edKey, String? dhKey}) async {
    final db = await _db.db;
    final updates = <String, dynamic>{};
    if (edKey != null) updates['ed_public_key'] = edKey;
    if (dhKey != null) updates['dh_public_key'] = dhKey;
    if (updates.isNotEmpty) {
      await db.update('peers', updates, where: 'node_id = ?', whereArgs: [nodeId]);
    }
  }

  Future<void> setTrusted(String nodeId, bool trusted) async {
    final db = await _db.db;
    await db.update('peers', {'is_trusted': trusted ? 1 : 0},
        where: 'node_id = ?', whereArgs: [nodeId]);
  }

  PeerNode _rowToPeer(Map<String, dynamic> r) {
    return PeerNode(
      nodeId: r['node_id'] as String,
      displayName: r['display_name'] as String,
      publicKey: r['ed_public_key'] as String?,
      dhPublicKey: r['dh_public_key'] as String?,
      lastSeen: r['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(r['last_seen'] as int)
          : null,
      connectionState: PeerConnectionState.values.firstWhere(
        (s) => s.name == (r['connection_state'] as String),
        orElse: () => PeerConnectionState.disconnected,
      ),
      rssi: r['rssi'] as int?,
      hopCount: r['hop_count'] as int? ?? 0,
      isTrusted: (r['is_trusted'] as int? ?? 0) == 1,
      nextHopId: r['next_hop_id'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Messages DAO
// ---------------------------------------------------------------------------

class MessagesDao {
  final AetherDatabase _db;
  MessagesDao(this._db);

  Future<List<AetherMessage>> getMessages(String conversationId) async {
    final db = await _db.db;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  Future<List<AetherMessage>> getPendingOutbound() async {
    final db = await _db.db;
    final rows = await db.query(
      'messages',
      where: "status IN ('pending', 'sending', 'sent', 'relayed') AND is_outgoing = 1",
    );
    return rows.map(_rowToMessage).toList();
  }

  Future<void> insertMessage(AetherMessage msg) async {
    final db = await _db.db;
    await db.insert('messages', _messageToRow(msg),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(String messageId, MessageStatus status, {int? hopCount, String? routeDesc}) async {
    final db = await _db.db;
    final updates = <String, dynamic>{'status': status.name};
    if (hopCount != null) updates['hop_count'] = hopCount;
    if (routeDesc != null) updates['route_description'] = routeDesc;
    await db.update('messages', updates,
        where: 'message_id = ?', whereArgs: [messageId]);
  }

  Future<void> incrementRetry(String messageId) async {
    final db = await _db.db;
    await db.rawUpdate(
      'UPDATE messages SET retry_count = retry_count + 1 WHERE message_id = ?',
      [messageId],
    );
  }

  Future<void> savePlaintext(String messageId, String plaintext) async {
    final db = await _db.db;
    await db.update('messages', {'plaintext': plaintext},
        where: 'message_id = ?', whereArgs: [messageId]);
  }

  Map<String, dynamic> _messageToRow(AetherMessage msg) => {
    'message_id':        msg.messageId,
    'conversation_id':   msg.conversationId,
    'sender_id':         msg.senderId,
    'receiver_id':       msg.receiverId,
    'encrypted_payload': msg.encryptedPayload,
    'plaintext':         msg.plaintext,
    'timestamp':         msg.timestamp.millisecondsSinceEpoch,
    'status':            msg.status.name,
    'hop_count':         msg.hopCount,
    'message_type':      msg.messageType.name,
    'retry_count':       msg.retryCount,
    'is_outgoing':       msg.isOutgoing ? 1 : 0,
    'route_description': msg.routeDescription,
  };

  AetherMessage _rowToMessage(Map<String, dynamic> r) => AetherMessage(
    messageId:        r['message_id'] as String,
    conversationId:   r['conversation_id'] as String,
    senderId:         r['sender_id'] as String,
    receiverId:       r['receiver_id'] as String,
    encryptedPayload: r['encrypted_payload'] as String,
    plaintext:        r['plaintext'] as String?,
    timestamp:        DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int),
    status:           MessageStatus.values.firstWhere(
      (s) => s.name == (r['status'] as String),
      orElse: () => MessageStatus.pending,
    ),
    hopCount:         r['hop_count'] as int? ?? 0,
    messageType:      MessageType.values.firstWhere(
      (t) => t.name == (r['message_type'] as String),
      orElse: () => MessageType.text,
    ),
    retryCount:       r['retry_count'] as int? ?? 0,
    isOutgoing:       (r['is_outgoing'] as int? ?? 0) == 1,
    routeDescription: r['route_description'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Conversations DAO
// ---------------------------------------------------------------------------

class ConversationsDao {
  final AetherDatabase _db;
  ConversationsDao(this._db);

  Future<List<Conversation>> getAllConversations() async {
    final db = await _db.db;
    final rows = await db.query('conversations', orderBy: 'last_message_time DESC NULLS LAST');
    return rows.map(_rowToConversation).toList();
  }

  Future<Conversation?> getConversation(String conversationId) async {
    final db = await _db.db;
    final rows = await db.query('conversations',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
    if (rows.isEmpty) return null;
    return _rowToConversation(rows.first);
  }

  Future<void> upsertConversation(Conversation conv) async {
    final db = await _db.db;
    await db.insert('conversations', {
      'conversation_id': conv.conversationId,
      'peer_id': conv.peerId,
      'peer_name': conv.peerName,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'last_message_text': conv.lastMessageText,
      'last_message_time': conv.lastMessageTime?.millisecondsSinceEpoch,
      'unread_count': conv.unreadCount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLastMessage(String conversationId, String text, DateTime time, MessageStatus status) async {
    final db = await _db.db;
    await db.update('conversations', {
      'last_message_text': text,
      'last_message_time': time.millisecondsSinceEpoch,
    }, where: 'conversation_id = ?', whereArgs: [conversationId]);
  }

  Conversation _rowToConversation(Map<String, dynamic> r) => Conversation(
    conversationId: r['conversation_id'] as String,
    peerId: r['peer_id'] as String,
    peerName: r['peer_name'] as String,
    lastMessageText: r['last_message_text'] as String?,
    lastMessageTime: r['last_message_time'] != null
        ? DateTime.fromMillisecondsSinceEpoch(r['last_message_time'] as int)
        : null,
    unreadCount: r['unread_count'] as int? ?? 0,
  );
}

// ---------------------------------------------------------------------------
// Routing Table DAO
// ---------------------------------------------------------------------------

class RoutingTableDao {
  final AetherDatabase _db;
  RoutingTableDao(this._db);

  Future<List<RouteEntry>> getAllRoutes() async {
    final db = await _db.db;
    final rows = await db.query('routing_table', orderBy: 'last_updated DESC');
    return rows.map(_rowToRoute).toList();
  }

  Future<RouteEntry?> getRoute(String destinationId) async {
    final db = await _db.db;
    final rows = await db.query('routing_table',
        where: 'destination_id = ?', whereArgs: [destinationId]);
    if (rows.isEmpty) return null;
    return _rowToRoute(rows.first);
  }

  Future<void> upsertRoute(RouteEntry route) async {
    final db = await _db.db;
    await db.insert('routing_table', {
      'destination_id':  route.destinationId,
      'next_hop_id':     route.nextHopId,
      'hop_count':       route.hopCount,
      'sequence_number': route.sequenceNumber,
      'state':           route.state.name,
      'last_updated':    route.lastUpdated.millisecondsSinceEpoch,
      'expires_at':      route.expiresAt.millisecondsSinceEpoch,
      'precursors':      jsonEncode(route.precursors),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> invalidateRoute(String destinationId) async {
    final db = await _db.db;
    await db.update('routing_table', {'state': 'invalid'},
        where: 'destination_id = ?', whereArgs: [destinationId]);
  }

  Future<void> deleteExpired() async {
    final db = await _db.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete('routing_table', where: 'expires_at < ?', whereArgs: [now]);
  }

  RouteEntry _rowToRoute(Map<String, dynamic> r) {
    final precursors = (jsonDecode(r['precursors'] as String? ?? '[]') as List)
        .cast<String>();
    return RouteEntry(
      destinationId: r['destination_id'] as String,
      nextHopId:     r['next_hop_id'] as String,
      hopCount:      r['hop_count'] as int,
      sequenceNumber: r['sequence_number'] as int,
      state: RouteState.values.firstWhere(
        (s) => s.name == (r['state'] as String),
        orElse: () => RouteState.invalid,
      ),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(r['last_updated'] as int),
      expiresAt:   DateTime.fromMillisecondsSinceEpoch(r['expires_at'] as int),
      precursors:  precursors,
    );
  }
}

// ---------------------------------------------------------------------------
// Seen Messages DAO (dedup cache)
// ---------------------------------------------------------------------------

class SeenMessagesDao {
  final AetherDatabase _db;
  SeenMessagesDao(this._db);

  final Set<String> _memCache = {};

  Future<bool> hasSeen(String messageId) async {
    if (_memCache.contains(messageId)) return true;
    final db = await _db.db;
    final rows = await db.query('seen_messages',
        where: 'message_id = ?', whereArgs: [messageId]);
    if (rows.isNotEmpty) {
      _memCache.add(messageId);
      return true;
    }
    return false;
  }

  Future<void> markSeen(String messageId) async {
    _memCache.add(messageId);
    final db = await _db.db;
    await db.insert('seen_messages', {
      'message_id': messageId,
      'seen_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // Evict old entries if cache grows too large
    if (_memCache.length > 1000) {
      await _evictOld(db);
    }
  }

  Future<void> _evictOld(Database db) async {
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    await db.delete('seen_messages', where: 'seen_at < ?', whereArgs: [cutoff]);
    _memCache.clear(); // Reload from DB on next access
  }
}

// ---------------------------------------------------------------------------
// Broadcast Messages DAO
// ---------------------------------------------------------------------------

class BroadcastDao {
  final AetherDatabase _db;
  BroadcastDao(this._db);

  Future<List<NetworkAlert>> getRecentAlerts({int limit = 50}) async {
    final db = await _db.db;
    final rows = await db.query('broadcast_messages',
        orderBy: 'timestamp DESC', limit: limit);
    return rows.map(_rowToAlert).toList();
  }

  Future<void> saveAlert(NetworkAlert alert) async {
    final db = await _db.db;
    await db.insert('broadcast_messages', {
      'message_id':  alert.messageId,
      'origin_id':   alert.originId,
      'origin_name': alert.originName,
      'alert_type':  alert.alertType.name,
      'content':     alert.content,
      'timestamp':   alert.timestamp.millisecondsSinceEpoch,
      'ttl':         alert.ttl,
      'hop_count':   alert.hopCount,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  NetworkAlert _rowToAlert(Map<String, dynamic> r) => NetworkAlert(
    messageId:  r['message_id'] as String,
    originId:   r['origin_id'] as String,
    originName: r['origin_name'] as String,
    alertType:  MessageType.values.firstWhere(
      (t) => t.name == (r['alert_type'] as String),
      orElse: () => MessageType.broadcast,
    ),
    content:    r['content'] as String,
    timestamp:  DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int),
    hopCount:   r['hop_count'] as int? ?? 0,
    ttl:        r['ttl'] as int? ?? 0,
  );
}
