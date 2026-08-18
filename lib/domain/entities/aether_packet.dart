// AetherLink Protocol Packet definition.
// Every packet transmitted over the BLE GATT connection uses this structure.
// Serialization: compact JSON (minimized field names to reduce BLE payload size).

import 'dart:convert';

/// All packet types in the AetherLink protocol.
enum PacketType {
  /// Initial greeting — exchanges node ID and display name.
  hello,

  /// Extended peer info (public keys, capabilities).
  peerInfo,

  /// Cryptographic key exchange for session key establishment.
  keyExchange,

  /// AODV Route Request — broadcast to discover a route.
  routeRequest,

  /// AODV Route Reply — unicast response when route is found.
  routeReply,

  /// AODV Route Error — notifies route failure.
  routeError,

  /// Encrypted data message to a specific destination.
  data,

  /// Delivery acknowledgement for a DATA packet.
  ack,

  /// Network-wide broadcast message (controlled flooding).
  broadcast,

  /// Emergency SOS broadcast (priority flooding).
  sos,

  /// Keepalive signal to maintain connection state.
  heartbeat,

  /// Chunk of a larger fragmented packet.
  chunk,

  /// Unknown/unsupported packet type.
  unknown,
}

/// Converts packet type to compact wire representation.
extension PacketTypeExtension on PacketType {
  String get wireCode {
    switch (this) {
      case PacketType.hello:        return 'HLO';
      case PacketType.peerInfo:     return 'PIN';
      case PacketType.keyExchange:  return 'KEX';
      case PacketType.routeRequest: return 'RRQ';
      case PacketType.routeReply:   return 'RRP';
      case PacketType.routeError:   return 'RER';
      case PacketType.data:         return 'DAT';
      case PacketType.ack:          return 'ACK';
      case PacketType.broadcast:    return 'BCT';
      case PacketType.sos:          return 'SOS';
      case PacketType.heartbeat:    return 'HBT';
      case PacketType.chunk:        return 'CHK';
      case PacketType.unknown:      return 'UNK';
    }
  }

  static PacketType fromWireCode(String code) {
    switch (code) {
      case 'HLO': return PacketType.hello;
      case 'PIN': return PacketType.peerInfo;
      case 'KEX': return PacketType.keyExchange;
      case 'RRQ': return PacketType.routeRequest;
      case 'RRP': return PacketType.routeReply;
      case 'RER': return PacketType.routeError;
      case 'DAT': return PacketType.data;
      case 'ACK': return PacketType.ack;
      case 'BCT': return PacketType.broadcast;
      case 'SOS': return PacketType.sos;
      case 'HBT': return PacketType.heartbeat;
      case 'CHK': return PacketType.chunk;
      default:    return PacketType.unknown;
    }
  }
}

/// The core AetherLink protocol packet.
/// Designed for compact JSON serialization over BLE GATT.
class AetherPacket {
  /// Protocol version (currently 1).
  final int version;

  /// Packet type (see [PacketType]).
  final PacketType type;

  /// Unique packet ID (UUIDv4) — used for duplicate detection and ACK matching.
  final String packetId;

  /// Node ID of the originating device (source of the message).
  final String originId;

  /// Node ID of the final destination (or '*' for broadcast).
  final String destinationId;

  /// Node ID of the device that sent us this packet (the previous hop).
  final String previousHopId;

  /// Time-to-live: decremented at each relay, dropped when it reaches 0.
  final int ttl;

  /// Number of hops this packet has traversed.
  final int hopCount;

  /// Sequence number (used by AODV for route freshness comparison).
  final int sequenceNumber;

  /// Unix timestamp (milliseconds) of packet creation at origin.
  final int timestamp;

  /// Encrypted or plaintext payload (Base64-encoded for JSON transport).
  /// For DATA packets: encrypted ciphertext.
  /// For HELLO/KEY_EXCHANGE: plaintext JSON sub-payload.
  final String? payload;

  /// Optional routing metadata (e.g., RREQ broadcast ID, RREP route).
  final Map<String, dynamic>? routingMeta;

