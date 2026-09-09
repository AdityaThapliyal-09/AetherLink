// AetherLink Network Manager — central coordinator.
// Orchestrates BLE events, AODV routing, encryption, and message delivery.
// Acts as the application-layer mesh network implementation on top of
// individual BLE connections.
//
// Message flow (sending):
//   UI → NetworkManager.sendMessage()
//     → CryptoService.encrypt(plaintext, peerId)
//     → AodvManager.getRoute(peerId) / discoverRoute(peerId)
//     → BleService.sendPacket(nextHopId, packet.toBytes())
//     → (relay nodes forward packet)
//     → Destination receives and decrypts
//     → ACK travels back
//
// Message flow (receiving):
//   BleService event → NetworkManager._onPacketReceived()
//     → Dedup check (SeenMessagesDao)
//     → Route packet (forward if not for us, or decrypt if for us)
//     → Store in DB, update UI via streams

import 'dart:async';
import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/aether_errors.dart';
import '../../core/logging/logger.dart';
import '../../core/utils/utils.dart';
import '../../data/database/daos.dart';
import '../../domain/entities/aether_packet.dart';
import '../../domain/entities/local_identity.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/peer_node.dart';
import '../../domain/entities/route_entry.dart';
import '../bluetooth/ble_service.dart';
import '../encryption/crypto_service.dart';
import '../encryption/identity_service.dart';
import '../routing/aodv_manager.dart';
import 'packet_chunker.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  // Dependencies
  final _ble = BleService();
  final _crypto = CryptoService();
  final _identity = IdentityService();
  final _chunker = PacketChunker();

  late AodvManager _aodv;
  late PeersDao _peersDao;
  late MessagesDao _messagesDao;
  late ConversationsDao _conversationsDao;
  late SeenMessagesDao _seenDao;
  late BroadcastDao _broadcastDao;

  // Stream controllers for UI updates
  final _peerStream = StreamController<List<PeerNode>>.broadcast();
  final _messageStream = StreamController<AetherMessage>.broadcast();
  final _alertStream = StreamController<NetworkAlert>.broadcast();
  final _networkStateStream = StreamController<NetworkState>.broadcast();

  Stream<List<PeerNode>> get peerUpdates => _peerStream.stream;
  Stream<AetherMessage> get messageUpdates => _messageStream.stream;
  Stream<NetworkAlert> get alertUpdates => _alertStream.stream;
  Stream<NetworkState> get networkStateUpdates => _networkStateStream.stream;

  // In-memory peer map: nodeId → PeerNode
  final Map<String, PeerNode> _peers = {};

  // Track nodes to whom we have dispatched KEY_EXCHANGE
  final Set<String> _sentKeyExchangeTo = {};

  // Store-and-forward pending queue: messageId → AetherPacket
  final Map<String, AetherPacket> _pendingPackets = {};

  // Chunk reassembly buffers: chunkSessionId → PacketChunker.Buffer
  final Map<String, ChunkBuffer> _chunkBuffers = {};

  StreamSubscription? _bleEventSub;
  Timer? _maintenanceTimer;
  Timer? _retryTimer;

  NetworkState _networkState = NetworkState.idle;
  LocalIdentity? _localIdentity;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize({
    required IdentityDao identityDao,
    required PeersDao peersDao,
    required MessagesDao messagesDao,
    required ConversationsDao conversationsDao,
    required RoutingTableDao routingDao,
    required SeenMessagesDao seenDao,
    required BroadcastDao broadcastDao,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _peersDao = peersDao;
    _messagesDao = messagesDao;
    _conversationsDao = conversationsDao;
    _seenDao = seenDao;
    _broadcastDao = broadcastDao;

    // Load identity
    _identity.configure(identityDao);
    _localIdentity = await _identity.getOrCreateIdentity();
    final identity = _localIdentity!;

    // Initialize AODV routing
    _aodv = AodvManager(
      localNodeId: identity.nodeId,
      routingDao: routingDao,
    );
    _aodv.configure(
      sendTo: _sendPacketDirect,
      broadcast: _broadcastPacket,
    );
    await _aodv.loadRoutesFromDatabase();

    // Initialize BLE layer
    await _ble.initialize(
      identity.nodeId,
      identity.displayName,
      identity.edPublicKey,
      identity.dhPublicKey,
    );

    // Subscribe to BLE events
    _bleEventSub = _ble.events.listen(_onBleEvent);

    // Pre-load known peers from database
    final savedPeers = await _peersDao.getAllPeers();
    for (final p in savedPeers) {
      _peers[p.nodeId] = p.copyWith(
        connectionState: PeerConnectionState.disconnected,
      );
    }

    // Start networking
    await _startNetworking();

    // Start maintenance timers
    _startMaintenanceTimer();
    _startRetryTimer();

    logger.system('NetworkManager initialized — local node: ${identity.nodeId}');
  }

  Future<void> _startNetworking() async {
    final hasPerms = await _ble.checkPermissions();
    if (!hasPerms) {
      _setNetworkState(NetworkState.permissionRequired);
      return;
    }
    final bleOn = await _ble.isBluetoothEnabled();
    if (!bleOn) {
      _setNetworkState(NetworkState.bluetoothOff);
      return;
    }
    await _ble.startAdvertising();
    await _ble.startDiscovery();
    _setNetworkState(NetworkState.scanning);
  }

  // ---------------------------------------------------------------------------
  // BLE Event Handling
  // ---------------------------------------------------------------------------

  void _onBleEvent(BleEvent event) {
    switch (event) {
      case PeerDiscoveredEvent():
        _onPeerDiscovered(event);
      case PeerConnectedEvent():
        _onPeerConnected(event);
      case PeerDisconnectedEvent():
        _onPeerDisconnected(event);
      case PacketReceivedEvent():
        _onPacketReceived(event);
      case NetworkStateChangedEvent():
        _onNetworkStateChanged(event);
      case BleRssiUpdatedEvent():
        _onRssiUpdated(event);
    }
  }

  void _onPeerDiscovered(PeerDiscoveredEvent e) {
    final existing = _peers[e.nodeId];
    final hasKey = _crypto.hasSessionKey(e.nodeId);
    if (existing == null) {
      final peer = PeerNode(
        nodeId: e.nodeId,
        displayName: e.displayName,
        connectionState: hasKey ? PeerConnectionState.ready : PeerConnectionState.discovering,
        rssi: e.rssi,
        lastSeen: DateTime.now(),
      );
      _peers[e.nodeId] = peer;
      _peersDao.upsertPeer(peer);
    } else {
      final nextState = hasKey
          ? PeerConnectionState.ready
          : (existing.connectionState == PeerConnectionState.ready
              ? PeerConnectionState.ready
              : (existing.connectionState == PeerConnectionState.connected
                  ? PeerConnectionState.connected
                  : PeerConnectionState.discovering));
      _peers[e.nodeId] = existing.copyWith(
        displayName: (e.displayName.isNotEmpty && !e.displayName.startsWith('Peer '))
            ? e.displayName
            : existing.displayName,
        rssi: e.rssi,
        lastSeen: DateTime.now(),
        connectionState: nextState,
      );
    }
    _notifyPeerUpdate();

    // Auto-connect to newly discovered peers
    _ble.connectToPeer(e.deviceAddress, e.nodeId);
  }

  void _onPeerConnected(PeerConnectedEvent e) {
    final hasKey = _crypto.hasSessionKey(e.nodeId);
    _updatePeerState(e.nodeId, hasKey ? PeerConnectionState.ready : PeerConnectionState.connected);

    // Install direct route
    _aodv.installDirectRoute(e.nodeId);

    // Initiate key exchange
    _sendHello(e.nodeId);

    // Attempt to deliver any pending messages for this peer or via this peer
    _triggerPendingDelivery();

    if (_peers.isNotEmpty) {
      _setNetworkState(NetworkState.connected);
    }
    logger.network('Peer connected: ${e.nodeId}');
  }

  void _onPeerDisconnected(PeerDisconnectedEvent e) {
    _updatePeerState(e.nodeId, PeerConnectionState.disconnected);
    _aodv.onPeerDisconnected(e.nodeId);
    _crypto.clearSessionKey(e.nodeId);
    _sentKeyExchangeTo.remove(e.nodeId);

    if (_peers.values.every((p) => !p.connectionState.isReachable)) {
      _setNetworkState(NetworkState.scanning);
    }
    logger.network('Peer disconnected: ${e.nodeId}');
  }

  void _onPacketReceived(PacketReceivedEvent e) {
    // Handle chunked packets first
    if (_chunker.isChunkData(e.rawBytes)) {
      final completed = _chunker.addChunk(e.rawBytes, _chunkBuffers);
      if (completed == null) return; // More chunks expected
      _processIncomingBytes(completed, e.fromNodeId);
      return;
    }
    _processIncomingBytes(e.rawBytes, e.fromNodeId);
  }

  void _processIncomingBytes(List<int> bytes, String fromPeerId) {
    try {
      final packet = AetherPacket.fromBytes(bytes);
      _routeIncomingPacket(packet, fromPeerId);
    } catch (err) {
      logger.network('Failed to parse incoming packet from $fromPeerId: $err',
          level: LogLevel.error);
    }
  }

  void _onNetworkStateChanged(NetworkStateChangedEvent e) {
    if (!e.bluetoothEnabled) {
      _setNetworkState(NetworkState.bluetoothOff);
      return;
    }
    if (e.isScanning || e.isAdvertising) {
      if (_peers.values.any((p) => p.connectionState.isReachable)) {
        _setNetworkState(NetworkState.connected);
      } else {
        _setNetworkState(NetworkState.scanning);
      }
    }
  }

  void _onRssiUpdated(BleRssiUpdatedEvent e) {
    final peer = _peers[e.nodeId];
    if (peer != null) {
      _peers[e.nodeId] = peer.copyWith(rssi: e.rssi);
      _notifyPeerUpdate();
    }
  }

  // ---------------------------------------------------------------------------
  // Packet Routing — Application-layer mesh
  // ---------------------------------------------------------------------------

  Future<void> _routeIncomingPacket(AetherPacket packet, String fromPeerId) async {
    // TTL check
    if (packet.ttl <= 0) {
      logger.network('Packet dropped: TTL exhausted ${packet.packetId.substring(0, 8)}');
      return;
    }

    // Let AODV handle routing control packets (RREQ, RREP, RERR)
    final handledByAodv = await _aodv.processPacket(packet, fromPeerId);
    if (handledByAodv) return;

    // Dedup check for all other packets
    final alreadySeen = await _seenDao.hasSeen(packet.packetId);
    if (alreadySeen) {
      logger.network('Packet dropped: duplicate ${packet.packetId.substring(0, 8)}');
      return;
    }
    await _seenDao.markSeen(packet.packetId);

    switch (packet.type) {
      case PacketType.hello:
        await _handleHello(packet, fromPeerId);
      case PacketType.peerInfo:
        await _handlePeerInfo(packet, fromPeerId);
      case PacketType.keyExchange:
        await _handleKeyExchange(packet, fromPeerId);
      case PacketType.data:
        await _handleData(packet, fromPeerId);
      case PacketType.ack:
        await _handleAck(packet);
      case PacketType.broadcast:
        await _handleBroadcast(packet, fromPeerId);
      case PacketType.sos:
        await _handleSos(packet, fromPeerId);
      case PacketType.heartbeat:
        _updatePeerLastSeen(fromPeerId);
      default:
        logger.network('Unhandled packet type: ${packet.type.wireCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // Protocol Handlers
  // ---------------------------------------------------------------------------

  Future<void> _sendHello(String peerId) async {
    final identity = _localIdentity!;
    final hello = AetherPacket(
      version: 1,
      type: PacketType.hello,
      packetId: generateMessageId(),
      originId: identity.nodeId,
      destinationId: peerId,
      previousHopId: identity.nodeId,
      ttl: 1,
      hopCount: 0,
      sequenceNumber: 0,
      timestamp: nowMs(),
      payload: jsonEncode({
        'displayName': identity.displayName,
        'protocolVersion': 1,
      }),
    );
    await _sendPacketDirect(peerId, hello);
    logger.network('HELLO sent to $peerId');

    // Follow up with key exchange
    await _sendKeyExchange(peerId);
  }

  Future<void> _handleHello(AetherPacket packet, String fromPeerId) async {
    final data = jsonDecode(packet.payload ?? '{}') as Map<String, dynamic>;
    final displayName = data['displayName'] as String? ?? 'Unknown';

    _updatePeerDisplayName(packet.originId, displayName);
    if (_crypto.hasSessionKey(packet.originId)) {
      _updatePeerState(packet.originId, PeerConnectionState.ready);
    } else {
      _updatePeerState(packet.originId, PeerConnectionState.authenticating);
    }
    logger.network('HELLO received from ${packet.originId} ($displayName)');
  }

  Future<void> _sendKeyExchange(String peerId) async {
    _sentKeyExchangeTo.add(peerId);
    final identity = _localIdentity!;
    final kex = AetherPacket(
      version: 1,
      type: PacketType.keyExchange,
      packetId: generateMessageId(),
      originId: identity.nodeId,
      destinationId: peerId,
      previousHopId: identity.nodeId,
      ttl: 1,
      hopCount: 0,
      sequenceNumber: 0,
      timestamp: nowMs(),
      payload: jsonEncode({
        'edPublicKey': identity.edPublicKey,
        'dhPublicKey': identity.dhPublicKey,
      }),
    );
    await _sendPacketDirect(peerId, kex);
    logger.crypto('KEY_EXCHANGE sent to $peerId');
  }

  Future<void> _handleKeyExchange(AetherPacket packet, String fromPeerId) async {
    try {
      final data = jsonDecode(packet.payload ?? '{}') as Map<String, dynamic>;
      final peerEdKey = data['edPublicKey'] as String? ?? '';
      final peerDhKey = data['dhPublicKey'] as String? ?? '';

      // Store peer's public keys
      await _peersDao.updatePublicKeys(packet.originId,
          edKey: peerEdKey, dhKey: peerDhKey);
      _updatePeerPublicKeys(packet.originId, edKey: peerEdKey, dhKey: peerDhKey);

      // Compute ECDH shared secret and derive session key
      final dhPrivKey = await _identity.getDhPrivateKey();
      final identity = _localIdentity!;
      final sharedSecret = _crypto.computeSharedSecret(dhPrivKey, peerDhKey);
      final sessionKey = _crypto.deriveSessionKey(
          sharedSecret, identity.nodeId, packet.originId);
      _crypto.storeSessionKey(packet.originId, sessionKey);

      // Mark peer as ready
      _updatePeerState(packet.originId, PeerConnectionState.ready);
      logger.crypto('Session key established with ${packet.originId}');

      // If we haven't sent our key exchange to this peer yet, reply immediately
      // so key exchange is guaranteed mutual
      if (!_sentKeyExchangeTo.contains(packet.originId)) {
        await _sendKeyExchange(packet.originId);
      }

      // Trigger delivery of any pending messages for this peer
      _triggerPendingDelivery();
    } catch (e) {
      logger.crypto('Key exchange failed with ${packet.originId}: $e',
          level: LogLevel.error);
    }
  }

  Future<void> _handlePeerInfo(AetherPacket packet, String fromPeerId) async {
    // Extended peer info — update routing table with relay peer information
    // final data = jsonDecode(packet.payload ?? '{}') as Map<String, dynamic>;
    // Future: parse peer's known peers list for topology awareness
    logger.network('PEER_INFO received from ${packet.originId}');
  }

  Future<void> _handleData(AetherPacket packet, String fromPeerId) async {
    final identity = _localIdentity!;

    if (packet.destinationId == identity.nodeId) {
      // This message is for US — decrypt and store
      await _deliverDataToLocal(packet, fromPeerId);
    } else {
      // This message is for someone else — forward it
      await _forwardData(packet, fromPeerId);
    }
  }

  Future<void> _deliverDataToLocal(AetherPacket packet, String fromPeerId) async {
    logger.network('DATA packet received for local node from ${packet.originId}');

    String? plaintext;
    try {
      if (_crypto.hasSessionKey(packet.originId)) {
        plaintext = _crypto.decrypt(packet.payload ?? '', packet.originId);
        logger.network('Message decrypted from ${packet.originId}');
        _updatePeerState(packet.originId, PeerConnectionState.ready);
      } else {
        logger.network('No session key for ${packet.originId} — storing ciphertext only',
            level: LogLevel.warning);
      }
    } catch (e) {
      logger.crypto('Decryption failed for message from ${packet.originId}: $e',
          level: LogLevel.error);
    }

    final identity = _localIdentity!;
    final msg = AetherMessage(
      messageId: packet.packetId,
      conversationId: packet.originId,
      senderId: packet.originId,
      receiverId: identity.nodeId,
      encryptedPayload: packet.payload ?? '',
      plaintext: plaintext,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
      status: MessageStatus.delivered,
      hopCount: packet.hopCount,
      messageType: MessageType.text,
      isOutgoing: false,
      routeDescription: packet.hopCount > 0 ? 'via ${packet.hopCount} hops' : 'direct',
    );

    await _messagesDao.insertMessage(msg);
    await _ensureConversation(packet.originId);
    await _conversationsDao.updateLastMessage(
      packet.originId, plaintext ?? '[encrypted]', msg.timestamp, MessageStatus.delivered);
    await _conversationsDao.incrementUnread(packet.originId);

    _messageStream.add(msg);
    _updatePeerLastSeen(fromPeerId);

    // Dispatch system notification
    final peer = _peers[packet.originId];
    final senderName = peer?.displayName ?? packet.originId;
    unawaited(_ble.showMessageNotification(
      senderName: senderName,
      messageText: plaintext ?? '[Encrypted message]',
      peerId: packet.originId,
    ));

    // Send ACK back
    await _sendAck(packet);
  }

  Future<void> _forwardData(AetherPacket packet, String fromPeerId) async {
    if (packet.ttl <= 1) {
      logger.network('DATA not forwarded: TTL exhausted');
      return;
    }

    final route = _aodv.getRoute(packet.destinationId);
    if (route == null) {
      logger.network('DATA not forwarded: no route to ${packet.destinationId}',
          level: LogLevel.warning);
      // Store for later delivery
      _pendingPackets[packet.packetId] = packet;
      await _aodv.discoverRoute(packet.destinationId).then((_) {
        _triggerPendingDelivery();
      }).catchError((e) {
        logger.routing('Route discovery failed for forwarding: $e');
      });
      return;
    }

    final identity = _localIdentity!;
    final forwarded = packet.relay(newPreviousHopId: identity.nodeId);
    logger.network('DATA forwarded: ${packet.originId}→${packet.destinationId} via ${route.nextHopId}');
    await _sendPacketDirect(route.nextHopId, forwarded);
  }

  Future<void> _sendAck(AetherPacket dataPacket) async {
    final identity = _localIdentity!;
    final ack = AetherPacket(
      version: 1,
      type: PacketType.ack,
      packetId: generateMessageId(),
      originId: identity.nodeId,
      destinationId: dataPacket.originId,
      previousHopId: identity.nodeId,
      ttl: AppConstants.defaultTtl,
      hopCount: 0,
      sequenceNumber: 0,
      timestamp: nowMs(),
      routingMeta: {'ack_for': dataPacket.packetId},
    );
    await _sendOrRoute(dataPacket.originId, ack);
    logger.network('ACK sent for ${dataPacket.packetId.substring(0, 8)}');
  }

  Future<void> _handleAck(AetherPacket ack) async {
    final identity = _localIdentity!;
    if (ack.destinationId == identity.nodeId) {
      final ackedId = ack.routingMeta?['ack_for'] as String?;
      if (ackedId != null) {
        await _messagesDao.updateStatus(ackedId, MessageStatus.delivered,
            hopCount: ack.hopCount,
            routeDesc: ack.hopCount > 0 ? 'via ${ack.hopCount} hops' : 'direct');
        logger.network('ACK received: message $ackedId marked DELIVERED');
        // Notify UI of status update
        final msgs = await _messagesDao.getMessages(ack.originId);
        final updated = msgs.where((m) => m.messageId == ackedId).firstOrNull;
        if (updated != null) _messageStream.add(updated);
      }
    } else {
      // Forward ACK toward its destination
      await _forwardData(ack, ack.previousHopId);
    }
  }

  Future<void> _handleBroadcast(AetherPacket packet, String fromPeerId) async {
    logger.broadcast('BROADCAST received from ${packet.originId} (${packet.hopCount} hops)');

    final data = jsonDecode(packet.payload ?? '{}') as Map<String, dynamic>;
    final content = data['text'] as String? ?? '';
    final senderName = data['name'] as String? ?? packet.originId;

    final alert = NetworkAlert(
      messageId: packet.packetId,
      originId: packet.originId,
      originName: senderName,
      alertType: MessageType.broadcast,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
      hopCount: packet.hopCount,
      ttl: packet.ttl,
    );

    await _broadcastDao.saveAlert(alert);
    _alertStream.add(alert);

    // Forward to other peers if TTL allows
    if (packet.ttl > 1) {
      final forwarded = packet.relay(
          newPreviousHopId: _localIdentity!.nodeId);
      await _broadcastPacket(forwarded, excludePeer: fromPeerId);
    }
  }

  Future<void> _handleSos(AetherPacket packet, String fromPeerId) async {
    logger.sos('SOS received from ${packet.originId} (${packet.hopCount} hops)');

    final data = jsonDecode(packet.payload ?? '{}') as Map<String, dynamic>;
    final content = data['text'] as String? ?? 'EMERGENCY — SOS';
    final senderName = data['name'] as String? ?? packet.originId;

    final alert = NetworkAlert(
      messageId: packet.packetId,
      originId: packet.originId,
      originName: senderName,
      alertType: MessageType.sos,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
      hopCount: packet.hopCount,
      ttl: packet.ttl,
    );

    await _broadcastDao.saveAlert(alert);
    _alertStream.add(alert);

    // Sound loud 2.5-3s emergency SOS siren upon detecting SOS
    unawaited(_ble.playSosSiren());

    // SOS has higher priority TTL — forward aggressively
    if (packet.ttl > 1) {
      final forwarded = packet.relay(
          newPreviousHopId: _localIdentity!.nodeId);
      await _broadcastPacket(forwarded, excludePeer: fromPeerId);
    }
  }

  // ---------------------------------------------------------------------------
  // Public API — called by UI layer
  // ---------------------------------------------------------------------------

  /// Sends an encrypted message to a peer (direct or via routing).
  Future<void> sendMessage(String peerId, String plaintext) async {
    final identity = _localIdentity!;

    if (plaintext.length > AppConstants.maxMessageLength) {
      throw MessageTooLargeError(plaintext.length, AppConstants.maxMessageLength);
    }

    // Ensure conversation exists
    await _ensureConversation(peerId);

    // Encrypt (requires session key with peer)
    String encryptedPayload;
    if (_crypto.hasSessionKey(peerId)) {
      encryptedPayload = _crypto.encrypt(plaintext, peerId);
    } else {
      // Encrypt with a placeholder if key exchange hasn't completed yet
      // Message stored as pending and delivered after key exchange
      encryptedPayload = base64.encode(utf8.encode('[pending-key-exchange]'));
    }

    final msgId = generateMessageId();
    final msg = AetherMessage(
      messageId: msgId,
      conversationId: peerId,
      senderId: identity.nodeId,
      receiverId: peerId,
      encryptedPayload: encryptedPayload,
      plaintext: plaintext,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      messageType: MessageType.text,
      isOutgoing: true,
    );

    await _messagesDao.insertMessage(msg);
    _messageStream.add(msg);
    await _conversationsDao.updateLastMessage(peerId, plaintext, msg.timestamp, MessageStatus.sending);

    // Build DATA packet
    final packet = AetherPacket(
      version: 1,
      type: PacketType.data,
      packetId: msgId,
      originId: identity.nodeId,
      destinationId: peerId,
      previousHopId: identity.nodeId,
      ttl: AppConstants.defaultTtl,
      hopCount: 0,
      sequenceNumber: generateSequenceNumber(),
      timestamp: nowMs(),
      payload: encryptedPayload,
    );

    await _seenDao.markSeen(msgId); // Don't re-process our own messages

    // Try to send (stores in pending queue if no route)
    try {
      await _sendOrRoute(peerId, packet);
      await _messagesDao.updateStatus(msgId, MessageStatus.sent);
      final updated = msg.copyWith(status: MessageStatus.sent);
      _messageStream.add(updated);
    } catch (e) {
      // Store in pending queue for store-and-forward
      _pendingPackets[msgId] = packet;
      await _messagesDao.updateStatus(msgId, MessageStatus.pending);
      final updated = msg.copyWith(status: MessageStatus.pending);
      _messageStream.add(updated);
      logger.messaging('Message $msgId queued for store-and-forward: $e');
    }
  }

  /// Sends a network-wide broadcast message.
  Future<void> sendBroadcast(String text) async {
    final identity = _localIdentity!;
    final msgId = generateMessageId();

    final packet = AetherPacket(
      version: 1,
      type: PacketType.broadcast,
      packetId: msgId,
      originId: identity.nodeId,
      destinationId: '*',
      previousHopId: identity.nodeId,
      ttl: AppConstants.defaultTtl,
      hopCount: 0,
      sequenceNumber: 0,
      timestamp: nowMs(),
      payload: jsonEncode({'text': text, 'name': identity.displayName}),
    );

    await _seenDao.markSeen(msgId);
    await _broadcastPacket(packet);
    logger.broadcast('BROADCAST sent: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"');
  }

  /// Sends an SOS emergency alert.
  Future<void> sendSos(String message) async {
    final identity = _localIdentity!;
    final msgId = generateMessageId();

    final packet = AetherPacket(
      version: 1,
      type: PacketType.sos,
      packetId: msgId,
      originId: identity.nodeId,
      destinationId: '*',
      previousHopId: identity.nodeId,
      ttl: AppConstants.sosTtl,
      hopCount: 0,
      sequenceNumber: 0,
      timestamp: nowMs(),
      payload: jsonEncode({
        'text': message,
        'name': identity.displayName,
        'priority': 'EMERGENCY',
      }),
    );

    await _seenDao.markSeen(msgId);
    await _broadcastPacket(packet);
    logger.sos('SOS sent by ${identity.nodeId}: "$message"');
  }

  List<PeerNode> getActivePeers() =>
      _peers.values.where((p) => p.connectionState != PeerConnectionState.disconnected).toList();

  LocalIdentity? get localIdentity => _localIdentity;

  NetworkState get networkState => _networkState;

  AodvManager get aodvManager => _aodv;

  bool hasSessionKey(String peerId) => _crypto.hasSessionKey(peerId);

  Future<void> initiateKeyExchange(String peerId) async {
    await _sendHello(peerId);
  }

  // ---------------------------------------------------------------------------
  // Private Transport Helpers
  // ---------------------------------------------------------------------------

  /// Sends a packet directly to a connected peer (chunked if large).
  Future<void> _sendPacketDirect(String peerId, AetherPacket packet) async {
    final bytes = packet.toBytes();

    if (bytes.length <= AppConstants.bleChunkPayloadSize) {
      final success = await _ble.sendPacket(peerId, bytes);
      if (!success) throw BleConnectionError(peerId);
    } else {
      // Chunk the packet
      final chunks = _chunker.chunk(bytes);
      for (final chunk in chunks) {
        final success = await _ble.sendPacket(peerId, chunk);
        if (!success) throw BleConnectionError(peerId);
        // Small delay between chunks to avoid overwhelming BLE buffer
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  /// Routes a packet to its destination using the routing table.
  Future<void> _sendOrRoute(String destinationId, AetherPacket packet) async {
    // Check for direct connection first
    if (_peers[destinationId]?.connectionState.isReachable ?? false) {
      if (_peers[destinationId]!.connectionState == PeerConnectionState.ready ||
          _peers[destinationId]!.connectionState == PeerConnectionState.connected) {
        await _sendPacketDirect(destinationId, packet);
        return;
      }
    }

    // Look up routing table
    RouteEntry? route = _aodv.getRoute(destinationId);
    route ??= await _aodv.discoverRoute(destinationId);

    await _sendPacketDirect(route.nextHopId, packet);
  }

  /// Broadcasts a packet to ALL currently connected peers (except optional exclusion).
  Future<void> _broadcastPacket(AetherPacket packet, {String? excludePeer}) async {
    final connected = _peers.entries
        .where((e) =>
            e.value.connectionState.isReachable &&
            e.key != excludePeer)
        .map((e) => e.key)
        .toList();

    for (final peerId in connected) {
      try {
        await _sendPacketDirect(peerId, packet);
      } catch (e) {
        logger.network('Broadcast to $peerId failed: $e', level: LogLevel.warning);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Store-and-Forward Retry
  // ---------------------------------------------------------------------------

  void _startRetryTimer() {
    _retryTimer = Timer.periodic(
      const Duration(seconds: AppConstants.storeForwardCheckIntervalSeconds),
      (_) => _triggerPendingDelivery(),
    );
  }

  void _triggerPendingDelivery() {
    if (_pendingPackets.isEmpty) return;
    final toRetry = Map.from(_pendingPackets);
    for (final entry in toRetry.entries) {
      final packet = entry.value;
      final route = _aodv.getRoute(packet.destinationId);
      if (route != null) {
        _pendingPackets.remove(entry.key);
        _sendPacketDirect(route.nextHopId, packet).then((_) {
          _messagesDao.updateStatus(entry.key, MessageStatus.sent);
          logger.messaging('Pending message ${entry.key} delivered via store-and-forward');
        }).catchError((e) {
          logger.messaging('Retry failed for ${entry.key}: $e');
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  void _startMaintenanceTimer() {
    _maintenanceTimer = Timer.periodic(
      const Duration(seconds: AppConstants.heartbeatIntervalSeconds),
      (_) async {
        await _aodv.performMaintenance();
        await _sendHeartbeats();
        await _cleanStalePeers();
      },
    );
  }

  Future<void> _sendHeartbeats() async {
    final identity = _localIdentity;
    if (identity == null) return;
    final connected = _peers.entries
        .where((e) => e.value.connectionState == PeerConnectionState.ready)
        .map((e) => e.key)
        .toList();
    for (final peerId in connected) {
      final hbt = AetherPacket(
        version: 1,
        type: PacketType.heartbeat,
        packetId: generateMessageId(),
        originId: identity.nodeId,
        destinationId: peerId,
        previousHopId: identity.nodeId,
        ttl: 1,
        hopCount: 0,
        sequenceNumber: 0,
        timestamp: nowMs(),
      );
      try {
        await _sendPacketDirect(peerId, hbt);
      } catch (_) {}
    }
  }

  Future<void> _cleanStalePeers() async {
    final cutoff = DateTime.now().subtract(
        const Duration(seconds: AppConstants.staleConnectionTimeoutSeconds));
    final stale = _peers.entries
        .where((e) =>
            e.value.lastSeen != null &&
            e.value.lastSeen!.isBefore(cutoff) &&
            !e.value.connectionState.isReachable)
        .map((e) => e.key)
        .toList();
    for (final id in stale) {
      _peers.remove(id);
    }
    if (stale.isNotEmpty) {
      _notifyPeerUpdate();
      logger.bluetooth('Removed ${stale.length} stale peers');
    }
  }

  // ---------------------------------------------------------------------------
  // UI State Helpers
  // ---------------------------------------------------------------------------

  void _updatePeerState(String nodeId, PeerConnectionState state) {
    var peer = _peers[nodeId];
    final hasSessionKey = _crypto.hasSessionKey(nodeId);

    // If session key exists and state is not disconnected or error, force ready
    if (hasSessionKey &&
        state != PeerConnectionState.disconnected &&
        state != PeerConnectionState.error) {
      state = PeerConnectionState.ready;
    }

    if (peer != null) {
      // Guard against accidental downgrade if already ready
      if (peer.connectionState == PeerConnectionState.ready &&
          (state == PeerConnectionState.connected ||
           state == PeerConnectionState.authenticating ||
           state == PeerConnectionState.connecting ||
           state == PeerConnectionState.discovering)) {
        logger.network('Preserving ready state for $nodeId (ignoring downgrade to $state)');
        return;
      }

      _peers[nodeId] = peer.copyWith(
          connectionState: state, lastSeen: DateTime.now());
      _peersDao.updateConnectionState(nodeId, state);
      _notifyPeerUpdate();
    } else {
      final newPeer = PeerNode(
        nodeId: nodeId,
        displayName: 'Peer ${nodeId.length >= 4 ? nodeId.substring(nodeId.length - 4).toUpperCase() : nodeId}',
        connectionState: state,
        lastSeen: DateTime.now(),
      );
      _peers[nodeId] = newPeer;
      _peersDao.upsertPeer(newPeer);
      _notifyPeerUpdate();

      _peersDao.getPeer(nodeId).then((dbPeer) {
        if (dbPeer != null && _peers[nodeId] != null) {
          _peers[nodeId] = _peers[nodeId]!.copyWith(
            displayName: (dbPeer.displayName.isNotEmpty && !dbPeer.displayName.startsWith('Peer '))
                ? dbPeer.displayName
                : null,
            publicKey: dbPeer.publicKey,
            dhPublicKey: dbPeer.dhPublicKey,
            isTrusted: dbPeer.isTrusted,
          );
          _notifyPeerUpdate();
        }
      });
    }
  }

  void _updatePeerDisplayName(String nodeId, String name) {
    final peer = _peers[nodeId];
    if (peer != null) {
      _peers[nodeId] = peer.copyWith(displayName: name);
      _notifyPeerUpdate();
    }
  }

  void _updatePeerPublicKeys(String nodeId,
      {String? edKey, String? dhKey}) {
    final peer = _peers[nodeId];
    if (peer != null) {
      _peers[nodeId] = peer.copyWith(publicKey: edKey, dhPublicKey: dhKey);
      _notifyPeerUpdate();
    }
  }

  void _updatePeerLastSeen(String nodeId) {
    final peer = _peers[nodeId];
    if (peer != null) {
      _peers[nodeId] = peer.copyWith(lastSeen: DateTime.now());
    }
  }

  void _notifyPeerUpdate() {
    _peerStream.add(getActivePeers());
  }

  void _setNetworkState(NetworkState state) {
    if (_networkState == state) return;
    _networkState = state;
    _networkStateStream.add(state);
    logger.network('Network state: ${state.label}');
  }

  Future<void> _ensureConversation(String peerId) async {
    final existing = await _conversationsDao.getConversation(peerId);
    if (existing == null) {
      final peerName = _peers[peerId]?.displayName ?? peerId;
      await _conversationsDao.upsertConversation(Conversation(
        conversationId: peerId,
        peerId: peerId,
        peerName: peerName,
      ));
    }
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.notification,
    ].request();

    final granted = await _ble.checkPermissions();
    if (granted) await _startNetworking();
  }

  Future<void> dispose() async {
    await _bleEventSub?.cancel();
    _maintenanceTimer?.cancel();
    _retryTimer?.cancel();
    await _peerStream.close();
    await _messageStream.close();
    await _alertStream.close();
    await _networkStateStream.close();
  }
}

/// High-level network state for UI display.
enum NetworkState {
  idle,
  permissionRequired,
  bluetoothOff,
  scanning,
  connected,
  error,
}

extension NetworkStateExtension on NetworkState {
  String get label {
    switch (this) {
      case NetworkState.idle:               return 'Idle';
      case NetworkState.permissionRequired: return 'Permission Required';
      case NetworkState.bluetoothOff:       return 'Bluetooth Disabled';
      case NetworkState.scanning:           return 'Scanning for peers...';
      case NetworkState.connected:          return 'Mesh Active';
      case NetworkState.error:              return 'Network Error';
    }
  }
}

/// Extension for logging convenience
extension _MessagingLogger on AetherLogger {
  void messaging(String msg, {String? details, LogLevel level = LogLevel.info}) {
    network(msg, details: details, level: level);
  }
}
