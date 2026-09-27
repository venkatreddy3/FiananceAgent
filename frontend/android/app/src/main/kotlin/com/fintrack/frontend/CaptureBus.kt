package com.fintrack.frontend

import android.content.Context
import android.content.SharedPreferences
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

object CaptureBus {
    private const val PREFS_NAME = "fintrack_capture_prefs"
    private const val KEY_PENDING_EVENTS = "pending_capture_events"

    private var eventSink: EventChannel.EventSink? = null
    private var isFlutterReady = false

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
        this.isFlutterReady = sink != null
    }

    fun onEventCaptured(context: Context, source: String, rawText: String, packageName: String? = null) {
        val eventObj = JSONObject().apply {
            put("source", source)
            put("rawText", rawText)
            put("packageName", packageName ?: "")
            put("timestamp", System.currentTimeMillis())
        }

        if (isFlutterReady && eventSink != null) {
            try {
                eventSink?.success(eventObj.toString())
            } catch (e: Exception) {
                saveToPreferences(context, eventObj)
            }
        } else {
            saveToPreferences(context, eventObj)
        }
    }

    private fun saveToPreferences(context: Context, eventObj: JSONObject) {
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existingString = prefs.getString(KEY_PENDING_EVENTS, "[]") ?: "[]"
        val array = try {
            JSONArray(existingString)
        } catch (e: Exception) {
            JSONArray()
        }
        array.put(eventObj)
        prefs.edit().putString(KEY_PENDING_EVENTS, array.toString()).apply()
    }

    fun drainPendingEvents(context: Context): List<String> {
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existingString = prefs.getString(KEY_PENDING_EVENTS, "[]") ?: "[]"
        val list = mutableListOf<String>()
        try {
            val array = JSONArray(existingString)
            for (i in 0 until array.length()) {
                list.add(array.getString(i))
            }
        } catch (e: Exception) {
            // ignore
        }
        // Clear pending queue
        prefs.edit().remove(KEY_PENDING_EVENTS).apply()
        return list
    }
}
