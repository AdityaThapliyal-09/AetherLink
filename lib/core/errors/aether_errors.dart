// AetherLink typed error hierarchy.
// Every layer of the app throws typed errors rather than generic exceptions.

abstract class AetherError implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const AetherError(this.message, {this.code, this.cause});

  @override
  String toString() => 'AetherError[$code]: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

// --- Bluetooth / BLE errors ---

class BleError extends AetherError {
  const BleError(super.message, {super.code, super.cause});
}

class BleNotAvailableError extends BleError {
  const BleNotAvailableError() : super('Bluetooth is not available on this device', code: 'BLE_UNAVAILABLE');
}

class BleDisabledError extends BleError {
  const BleDisabledError() : super('Bluetooth is disabled. Enable Bluetooth to discover nearby AetherLink nodes.', code: 'BLE_DISABLED');
}

class BlePermissionError extends BleError {
  const BlePermissionError(String permission) : super('Bluetooth permission denied: $permission. Nearby-device permission is required for AetherLink networking.', code: 'BLE_PERMISSION_DENIED');
}

class BleConnectionError extends BleError {
  const BleConnectionError(String peerId) : super('Unable to establish a connection to $peerId. Retrying...', code: 'BLE_CONNECTION_FAILED');
}

class BleConnectionTimeoutError extends BleError {
  const BleConnectionTimeoutError(String peerId) : super('Connection timeout to peer $peerId', code: 'BLE_TIMEOUT');
}

// --- Routing errors ---

class RoutingError extends AetherError {
  const RoutingError(super.message, {super.code, super.cause});
}

class NoRouteError extends RoutingError {
  const NoRouteError(String destinationId)
      : super(
          'No route to $destinationId. The message has been saved and will retry when a route becomes available.',
          code: 'NO_ROUTE',
        );
}

class RouteExpiredError extends RoutingError {
  const RouteExpiredError(String destinationId)
      : super('Route to $destinationId has expired', code: 'ROUTE_EXPIRED');
}

class RoutingLoopError extends RoutingError {
  const RoutingLoopError(String packetId)
      : super('Routing loop detected for packet $packetId', code: 'ROUTING_LOOP');
}

// --- Encryption errors ---

class CryptoError extends AetherError {
  const CryptoError(super.message, {super.code, super.cause});
}

class KeyGenerationError extends CryptoError {
  const KeyGenerationError({dynamic cause}) : super('Failed to generate cryptographic keys', code: 'KEY_GEN_FAILED', cause: cause);
}

class EncryptionError extends CryptoError {
  const EncryptionError({dynamic cause}) : super('Message encryption failed', code: 'ENCRYPT_FAILED', cause: cause);
}

class DecryptionError extends CryptoError {
  const DecryptionError({dynamic cause}) : super('Message decryption failed — authentication tag mismatch', code: 'DECRYPT_FAILED', cause: cause);
}

class NoSessionKeyError extends CryptoError {
  const NoSessionKeyError(String peerId)
      : super('No session key established with $peerId. Key exchange required.', code: 'NO_SESSION_KEY');
}

// --- Messaging errors ---

class MessagingError extends AetherError {
  const MessagingError(super.message, {super.code, super.cause});
}

class MessageTooLargeError extends MessagingError {
  const MessageTooLargeError(int length, int max)
      : super('Message length $length exceeds maximum $max characters', code: 'MSG_TOO_LARGE');
}

class MessageDeliveryError extends MessagingError {
  const MessageDeliveryError(String msgId)
      : super('Message $msgId could not be delivered after maximum retries', code: 'DELIVERY_FAILED');
}

// --- Database errors ---

class DatabaseError extends AetherError {
  const DatabaseError(super.message, {super.code, super.cause});
}

class DatabaseOpenError extends DatabaseError {
  const DatabaseOpenError({dynamic cause}) : super('Failed to open AetherLink database', code: 'DB_OPEN_FAILED', cause: cause);
}

// --- Protocol errors ---

class ProtocolError extends AetherError {
  const ProtocolError(super.message, {super.code, super.cause});
}

class MalformedPacketError extends ProtocolError {
  const MalformedPacketError({dynamic cause}) : super('Received malformed packet — dropping', code: 'MALFORMED_PACKET', cause: cause);
}

class TtlExpiredError extends ProtocolError {
  const TtlExpiredError(String packetId)
      : super('TTL expired for packet $packetId — dropping', code: 'TTL_EXPIRED');
}

class DuplicatePacketError extends ProtocolError {
  const DuplicatePacketError(String packetId)
      : super('Duplicate packet $packetId — dropping', code: 'DUPLICATE_PACKET');
}
