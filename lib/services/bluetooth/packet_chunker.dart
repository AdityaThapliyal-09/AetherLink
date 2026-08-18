// AetherLink Packet Chunker.
// Splits large BLE payloads into chunks and reassembles them on the receiving end.
// Needed because BLE GATT has MTU constraints (max ~512 bytes after negotiation).

import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/utils/utils.dart';

/// A reassembly buffer for chunks belonging to the same session.
class ChunkBuffer {
  final String sessionId;
  final int totalChunks;
  final Map<int, List<int>> chunks = {};
  final DateTime createdAt = DateTime.now();

  ChunkBuffer({required this.sessionId, required this.totalChunks});

  bool get isComplete => chunks.length == totalChunks;

  bool get isExpired =>
      DateTime.now().difference(createdAt).inSeconds > 30;

  List<int> assemble() {
    final all = <int>[];
    for (var i = 0; i < totalChunks; i++) {
      all.addAll(chunks[i] ?? []);
    }
    return all;
  }
}

class PacketChunker {
  static const int _chunkSize = AppConstants.bleChunkPayloadSize;

  // Marker prefix to identify chunk packets (4 bytes: 0xCH NK)
  static const List<int> _chunkMagic = [0xC4, 0x48, 0x4E, 0x4B];

  /// Returns true if [bytes] starts with the chunk magic bytes.
  bool isChunkData(List<int> bytes) {
    if (bytes.length < 4) return false;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _chunkMagic[i]) return false;
    }
    return true;
  }

  /// Splits [data] into chunk packets, each prefixed with chunk metadata.
  /// Returns list of raw byte arrays ready for BLE transmission.
  List<List<int>> chunk(List<int> data) {
    final sessionId = generateMessageId().replaceAll('-', '').substring(0, 16);
    final encoded = base64.encode(data);
    final totalChunks = (encoded.length / _chunkSize).ceil();
    final result = <List<int>>[];

    for (var i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize).clamp(0, encoded.length);
      final chunkData = encoded.substring(start, end);

      final chunkJson = jsonEncode({
        'cid': sessionId,
        'n': totalChunks,
        'i': i,
        'd': chunkData,
      });
      final chunkBytes = utf8.encode(chunkJson);

      // Prepend magic bytes
      final payload = [..._chunkMagic, ...chunkBytes];
      result.add(payload);
    }

    return result;
  }

  /// Processes incoming chunk bytes. Returns assembled data when all chunks
  /// of a session have been received, or null if still waiting.
  List<int>? addChunk(List<int> bytes, Map<String, ChunkBuffer> buffers) {
    // Strip magic prefix
    final jsonBytes = bytes.sublist(4);
    final json = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;

    final sessionId = json['cid'] as String;
    final totalChunks = (json['n'] as num).toInt();
    final chunkIndex = (json['i'] as num).toInt();
    final chunkData = json['d'] as String;

    final buffer = buffers.putIfAbsent(
      sessionId,
      () => ChunkBuffer(sessionId: sessionId, totalChunks: totalChunks),
    );

    buffer.chunks[chunkIndex] = utf8.encode(chunkData);

    // Clean expired buffers
    buffers.removeWhere((_, b) => b.isExpired);

    if (buffer.isComplete) {
      buffers.remove(sessionId);
      final assembled = buffer.assemble();
      // Decode from base64 (chunked as base64 of original bytes)
      return base64.decode(utf8.decode(assembled));
    }

    return null;
  }
}
