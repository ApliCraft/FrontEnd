package com.aplicraft.decideat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aplicraft.decideat/timezone"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getTimeZone") {
                val timeZoneId = TimeZone.getDefault().id  // e.g., "Europe/Warsaw"
                result.success(timeZoneId)
            } else {
                result.notImplemented()
            }
        }
    }
}