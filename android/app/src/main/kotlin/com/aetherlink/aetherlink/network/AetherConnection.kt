package com.aetherlink.aetherlink.network

interface AetherConnection {
    fun sendData(data: ByteArray): Boolean
    fun disconnect()
}
