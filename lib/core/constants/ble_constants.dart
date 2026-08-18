// AetherLink BLE/Bluetooth UUIDs
// Custom UUIDs that uniquely identify AetherLink devices and characteristics.
// These UUIDs are used for BLE advertising and GATT service definition.

class BleConstants {
  BleConstants._();

  // Primary AetherLink BLE service UUID
  // Any device advertising this service UUID is an AetherLink node.
  static const String serviceUuid = 'a3th0001-1ink-b1e4-ae7h-er1ink202600';

  // Characteristic for writing packets TO this device (remote writes here)
  static const String packetWriteCharUuid = 'a3th0002-1ink-b1e4-ae7h-er1ink202600';

  // Characteristic for notifications FROM this device (remote subscribes)
  static const String packetNotifyCharUuid = 'a3th0003-1ink-b1e4-ae7h-er1ink202600';

  // Characteristic for device info (node ID, display name, protocol version)
  static const String deviceInfoCharUuid = 'a3th0004-1ink-b1e4-ae7h-er1ink202600';

  // Advertisement manufacturer ID (custom, not registered)
  static const int manufacturerId = 0xAE78; // 0xAE78 as uint16 approximation

  // Service name for human-readable identification
  static const String serviceLocalName = 'AetherLink';

  // BLE connection priority (for Android)
  static const int connectionPriorityBalanced = 0;
  static const int connectionPriorityHigh = 1;
  static const int connectionPriorityLowPower = 2;
}
