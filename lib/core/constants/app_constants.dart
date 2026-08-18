// AetherLink Application Constants
// Core identifiers and configuration values for the AetherLink protocol

class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'AetherLink';
  static const String appVersion = '1.0.0';
  static const String appSubtitle = 'Decentralized Disaster Communication';

  // Protocol versioning
  static const int protocolVersion = 1;
  static const String protocolVersionString = 'AETH-v1';

  // Node ID format: AETH-XXXXXXXX (8 uppercase hex chars)
  static const String nodeIdPrefix = 'AETH-';
  static const int nodeIdHexLength = 8;

  // Routing defaults
  static const int defaultTtl = 10;
  static const int maxTtl = 20;
  static const int maxHopCount = 15;
  static const int routeExpirySeconds = 300; // 5 minutes
  static const int heartbeatIntervalSeconds = 30;
  static const int staleConnectionTimeoutSeconds = 90;

  // Messaging
  static const int maxMessageLength = 10000;
  static const int messageRetryMax = 5;
  static const int messageRetryBaseDelayMs = 2000;
  static const int ackTimeoutMs = 15000;
  static const int storeForwardCheckIntervalSeconds = 10;

  // Seen-message cache
  static const int seenCacheMaxSize = 1000;
  static const int seenCacheExpiryMinutes = 60;

  // BLE
  static const int bleScanWindowMs = 5000;
  static const int bleScanRestMs = 10000; // Throttled scan interval
  static const int bleConnectionTimeoutMs = 10000;
  static const int bleMtuSize = 512;
  static const int bleChunkPayloadSize = 480; // ~480 bytes per chunk (MTU 512 - overhead)

  // SOS
  static const int sosTtl = 15; // Higher TTL for SOS
  static const int sosHoldDurationMs = 2000; // Press-and-hold 2 seconds

  // Database
  static const String dbName = 'aetherlink.db';
  static const int dbVersion = 1;
}
