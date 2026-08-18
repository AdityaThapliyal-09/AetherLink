package com.aetherlink.aetherlink.network

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.os.Build

class AetherServerConnection(
    private val device: BluetoothDevice,
    private val gattServer: BluetoothGattServer,
    private val rxChar: BluetoothGattCharacteristic
) : AetherConnection {
    private val writeQueue = java.util.concurrent.ConcurrentLinkedQueue<ByteArray>()
    private val isWriting = java.util.concurrent.atomic.AtomicBoolean(false)

    override fun sendData(data: ByteArray): Boolean {
        writeQueue.add(data)
        processNextWrite()
        return true
    }

    @Synchronized
    fun processNextWrite() {
        if (isWriting.get() || writeQueue.isEmpty()) return
        val data = writeQueue.peek() ?: return
        isWriting.set(true)

        val success = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gattServer.notifyCharacteristicChanged(device, rxChar, false, data) == android.bluetooth.BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                rxChar.value = data
                @Suppress("DEPRECATION")
                gattServer.notifyCharacteristicChanged(device, rxChar, false)
            }
        } catch (e: Exception) {
            false
        }

        if (!success) {
            isWriting.set(false)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                processNextWrite()
            }, 50)
        }
    }

    fun onNotificationSent() {
        writeQueue.poll()
        isWriting.set(false)
        processNextWrite()
    }

    override fun disconnect() {
        gattServer.cancelConnection(device)
    }
}