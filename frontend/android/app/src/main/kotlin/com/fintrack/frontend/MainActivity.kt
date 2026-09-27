package com.fintrack.frontend

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "com.fintrack/capture_events"
    private val METHOD_CHANNEL = "com.fintrack/capture_bridge"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup EventChannel for real-time live events from CaptureBus
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    CaptureBus.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    CaptureBus.setEventSink(null)
                }
            }
        )

        // Setup MethodChannel for querying pending events and checking permissions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingEvents" -> {
                    val pending = CaptureBus.drainPendingEvents(applicationContext)
                    result.success(pending)
                }
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "checkNotificationPermission" -> {
                    val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                    val isEnabled = enabledListeners != null && enabledListeners.contains(packageName)
                    result.success(isEnabled)
                }
                else -> result.notImplemented()
            }
        }
    }
}
