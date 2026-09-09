package com.aetherlink.aetherlink.network

import android.bluetooth.*
import android.content.Context
import android.os.Build
import android.util.Log
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manages a single GATT connection to a remote AetherLink peer.
 * Handles:
 * - GATT client connection and MTU negotiation
 * - Service/characteristic discovery
 * - Reliable write to TX characteristic on remote GATT server
 * - Subscription to RX notifications from remote GATT server
 * - RSSI periodic reading
 */
class AetherPeerConnection(
    val nodeId: String,
    private val device: BluetoothDevice,
    private val gattServer: BluetoothGattServer?,
    private val onConnected: (String) -> Unit,
    private val onDisconnected: (String) -> Unit,
    private val onPacketReceived: (String, ByteArray) -> Unit,
    private val onRssiUpdate: (String, Int) -> Unit
) : AetherConnection {
    companion object {
        private const val TAG = "AetherPeerConnection"
        private val SERVICE_UUID = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        private val TX_CHAR_UUID = UUID.fromString("6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        private val RX_CHAR_UUID = UUID.fromString("6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
        private val CLIENT_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
        private const val TARGET_MTU = 512
        private const val WATCHDOG_TIMEOUT_MS = 3000L
    }

    private var gatt: BluetoothGatt? = null
    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null
    private val connected = AtomicBoolean(false)

    // Write queue for ordered delivery
    private val writeQueue = ArrayDeque<ByteArray>()
    private var isWriting = false
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val watchdogRunnable = Runnable {
        synchronized(writeQueue) {
            if (isWriting) {
                Log.w(TAG, "Write watchdog timeout on $nodeId - advancing queue")
                writeQueue.removeFirstOrNull()
                isWriting = false
                processNextWrite()
            }
        }
    }

    fun connect(context: Context) {
        Log.d(TAG, "Connecting to $nodeId (${device.address})")
        @Suppress("DEPRECATION")
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
    }

    override fun disconnect() {
        mainHandler.removeCallbacks(watchdogRunnable)
        connected.set(false)
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        Log.d(TAG, "Disconnected from $nodeId")
    }

    /**
     * Sends [data] to the connected peer by writing to their TX characteristic.
     * Returns true if queued successfully.
     */
    override fun sendData(data: ByteArray): Boolean {
        if (!connected.get()) {
            Log.w(TAG, "sendData: not connected to $nodeId")
            return false
        }
        synchronized(writeQueue) {
            writeQueue.addLast(data)
            if (!isWriting) processNextWrite()
        }
        return true
    }

    private fun processNextWrite() {
        synchronized(writeQueue) {
            val data = writeQueue.firstOrNull() ?: run {
                isWriting = false
                return
            }
            isWriting = true
            val char = txCharacteristic ?: run {
                Log.w(TAG, "TX characteristic not found")
                writeQueue.removeFirstOrNull()
                isWriting = false
                return
            }

            val success = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    gatt?.writeCharacteristic(char, data,
                        BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) == android.bluetooth.BluetoothStatusCodes.SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    char.value = data
                    @Suppress("DEPRECATION")
                    char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    @Suppress("DEPRECATION")
                    gatt?.writeCharacteristic(char) == true
                }
            } catch (e: Exception) {
                false
            }

            if (success) {
                mainHandler.removeCallbacks(watchdogRunnable)
                mainHandler.postDelayed(watchdogRunnable, WATCHDOG_TIMEOUT_MS)
            } else {
                mainHandler.removeCallbacks(watchdogRunnable)
                isWriting = false
                // Retry after a short delay
                mainHandler.postDelayed({
                    processNextWrite()
                }, 50)
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d(TAG, "Connected to $nodeId — requesting MTU $TARGET_MTU")
                gatt.requestMtu(TARGET_MTU)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.d(TAG, "Disconnected from $nodeId (status=$status)")
                connected.set(false)
                onDisconnected(nodeId)
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            Log.d(TAG, "MTU negotiated: $mtu for $nodeId")
            // Proceed to discover services
            gatt.discoverServices()
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.e(TAG, "Service discovery failed: $status")
                return
            }

            val service = gatt.getService(SERVICE_UUID) ?: run {
                Log.e(TAG, "AetherLink service not found on $nodeId")
                return
            }

            txCharacteristic = service.getCharacteristic(TX_CHAR_UUID)
            rxCharacteristic = service.getCharacteristic(RX_CHAR_UUID)

            rxCharacteristic?.let { rxChar ->
                gatt.setCharacteristicNotification(rxChar, true)
                val descriptor = rxChar.getDescriptor(CLIENT_CONFIG_UUID)
                if (descriptor != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        gatt.writeDescriptor(descriptor,
                            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                    } else {
                        @Suppress("DEPRECATION")
                        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        gatt.writeDescriptor(descriptor)
                    }
                } else {
                    Log.w(TAG, "Client Config descriptor not found! Proceeding anyway.")
                    connected.set(true)
                    onConnected(nodeId)
                    startRssiPolling(gatt)
                }
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            if (descriptor.uuid == CLIENT_CONFIG_UUID) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "Descriptor write successful, Peer $nodeId ready")
                    connected.set(true)
                    onConnected(nodeId)
                    startRssiPolling(gatt)
                } else {
                    Log.e(TAG, "Failed to write descriptor for $nodeId, status=$status")
                    disconnect()
                }
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            // API 33+ preferred callback
            if (characteristic.uuid == RX_CHAR_UUID) {
                Log.d(TAG, "Notification from $nodeId: ${value.size} bytes")
                onPacketReceived(nodeId, value)
            }
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            @Suppress("DEPRECATION")
            if (characteristic.uuid == RX_CHAR_UUID) {
                val value = characteristic.value ?: return
                Log.d(TAG, "Notification (legacy) from $nodeId: ${value.size} bytes")
                onPacketReceived(nodeId, value)
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            mainHandler.removeCallbacks(watchdogRunnable)
            synchronized(writeQueue) {
                writeQueue.removeFirstOrNull() // Remove the sent item
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    Log.w(TAG, "Write failed to $nodeId: status=$status")
                }
                // Process next in queue
                if (writeQueue.isNotEmpty()) {
                    processNextWrite()
                } else {
                    isWriting = false
                }
            }
        }

        override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                onRssiUpdate(nodeId, rssi)
            }
        }
    }

    private fun startRssiPolling(gatt: BluetoothGatt) {
        // Poll RSSI every 10 seconds for signal strength updates
        Thread {
            while (connected.get()) {
                Thread.sleep(10_000)
                if (connected.get()) {
                    gatt.readRemoteRssi()
                }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }
}
