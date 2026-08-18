package com.aetherlink.aetherlink

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.aetherlink.aetherlink.network.AetherBleManager

class MainActivity : FlutterActivity() {
    private lateinit var bleManager: AetherBleManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bleManager = AetherBleManager(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        bleManager.shutdown()
        super.onDestroy()
    }
}
