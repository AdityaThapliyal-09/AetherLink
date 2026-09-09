// AetherLink BLE/Bluetooth UUIDs
// Custom UUIDs that uniquely identify AetherLink devices and characteristics.
// These UUIDs are used for BLE advertising and GATT service definition.

class BleConstants {
  BleConstants._();

  // Primary AetherLink BLE service UUID (Nordic UART Service)
  // Any device advertising this service UUID is an AetherLink node.
  static const String serviceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  // Characteristic for writing packets TO this device (remote writes here - TX on Central)
  static const String packetWriteCharUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  // Characteristic for notifications FROM this device (remote subscribes - RX on Central)
  static const String packetNotifyCharUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  // Standard BLE Client Characteristic Configuration Descriptor UUID
  static const String clientConfigDescriptorUuid = '00002902-0000-1000-8000-00805F9B34FB';

  // Characteristic for device info (optional fallback)
  static const String deviceInfoCharUuid = '6E400004-B5A3-F393-E0A9-E50E24DCCA9E';

  // Advertisement manufacturer ID (custom, not registered)
  static const int manufacturerId = 0xAE78; // 0xAE78 as uint16 approximation

  // Service name for human-readable identification
  static const String serviceLocalName = 'AetherLink';

  // BLE connection priority (for Android)
  static const int connectionPriorityBalanced = 0;
  static const int connectionPriorityHigh = 1;
  static const int connectionPriorityLowPower = 2;
}
