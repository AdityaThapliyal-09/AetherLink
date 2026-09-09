package com.aetherlink.aetherlink.network

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

class AetherServerConnection(
    private val device: BluetoothDevice,
    private val gattServer: BluetoothGattServer,
    private val rxChar: BluetoothGattCharacteristic
) : AetherConnection {
    companion object {
        private const val TAG = "AetherServerConn"
        private const val WATCHDOG_TIMEOUT_MS = 3000L
    }

    private val writeQueue = java.util.concurrent.ConcurrentLinkedQueue<ByteArray>()
    private val isWriting = java.util.concurrent.atomic.AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val watchdogRunnable = Runnable {
        if (isWriting.get()) {
            Log.w(TAG, "Notification watchdog timeout on ${device.address} - advancing queue")
            writeQueue.poll()
            isWriting.set(false)
            processNextWrite()
        }
    }

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

        if (success) {
            mainHandler.removeCallbacks(watchdogRunnable)
            mainHandler.postDelayed(watchdogRunnable, WATCHDOG_TIMEOUT_MS)
        } else {
            isWriting.set(false)
            mainHandler.removeCallbacks(watchdogRunnable)
            mainHandler.postDelayed({
                processNextWrite()
            }, 50)
        }
    }

    fun onNotificationSent() {
        mainHandler.removeCallbacks(watchdogRunnable)
        writeQueue.poll()
        isWriting.set(false)
        processNextWrite()
    }

    override fun disconnect() {
        mainHandler.removeCallbacks(watchdogRunnable)
        gattServer.cancelConnection(device)
    }
}