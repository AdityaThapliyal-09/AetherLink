package com.aetherlink.aetherlink.network

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.aetherlink.aetherlink.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * AetherLink BLE Manager — Kotlin native layer.
 *
 * Responsibilities:
 * - BLE peripheral (GATT server) for data reception
 * - BLE central (scanner + GATT client) for discovery and sending
 * - MethodChannel handler (Flutter → Kotlin commands)
 * - EventChannel sinks (Kotlin → Flutter events: peer events, packets)
 *
 * BLE Architecture:
 *   - We advertise our AetherLink service UUID so peers can discover us
 *   - We scan for devices advertising the same UUID
 *   - When connecting, we open a GATT client AND act as GATT server
 *   - Data is transferred via GATT characteristics (write + notify)
 *   - Max MTU negotiated to 512 bytes; larger data chunked by PacketChunker on Dart side
 */
class AetherBleManager(
    private val context: Context,
    messenger: BinaryMessenger
) {
    companion object {
        private const val TAG = "AetherBleManager"

        // Must match BLE constants in Dart (ble_constants.dart)
        private val SERVICE_UUID = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        private val TX_CHAR_UUID = UUID.fromString("6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Write (central→peripheral)
        private val RX_CHAR_UUID = UUID.fromString("6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Notify (peripheral→central)
        private val CLIENT_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

        private const val MAX_MTU = 512
        private const val MANUFACTURER_ID = 0xAE78
        private const val SCAN_PERIOD_MS = 10_000L
        private const val SCAN_REST_MS = 5_000L

        private const val CH_METHOD = "aetherlink/network"
        private const val CH_EVENTS = "aetherlink/events"
        private const val CH_PACKETS = "aetherlink/packets"
    }

    // Flutter channels
    private val methodChannel = MethodChannel(messenger, CH_METHOD)
    private val eventChannel = EventChannel(messenger, CH_EVENTS)
    private val packetChannel = EventChannel(messenger, CH_PACKETS)

    private var eventSink: EventChannel.EventSink? = null
    private var packetSink: EventChannel.EventSink? = null

    // BLE system objects
    private val bluetoothManager: BluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter get() = bluetoothManager.adapter
    private var scanner: BluetoothLeScanner? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    // Connected peers: nodeId → AetherPeerConnection
    private val peers = ConcurrentHashMap<String, AetherConnection>()

    // Device address → nodeId mapping (populated during discovery from advertisement data)
    private val deviceNodeMap = ConcurrentHashMap<String, String>()

    // Our own identity (set by Dart on initialize)
    private var localNodeId: String = ""
    private var localDisplayName: String = ""
    private var localEdPubKey: String = ""
    private var localDhPubKey: String = ""

    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var isScanning = false
    private var isAdvertising = false
    private var scanJob: Job? = null

    init {
        setupMethodChannel()
        setupEventChannels()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Channel Setup
    // ──────────────────────────────────────────────────────────────────────────

    private fun setupMethodChannel() {
        methodChannel.setMethodCallHandler { call, result ->
            mainHandler.post { handleMethodCall(call, result) }
        }
    }

    private fun setupEventChannels() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "EventChannel: listening")
            }
            override fun onCancel(arguments: Any?) { eventSink = null }
        })

        packetChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                packetSink = events
                Log.d(TAG, "PacketChannel: listening")
            }
            override fun onCancel(arguments: Any?) { packetSink = null }
        })
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Method Channel Handlers
    // ──────────────────────────────────────────────────────────────────────────

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize"         -> handleInitialize(call, result)
            "startDiscovery"     -> handleStartDiscovery(result)
            "stopDiscovery"      -> handleStopDiscovery(result)
            "startAdvertising"   -> handleStartAdvertising(result)
            "stopAdvertising"    -> handleStopAdvertising(result)
            "connectToPeer"      -> handleConnectToPeer(call, result)
            "disconnectFromPeer" -> handleDisconnectFromPeer(call, result)
            "sendPacket"         -> handleSendPacket(call, result)
            "getConnectedPeers"  -> handleGetConnectedPeers(result)
            "getNetworkState"    -> handleGetNetworkState(result)
            "checkPermissions"   -> result.success(checkBluetoothPermissions())
            "requestPermissions" -> { result.success(false) } // handled by Flutter side via permission_handler
            "isBluetoothEnabled" -> result.success(bluetoothAdapter.isEnabled)
            "playSosSiren"       -> {
                playSosSiren()
                result.success(true)
            }
            "showMessageNotification" -> {
                val senderName = call.argument<String>("senderName") ?: "AetherLink Node"
                val messageText = call.argument<String>("messageText") ?: ""
                val peerId = call.argument<String>("peerId") ?: ""
                showMessageNotification(senderName, messageText, peerId)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        localNodeId      = call.argument<String>("nodeId") ?: ""
        localDisplayName = call.argument<String>("displayName") ?: "AetherNode"
        localEdPubKey    = call.argument<String>("edPublicKey") ?: ""
        localDhPubKey    = call.argument<String>("dhPublicKey") ?: ""
        Log.i(TAG, "Initialized: nodeId=$localNodeId displayName=$localDisplayName")
        setupGattServer()
        result.success(true)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // GATT Server (peripheral role — receive connections from other nodes)
    // ──────────────────────────────────────────────────────────────────────────

    private fun setupGattServer() {
        if (!hasPermission(Manifest.permission.BLUETOOTH_CONNECT)) return
        if (gattServer != null) return // Already running

        gattServer = bluetoothManager.openGattServer(context, gattServerCallback)

        // Build service
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // TX characteristic (central writes to us)
        val txChar = BluetoothGattCharacteristic(
            TX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        // RX characteristic (we notify centrals)
        val rxChar = BluetoothGattCharacteristic(
            RX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val cccd = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        rxChar.addDescriptor(cccd)

        service.addCharacteristic(txChar)
        service.addCharacteristic(rxChar)
        gattServer?.addService(service)

        Log.i(TAG, "GATT Server started with AetherLink service")
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            val address = device.address
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d(TAG, "GATT Server: device connected $address")
                // Wait for the first packet (HELLO) to identify the nodeId before creating the ServerConnection
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.d(TAG, "GATT Server: device disconnected $address")
                val nodeId = deviceNodeMap[address]
                if (nodeId != null) {
                    peers.remove(nodeId)
                    sendEvent(mapOf("type" to "peerDisconnected", "nodeId" to nodeId))
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }

            if (characteristic.uuid == TX_CHAR_UUID) {
                var actualNodeId = deviceNodeMap[device.address]
                
                // If we don't know the nodeId yet, peek into the JSON to find the originId
                if (actualNodeId == null) {
                    val jsonStr = String(value, Charsets.UTF_8)
                    val matcher = Regex("\"src\":\"([^\"]+)\"").find(jsonStr)
                    actualNodeId = matcher?.groupValues?.get(1)
                    if (actualNodeId != null) {
                        deviceNodeMap[device.address] = actualNodeId
                    }
                }
                
                val nodeId = actualNodeId ?: device.address

                // If this is a newly identified server connection, store it and notify Flutter
                if (actualNodeId != null && !peers.containsKey(actualNodeId)) {
                    val rxChar = gattServer?.getService(SERVICE_UUID)?.getCharacteristic(RX_CHAR_UUID)
                    if (gattServer != null && rxChar != null) {
                        val serverConnection = AetherServerConnection(device, gattServer!!, rxChar)
                        peers[actualNodeId] = serverConnection
                        Log.i(TAG, "GATT Server: established AetherServerConnection for $actualNodeId")
                        mainHandler.post {
                            sendEvent(mapOf(
                                "type" to "peerConnected",
                                "nodeId" to actualNodeId,
                                "deviceAddress" to device.address
                            ))
                        }
                    }
                }

                Log.d(TAG, "Packet received from $nodeId (${value.size} bytes)")
                sendPacketEvent(nodeId, value)
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (descriptor.uuid == CLIENT_CONFIG_UUID) {
                // Client subscribed to notifications
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId,
                        BluetoothGatt.GATT_SUCCESS, 0, null)
                }
                Log.d(TAG, "Client subscribed to notifications: ${device.address}")
            }
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            val nodeId = deviceNodeMap[device.address] ?: return
            val conn = peers[nodeId] as? AetherServerConnection
            conn?.onNotificationSent()
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            Log.d(TAG, "Server MTU changed for ${device.address}: $mtu")
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // BLE Advertising
    // ──────────────────────────────────────────────────────────────────────────

    private fun handleStartAdvertising(result: MethodChannel.Result) {
        if (!hasPermission(Manifest.permission.BLUETOOTH_ADVERTISE)) {
            Log.w(TAG, "handleStartAdvertising: BLUETOOTH_ADVERTISE not granted")
            result.error("PERMISSION_DENIED", "BLUETOOTH_ADVERTISE not granted", null)
            return
        }

        // Ensure the GATT Server is running before we advertise ourselves
        if (gattServer == null) {
            setupGattServer()
        }

        val bleAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
        if (bleAdvertiser == null) {
            Log.w(TAG, "handleStartAdvertising: BLE advertising not supported or Bluetooth off")
            result.error("NOT_SUPPORTED", "BLE advertising not supported", null)
            return
        }
        this.advertiser = bleAdvertiser

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0) // Advertise indefinitely
            .build()

        // 1. Primary advertisement data packet (Max 31 bytes total)
        // 18 bytes for 128-bit Service UUID + 3 bytes flags = 21 bytes <= 31 bytes.
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        // 2. Scan response packet (Max 31 bytes total)
        // Manufacturer data: 4 bytes header (Len + 0xFF + 2-byte ID) + up to 24 bytes payload = 28 bytes <= 31 bytes!
        // DO NOT add addServiceData here to prevent exceeding 31 bytes.
        val nodeIdShort = if (localNodeId.length >= 8) localNodeId.takeLast(8) else localNodeId.padEnd(8, '0')
        val nameClean = localDisplayName.replace("|", "").take(15)
        val payloadStr = "$nodeIdShort|$nameClean"
        val mfrPayload = payloadStr.toByteArray(Charsets.UTF_8).take(24).toByteArray()

        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addManufacturerData(MANUFACTURER_ID, mfrPayload)
            .build()

        try {
            bleAdvertiser.startAdvertising(settings, data, scanResponse, advertiseCallback)
            isAdvertising = true
            Log.i(TAG, "BLE advertising started with payload: $payloadStr")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "startAdvertising threw exception: ${e.message}")
            result.error("ADVERTISE_ERROR", e.message, null)
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.i(TAG, "BLE advertising active (LOW_LATENCY, HIGH_POWER)")
            isAdvertising = true
            sendEvent(mapOf(
                "type" to "networkStateChanged",
                "bluetoothEnabled" to true,
                "isAdvertising" to true,
                "isScanning" to isScanning,
            ))
        }
        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "BLE advertising failed: errorCode=$errorCode")
            isAdvertising = false
            sendEvent(mapOf(
                "type" to "networkStateChanged",
                "bluetoothEnabled" to true,
                "isAdvertising" to false,
                "isScanning" to isScanning,
                "error" to "ADVERTISE_FAILED_$errorCode"
            ))
        }
    }

    private fun handleStopAdvertising(result: MethodChannel.Result) {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (e: Exception) { Log.w(TAG, "stopAdvertising: ${e.message}") }
        isAdvertising = false
        result.success(null)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // BLE Scanning (discovery)
    // ──────────────────────────────────────────────────────────────────────────

    private fun handleStartDiscovery(result: MethodChannel.Result) {
        if (!hasPermission(Manifest.permission.BLUETOOTH_SCAN)) {
            Log.w(TAG, "handleStartDiscovery: BLUETOOTH_SCAN not granted")
            result.error("PERMISSION_DENIED", "BLUETOOTH_SCAN not granted", null)
            return
        }
        val leScanner = bluetoothAdapter.bluetoothLeScanner
        if (leScanner == null) {
            Log.w(TAG, "handleStartDiscovery: Bluetooth not enabled")
            result.error("BLE_DISABLED", "Bluetooth not enabled", null)
            return
        }
        this.scanner = leScanner
        startScan()
        result.success(true)
    }

    private fun startScan() {
        if (!hasPermission(Manifest.permission.BLUETOOTH_SCAN)) return
        val leScanner = scanner ?: bluetoothAdapter.bluetoothLeScanner ?: return
        this.scanner = leScanner

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
            .build()

        val filters = listOf(
            ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build(),
            ScanFilter.Builder().setManufacturerData(MANUFACTURER_ID, byteArrayOf()).build()
        )

        try {
            leScanner.startScan(filters, settings, scanCallback)
            isScanning = true
            Log.i(TAG, "BLE scan started with dual filters (LOW_LATENCY)")
        } catch (e: Exception) {
            Log.w(TAG, "Filtered scan failed (${e.message}), attempting unfiltered scan")
            try {
                leScanner.startScan(null, settings, scanCallback)
                isScanning = true
                Log.i(TAG, "BLE scan started unfiltered")
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to start BLE scan: ${e2.message}")
            }
        }
    }

    private fun stopScan() {
        try {
            scanner?.stopScan(scanCallback)
            isScanning = false
            Log.d(TAG, "BLE scan stopped")
        } catch (e: Exception) { /* ignore */ }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            parseScanResult(result)
        }
        override fun onBatchScanResults(results: List<ScanResult>) {
            results.forEach { parseScanResult(it) }
        }
        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "BLE scan failed: $errorCode")
        }
    }

    private fun parseScanResult(result: ScanResult) {
        val device = result.device
        val address = device.address
        val rssi = result.rssi
        val scanRecord = result.scanRecord ?: return

        // Verify that this device belongs to the AetherLink mesh
        val hasServiceUuid = scanRecord.serviceUuids?.any { it.uuid == SERVICE_UUID } == true
        val mfrData = scanRecord.getManufacturerSpecificData(MANUFACTURER_ID)
        val srvData = scanRecord.getServiceData(ParcelUuid(SERVICE_UUID))

        if (!hasServiceUuid && mfrData == null && srvData == null) {
            return // Not an AetherLink device
        }

        // Parse payload (NodeId|DisplayName)
        val payload = when {
            mfrData != null && mfrData.isNotEmpty() -> String(mfrData, Charsets.UTF_8)
            srvData != null && srvData.isNotEmpty() -> String(srvData, Charsets.UTF_8)
            else -> ""
        }

        val (nodeIdShort, displayName) = if (payload.isNotEmpty()) {
            val parts = payload.split("|")
            val nid = parts.getOrNull(0)?.trim() ?: ""
            val name = parts.getOrNull(1)?.trim() ?: "AetherNode"
            Pair(nid, name)
        } else {
            // Fallback if scan response packet has not yet been merged by the OS
            val fallbackShort = address.replace(":", "").takeLast(8).uppercase()
            Pair(fallbackShort, "AetherNode")
        }

        if (nodeIdShort.isEmpty()) return

        // Never discover ourselves
        if (localNodeId.isNotEmpty() && nodeIdShort.equals(localNodeId.takeLast(8), ignoreCase = true)) {
            return
        }

        val nodeId = "AETH-$nodeIdShort"
        deviceNodeMap[address] = nodeId

        Log.d(TAG, "Discovered peer: $nodeId ($displayName) at $address, RSSI=$rssi")
        sendEvent(mapOf(
            "type" to "peerDiscovered",
            "nodeId" to nodeId,
            "displayName" to displayName,
            "deviceAddress" to address,
            "rssi" to rssi,
        ))
    }

    private fun handleStopDiscovery(result: MethodChannel.Result) {
        scanJob?.cancel()
        stopScan()
        result.success(null)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // GATT Client (central role — connect to discovered peers)
    // ──────────────────────────────────────────────────────────────────────────

    private fun handleConnectToPeer(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("deviceAddress") ?: run {
            result.error("INVALID_ARGS", "deviceAddress required", null); return
        }
        val nodeId = call.argument<String>("nodeId") ?: run {
            result.error("INVALID_ARGS", "nodeId required", null); return
        }

        if (peers.containsKey(nodeId)) {
            result.success(true) // already connected
            return
        }

        if (!hasPermission(Manifest.permission.BLUETOOTH_CONNECT)) {
            result.error("PERMISSION_DENIED", "BLUETOOTH_CONNECT not granted", null)
            return
        }

        val device = bluetoothAdapter.getRemoteDevice(address)
        val connection = AetherPeerConnection(
            nodeId = nodeId,
            device = device,
            gattServer = gattServer,
            onConnected = { id ->
                mainHandler.post {
                    sendEvent(mapOf(
                        "type" to "peerConnected",
                        "nodeId" to id,
                        "deviceAddress" to address,
                    ))
                }
            },
            onDisconnected = { id ->
                peers.remove(id)
                mainHandler.post {
                    sendEvent(mapOf("type" to "peerDisconnected", "nodeId" to id))
                }
            },
            onPacketReceived = { id, bytes ->
                mainHandler.post { sendPacketEvent(id, bytes) }
            },
            onRssiUpdate = { id, rssi ->
                mainHandler.post {
                    sendEvent(mapOf("type" to "rssiUpdated", "nodeId" to id, "rssi" to rssi))
                }
            }
        )

        peers[nodeId] = connection
        deviceNodeMap[address] = nodeId
        connection.connect(context)
        result.success(true)
    }

    private fun handleDisconnectFromPeer(call: MethodCall, result: MethodChannel.Result) {
        val nodeId = call.argument<String>("nodeId") ?: run {
            result.success(null); return
        }
        peers[nodeId]?.disconnect()
        peers.remove(nodeId)
        result.success(null)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Packet Sending
    // ──────────────────────────────────────────────────────────────────────────

    private fun handleSendPacket(call: MethodCall, result: MethodChannel.Result) {
        val nodeId = call.argument<String>("nodeId") ?: run {
            result.error("INVALID_ARGS", "nodeId required", null); return
        }
        val bytes = call.argument<ByteArray>("data") ?: run {
            result.error("INVALID_ARGS", "data required", null); return
        }

        val peer = peers[nodeId]
        if (peer == null) {
            Log.w(TAG, "sendPacket: peer $nodeId not connected")
            result.success(false)
            return
        }

        val success = peer.sendData(bytes)
        result.success(success)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Status Queries
    // ──────────────────────────────────────────────────────────────────────────

    private fun handleGetConnectedPeers(result: MethodChannel.Result) {
        result.success(peers.keys.toList())
    }

    private fun handleGetNetworkState(result: MethodChannel.Result) {
        result.success(mapOf(
            "bluetoothEnabled" to bluetoothAdapter.isEnabled,
            "isAdvertising" to isAdvertising,
            "isScanning" to isScanning,
            "connectedPeerCount" to peers.size,
        ))
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Event Sending (Kotlin → Dart)
    // ──────────────────────────────────────────────────────────────────────────

    private fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post {
            try { eventSink?.success(data) }
            catch (e: Exception) { Log.e(TAG, "sendEvent error: ${e.message}") }
        }
    }

    private fun sendPacketEvent(fromNodeId: String, bytes: ByteArray) {
        mainHandler.post {
            try {
                packetSink?.success(mapOf(
                    "fromNodeId" to fromNodeId,
                    "data" to bytes.map { it.toInt() and 0xFF },
                ))
            } catch (e: Exception) {
                Log.e(TAG, "sendPacketEvent error: ${e.message}")
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Permissions
    // ──────────────────────────────────────────────────────────────────────────

    private fun hasPermission(permission: String): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, permission) ==
                    PackageManager.PERMISSION_GRANTED
        } else {
            if (permission == Manifest.permission.BLUETOOTH_SCAN) {
                ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                        PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        }
    }

    private fun checkBluetoothPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val required = listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
            return required.all {
                ContextCompat.checkSelfPermission(context, it) ==
                        PackageManager.PERMISSION_GRANTED
            }
        }
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Audio Alerts & Notifications
    // ──────────────────────────────────────────────────────────────────────────

    private var activeSirenJob: Job? = null

    private fun playSosSiren(durationSeconds: Int = 3) {
        activeSirenJob?.cancel()
        activeSirenJob = scope.launch(Dispatchers.Default) {
            try {
                // Trigger tactile vibration in sync
                try {
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                    if (vibrator != null && vibrator.hasVibrator()) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val timings = longArrayOf(0, 450, 150, 450, 150, 450, 150, 450)
                            val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255, 0, 255)
                            vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(longArrayOf(0, 450, 150, 450, 150, 450), -1)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Vibration failed: ${e.message}")
                }

                // Synthesize dual-frequency wailing emergency siren
                val sampleRate = 44100
                val totalSamples = sampleRate * durationSeconds
                val buffer = ShortArray(totalSamples)

                var phase = 0.0
                val minFreq = 650.0  // Hz
                val maxFreq = 1400.0 // Hz
                val sweepRate = 2.0  // 2 full cycles per second

                for (i in 0 until totalSamples) {
                    val t = i.toDouble() / sampleRate
                    val lfo = Math.abs((t * sweepRate % 1.0) * 2.0 - 1.0)
                    val currentFreq = minFreq + (maxFreq - minFreq) * lfo
                    phase += 2.0 * Math.PI * currentFreq / sampleRate
                    buffer[i] = (Math.sin(phase) * Short.MAX_VALUE * 0.92).toInt().toShort()
                }

                val minBufSize = AudioTrack.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                )
                val bufferSize = Math.max(minBufSize, totalSamples * 2)

                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val audioFormat = AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()

                val audioTrack = AudioTrack.Builder()
                    .setAudioAttributes(audioAttributes)
                    .setAudioFormat(audioFormat)
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()

                audioTrack.play()
                audioTrack.write(buffer, 0, buffer.size)
                delay((durationSeconds * 1000).toLong())
                try {
                    audioTrack.stop()
                    audioTrack.release()
                } catch (_: Exception) {}
            } catch (e: Exception) {
                Log.e(TAG, "Failed to play emergency SOS siren: ${e.message}")
            }
        }
    }

    private fun showMessageNotification(senderName: String, messageText: String, peerId: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val channelId = "aetherlink_messages"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "AetherLink Messages",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Incoming messages from nearby AetherLink nodes"
                    enableVibration(true)
                    setShowBadge(true)
                }
                nm.createNotificationChannel(channel)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("peerId", peerId)
                putExtra("peerName", senderName)
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                peerId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notif = NotificationCompat.Builder(context, channelId)
                .setContentTitle(senderName)
                .setContentText(messageText)
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            nm.notify(peerId.hashCode(), notif)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show message notification: ${e.message}")
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ──────────────────────────────────────────────────────────────────────────

    fun shutdown() {
        scanJob?.cancel()
        scope.cancel()
        try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: Exception) {}
        try { scanner?.stopScan(scanCallback) } catch (_: Exception) {}
        peers.values.forEach { it.disconnect() }
        peers.clear()
        try { gattServer?.close() } catch (_: Exception) {}
        Log.i(TAG, "AetherBleManager shut down")
    }
}
