// AetherLink BLE Service — Dart-side bridge to Kotlin native BLE layer.
// Communicates with the Kotlin layer via MethodChannel (commands) and
// EventChannel (continuous events like peer discovery, packet receipt).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/errors/aether_errors.dart';
import '../../core/logging/logger.dart';

/// Events received from the Kotlin native layer.
sealed class BleEvent {}

class PeerDiscoveredEvent extends BleEvent {
  final String nodeId;
  final String displayName;
  final String deviceAddress;
  final int rssi;
  PeerDiscoveredEvent({required this.nodeId, required this.displayName,
      required this.deviceAddress, required this.rssi});
}

class PeerConnectedEvent extends BleEvent {
  final String nodeId;
  final String deviceAddress;
  PeerConnectedEvent({required this.nodeId, required this.deviceAddress});
}

class PeerDisconnectedEvent extends BleEvent {
  final String nodeId;
  PeerDisconnectedEvent({required this.nodeId});
}

class PacketReceivedEvent extends BleEvent {
  final String fromNodeId;
  final List<int> rawBytes;
  PacketReceivedEvent({required this.fromNodeId, required this.rawBytes});
}

class NetworkStateChangedEvent extends BleEvent {
  final bool bluetoothEnabled;
  final bool isAdvertising;
  final bool isScanning;
  NetworkStateChangedEvent({required this.bluetoothEnabled,
      required this.isAdvertising, required this.isScanning});
}

class BleRssiUpdatedEvent extends BleEvent {
  final String nodeId;
  final int rssi;
  BleRssiUpdatedEvent({required this.nodeId, required this.rssi});
}

