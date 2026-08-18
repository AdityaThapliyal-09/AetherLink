// AetherLink Provider — application state management using Provider.
// Wraps NetworkManager and exposes reactive state for UI.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/database/aether_database.dart';
import '../../data/database/daos.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/peer_node.dart';
import '../../domain/entities/route_entry.dart';
import '../../services/bluetooth/network_manager.dart';
import '../../services/encryption/identity_service.dart';
import '../../domain/entities/local_identity.dart';

class AetherProvider extends ChangeNotifier {
  final _nm = NetworkManager();
  final _db = AetherDatabase();

  late IdentityDao _identityDao;
  late PeersDao _peersDao;
  late MessagesDao _messagesDao;
  late ConversationsDao _conversationsDao;
  late RoutingTableDao _routingDao;
  late SeenMessagesDao _seenDao;
  late BroadcastDao _broadcastDao;

  // State
  List<PeerNode> _peers = [];
  List<Conversation> _conversations = [];
  List<NetworkAlert> _alerts = [];
  NetworkState _networkState = NetworkState.idle;
  LocalIdentity? _identity;
  bool _initialized = false;
  bool _initializing = false;

  // Stats
  int _pendingMessages = 0;

  // Subscriptions
  StreamSubscription? _peerSub;
  StreamSubscription? _msgSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _stateSub;

  // Getters
  List<PeerNode> get peers => _peers;
  List<PeerNode> get activePeers => _peers.where((p) => p.connectionState != PeerConnectionState.disconnected).toList();
  List<PeerNode> get readyPeers => _peers.where((p) => p.connectionState == PeerConnectionState.ready).toList();
  List<Conversation> get conversations => _conversations;
  List<NetworkAlert> get alerts => _alerts;
  NetworkState get networkState => _networkState;
  LocalIdentity? get identity => _identity;
  bool get initialized => _initialized;
  NetworkManager get networkManager => _nm;
  int get pendingMessages => _pendingMessages;
  RoutingTableDao get routingDao => _routingDao;
  MessagesDao get messagesDao => _messagesDao;
  BroadcastDao get broadcastDao => _broadcastDao;

  /// Initialize all services and start networking.
  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    // Set up DAOs
    _identityDao = IdentityDao(_db);
    _peersDao = PeersDao(_db);
    _messagesDao = MessagesDao(_db);
    _conversationsDao = ConversationsDao(_db);
    _routingDao = RoutingTableDao(_db);
    _seenDao = SeenMessagesDao(_db);
    _broadcastDao = BroadcastDao(_db);

    // Initialize networking
    await _nm.initialize(
      identityDao: _identityDao,
      peersDao: _peersDao,
      messagesDao: _messagesDao,
      conversationsDao: _conversationsDao,
      routingDao: _routingDao,
      seenDao: _seenDao,
      broadcastDao: _broadcastDao,
    );

    _identity = _nm.localIdentity;

    // Load initial data
    _conversations = await _conversationsDao.getAllConversations();
    _alerts = await _broadcastDao.getRecentAlerts();

    // Subscribe to live updates
    _peerSub = _nm.peerUpdates.listen((peers) {
      _peers = peers;
      notifyListeners();
    });

    _msgSub = _nm.messageUpdates.listen((msg) {
      _refreshConversations();
      notifyListeners();
    });

    _alertSub = _nm.alertUpdates.listen((alert) {
      _alerts = [alert, ..._alerts.take(49)];
      notifyListeners();
    });

    _stateSub = _nm.networkStateUpdates.listen((state) {
      _networkState = state;
      notifyListeners();
    });

    _networkState = _nm.networkState;
    _initialized = true;
    _initializing = false;
    notifyListeners();
  }

  Future<void> _refreshConversations() async {
    _conversations = await _conversationsDao.getAllConversations();
    final pending = await _messagesDao.getPendingOutbound();
    _pendingMessages = pending.length;
    notifyListeners();
  }

  Future<void> sendMessage(String peerId, String text) async {
    await _nm.sendMessage(peerId, text);
    await _refreshConversations();
  }

  Future<void> sendBroadcast(String text) async {
    await _nm.sendBroadcast(text);
  }

  Future<void> sendSos(String message) async {
    await _nm.sendSos(message);
  }

  Future<void> updateDisplayName(String name) async {
    await IdentityService().updateDisplayName(name);
    _identity = _identity?.copyWith(displayName: name);
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    await _nm.requestPermissions();
  }

  List<RouteEntry> getRoutingTable() {
    return _nm.aodvManager.getAllRoutes();
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _msgSub?.cancel();
    _alertSub?.cancel();
    _stateSub?.cancel();
    _nm.dispose();
    super.dispose();
  }
}
