// AetherLink utility functions

import 'dart:math';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

final _uuid = Uuid();
final _random = Random.secure();

/// Generates a cryptographically random AetherLink node ID.
/// Format: AETH-XXXXXXXX (8 uppercase hex characters)
String generateNodeId() {
  final bytes = Uint8List(4);
  for (var i = 0; i < 4; i++) {
    bytes[i] = _random.nextInt(256);
  }
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  return '${AppConstants.nodeIdPrefix}$hex';
}

/// Generates a UUIDv4 for message IDs and packet IDs.
String generateMessageId() => _uuid.v4();

/// Generates a random 32-bit sequence number for AODV.
int generateSequenceNumber() => _random.nextInt(0x7FFFFFFF);

/// Returns the short form of a node ID for display (last 4 chars).
/// Example: AETH-A1B2C3D4 → A1B2
String shortNodeId(String nodeId) {
  if (nodeId.length >= 4) {
    return nodeId.substring(nodeId.length - 4).toUpperCase();
  }
  return nodeId;
}

/// Formats a timestamp for display in the chat UI.
String formatMessageTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(dt.year, dt.month, dt.day);
  if (msgDay == today) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (msgDay == yesterday) {
    return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Formats a RSSI value to a human-readable signal strength label.
String formatRssi(int? rssi) {
  if (rssi == null) return 'Unknown';
  if (rssi >= -50) return 'Excellent';
  if (rssi >= -65) return 'Good';
  if (rssi >= -75) return 'Fair';
  return 'Weak';
}

/// Returns a human-readable hop count description.
String formatHopCount(int hops) {
  if (hops == 0) return 'Direct';
  if (hops == 1) return '1 hop';
  return '$hops hops';
}

/// Formats bytes as a hex string for display/debugging.
String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Parses a hex string to bytes.
List<int> hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

/// Returns the current UTC timestamp in milliseconds.
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Returns true if [timestamp] is within [windowMs] of now (replay protection).
bool isTimestampFresh(int timestampMs, {int windowMs = 300000}) {
  final diff = (nowMs() - timestampMs).abs();
  return diff < windowMs;
}

/// Clamps an integer to a valid TTL range.
int clampTtl(int ttl) => ttl.clamp(0, AppConstants.maxTtl);