  const AetherPacket({
    required this.version,
    required this.type,
    required this.packetId,
    required this.originId,
    required this.destinationId,
    required this.previousHopId,
    required this.ttl,
    required this.hopCount,
    required this.sequenceNumber,
    required this.timestamp,
    this.payload,
    this.routingMeta,
  });

  /// Creates a copy of this packet with updated routing fields (relay use).
  AetherPacket relay({
    required String newPreviousHopId,
    int? newTtl,
    int? newHopCount,
  }) {
    return AetherPacket(
      version: version,
      type: type,
      packetId: packetId,
      originId: originId,
      destinationId: destinationId,
      previousHopId: newPreviousHopId,
      ttl: newTtl ?? (ttl - 1),
      hopCount: newHopCount ?? (hopCount + 1),
      sequenceNumber: sequenceNumber,
      timestamp: timestamp,
      payload: payload,
      routingMeta: routingMeta,
    );
  }

  /// Serializes to compact JSON map (short field names for BLE efficiency).
  Map<String, dynamic> toJson() {
    return {
      'v':   version,
      't':   type.wireCode,
      'id':  packetId,
      'src': originId,
      'dst': destinationId,
      'ph':  previousHopId,
      'ttl': ttl,
      'hops': hopCount,
      'seq': sequenceNumber,
      'ts':  timestamp,
      if (payload != null)     'pl': payload,
      if (routingMeta != null) 'rm': routingMeta,
    };
  }

  /// Deserializes from compact JSON map.
  factory AetherPacket.fromJson(Map<String, dynamic> json) {
    return AetherPacket(
      version:       (json['v'] as num?)?.toInt() ?? 1,
      type:          PacketTypeExtension.fromWireCode(json['t'] as String? ?? 'UNK'),
      packetId:      json['id'] as String? ?? '',
      originId:      json['src'] as String? ?? '',
      destinationId: json['dst'] as String? ?? '',
      previousHopId: json['ph'] as String? ?? '',
      ttl:           (json['ttl'] as num?)?.toInt() ?? 0,
      hopCount:      (json['hops'] as num?)?.toInt() ?? 0,
      sequenceNumber:(json['seq'] as num?)?.toInt() ?? 0,
      timestamp:     (json['ts'] as num?)?.toInt() ?? 0,
      payload:       json['pl'] as String?,
      routingMeta:   json['rm'] as Map<String, dynamic>?,
    );
  }

  /// Serializes to raw JSON bytes for BLE transmission.
  List<int> toBytes() {
    return utf8.encode(jsonEncode(toJson()));
  }

  /// Deserializes from raw JSON bytes received over BLE.
  factory AetherPacket.fromBytes(List<int> bytes) {
    final jsonStr = utf8.decode(bytes);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AetherPacket.fromJson(map);
  }

  @override
  String toString() {
    return 'AetherPacket(${type.wireCode}, id=${packetId.substring(0, 8)}, '
        'src=$originId, dst=$destinationId, ttl=$ttl, hops=$hopCount)';
  }
}

/// A chunk packet for fragmenting large payloads across multiple BLE writes.
class ChunkPacket {
  /// The session ID tying all chunks of the same message together.
  final String chunkSessionId;

  /// Total number of chunks in this session.
  final int totalChunks;

  /// Zero-based index of this chunk.
  final int chunkIndex;

  /// Chunk data (Base64-encoded bytes).
  final String data;

  const ChunkPacket({
    required this.chunkSessionId,
    required this.totalChunks,
    required this.chunkIndex,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'cid': chunkSessionId,
    'n':   totalChunks,
    'i':   chunkIndex,
    'd':   data,
  };

  factory ChunkPacket.fromJson(Map<String, dynamic> json) {
    return ChunkPacket(
      chunkSessionId: json['cid'] as String,
      totalChunks:    (json['n'] as num).toInt(),
      chunkIndex:     (json['i'] as num).toInt(),
      data:           json['d'] as String,
    );
  }
}