/// Dart-side interface to the Kotlin BLE layer.
/// Wraps MethodChannel commands and EventChannel streams.
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  static const _methodChannel = MethodChannel('aetherlink/network');
  static const _eventChannel = EventChannel('aetherlink/events');
  static const _packetChannel = EventChannel('aetherlink/packets');

  StreamController<BleEvent>? _eventController;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _packetSubscription;

  Stream<BleEvent>? _eventStream;

  /// Initialize the BLE service and start listening to native events.
  Future<void> initialize(String nodeId, String displayName,
      String edPublicKey, String dhPublicKey) async {
    _eventController = StreamController<BleEvent>.broadcast();
    _eventStream = _eventController!.stream;

    // Subscribe to peer discovery / connection events
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) => _handleNativeEvent(event),
      onError: (e) => logger.bluetooth('EventChannel error: $e', level: LogLevel.error),
    );

    // Subscribe to incoming packet events
    _packetSubscription = _packetChannel.receiveBroadcastStream().listen(
      (event) => _handlePacketEvent(event),
      onError: (e) => logger.bluetooth('PacketChannel error: $e', level: LogLevel.error),
    );

    // Initialize the native layer with our identity
    try {
      await _methodChannel.invokeMethod('initialize', {
        'nodeId': nodeId,
        'displayName': displayName,
        'edPublicKey': edPublicKey,
        'dhPublicKey': dhPublicKey,
      });
      logger.bluetooth('BLE service initialized for node $nodeId');
    } catch (e) {
      logger.bluetooth('Failed to initialize BLE service: $e', level: LogLevel.error);
    }
  }

  Stream<BleEvent> get events => _eventStream ?? const Stream.empty();

  // ---------------------------------------------------------------------------
  // Commands → Kotlin
  // ---------------------------------------------------------------------------

  Future<bool> startDiscovery() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startDiscovery');
      logger.bluetooth('BLE discovery started: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      logger.bluetooth('startDiscovery failed: ${e.message}', level: LogLevel.error);
      if (e.code == 'BLE_DISABLED') throw const BleDisabledError();
      if (e.code == 'PERMISSION_DENIED') throw const BlePermissionError('BLUETOOTH_SCAN');
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _methodChannel.invokeMethod('stopDiscovery');
      logger.bluetooth('BLE discovery stopped');
    } catch (e) {
      logger.bluetooth('stopDiscovery error: $e', level: LogLevel.warning);
    }
  }

  Future<bool> startAdvertising() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startAdvertising');
      logger.bluetooth('BLE advertising started: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      logger.bluetooth('startAdvertising failed: ${e.message}', level: LogLevel.error);
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _methodChannel.invokeMethod('stopAdvertising');
      logger.bluetooth('BLE advertising stopped');
    } catch (e) {
      logger.bluetooth('stopAdvertising error: $e', level: LogLevel.warning);
    }
  }

  Future<bool> connectToPeer(String deviceAddress, String nodeId) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('connectToPeer', {
        'deviceAddress': deviceAddress,
        'nodeId': nodeId,
      });
      logger.bluetooth('Connect to peer $nodeId ($deviceAddress): $result');
      return result ?? false;
    } on PlatformException catch (e) {
      logger.bluetooth('connectToPeer failed: ${e.message}', level: LogLevel.error);
      throw BleConnectionError(nodeId);
    }
  }

  Future<void> disconnectFromPeer(String nodeId) async {
    try {
      await _methodChannel.invokeMethod('disconnectFromPeer', {'nodeId': nodeId});
      logger.bluetooth('Disconnected from peer $nodeId');
    } catch (e) {
      logger.bluetooth('disconnectFromPeer error: $e', level: LogLevel.warning);
    }
  }

  /// Sends raw bytes to a connected peer via GATT write.
  Future<bool> sendPacket(String nodeId, List<int> bytes) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('sendPacket', {
        'nodeId': nodeId,
        'data': bytes,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      logger.bluetooth('sendPacket to $nodeId failed: ${e.message}', level: LogLevel.error);
      return false;
    }
  }

  Future<List<String>> getConnectedPeers() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getConnectedPeers');
      return (result ?? []).cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getNetworkState() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getNetworkState');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {};
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Triggers a loud 2.5-3 second emergency SOS siren tone on the device.
  Future<void> playSosSiren() async {
    try {
      await _methodChannel.invokeMethod('playSosSiren');
      logger.sos('Emergency SOS siren triggered');
    } catch (e) {
      logger.sos('Failed to trigger emergency SOS siren: $e', level: LogLevel.warning);
    }
  }

  /// Shows a system heads-up notification for an incoming peer message.
  Future<void> showMessageNotification({
    required String senderName,
    required String messageText,
    required String peerId,
  }) async {
    try {
      await _methodChannel.invokeMethod('showMessageNotification', {
        'senderName': senderName,
        'messageText': messageText,
        'peerId': peerId,
      });
    } catch (e) {
      logger.network('Failed to dispatch system notification: $e', level: LogLevel.warning);
    }
  }

  // ---------------------------------------------------------------------------
  // Event Handling
  // ---------------------------------------------------------------------------

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    final type = map['type'] as String?;

    switch (type) {
      case 'peerDiscovered':
        _eventController?.add(PeerDiscoveredEvent(
          nodeId: map['nodeId'] as String? ?? '',
          displayName: map['displayName'] as String? ?? 'Unknown',
          deviceAddress: map['deviceAddress'] as String? ?? '',
          rssi: (map['rssi'] as num?)?.toInt() ?? -100,
        ));
        logger.bluetooth('Peer discovered: ${map['nodeId']} RSSI=${map['rssi']}');

      case 'peerConnected':
        _eventController?.add(PeerConnectedEvent(
          nodeId: map['nodeId'] as String? ?? '',
          deviceAddress: map['deviceAddress'] as String? ?? '',
        ));
        logger.bluetooth('Peer connected: ${map['nodeId']}');

      case 'peerDisconnected':
        _eventController?.add(PeerDisconnectedEvent(
          nodeId: map['nodeId'] as String? ?? '',
        ));
        logger.bluetooth('Peer disconnected: ${map['nodeId']}');

      case 'networkStateChanged':
        _eventController?.add(NetworkStateChangedEvent(
          bluetoothEnabled: map['bluetoothEnabled'] as bool? ?? false,
          isAdvertising: map['isAdvertising'] as bool? ?? false,
          isScanning: map['isScanning'] as bool? ?? false,
        ));

      case 'rssiUpdated':
        _eventController?.add(BleRssiUpdatedEvent(
          nodeId: map['nodeId'] as String? ?? '',
          rssi: (map['rssi'] as num?)?.toInt() ?? -100,
        ));

      default:
        logger.bluetooth('Unknown native event type: $type', level: LogLevel.warning);
    }
  }

  void _handlePacketEvent(dynamic event) {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    final fromNodeId = map['fromNodeId'] as String? ?? '';
    final rawData = map['data'];

    List<int> bytes;
    if (rawData is List) {
      bytes = rawData.cast<int>();
    } else if (rawData is String) {
      bytes = base64.decode(rawData);
    } else {
      logger.bluetooth('Unrecognised packet data format', level: LogLevel.warning);
      return;
    }

    _eventController?.add(PacketReceivedEvent(
      fromNodeId: fromNodeId,
      rawBytes: bytes,
    ));
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _packetSubscription?.cancel();
    await _eventController?.close();
  }
}
