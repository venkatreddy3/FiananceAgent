package com.fintrack.frontend

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

object CaptureBus {
    private const val PREFS_NAME = "fintrack_capture_prefs"
    private const val KEY_PENDING_EVENTS = "pending_capture_events"
    private const val MAX_PENDING_EVENTS = 200

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    fun onEventCaptured(
        context: Context,
        source: String,
        rawText: String,
        packageName: String? = null,
        timestamp: Long = System.currentTimeMillis()
    ) {
        val eventObj = JSONObject().apply {
            put("source", source)
            put("rawText", rawText)
            put("packageName", packageName ?: "")
            put("timestamp", timestamp)
        }

        val currentSink = eventSink
        if (currentSink != null) {
            mainHandler.post {
                try {
                    currentSink.success(eventObj.toString())
                } catch (e: Exception) {
                    saveToPreferences(context, eventObj)
                }
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

        // Cap buffer at 200 events (drop oldest if exceeding)
        if (array.length() >= MAX_PENDING_EVENTS) {
            val trimmedArray = JSONArray()
            val startIndex = array.length() - (MAX_PENDING_EVENTS - 1)
            for (i in startIndex until array.length()) {
                trimmedArray.put(array.get(i))
            }
            trimmedArray.put(eventObj)
            prefs.edit().putString(KEY_PENDING_EVENTS, trimmedArray.toString()).apply()
        } else {
            array.put(eventObj)
            prefs.edit().putString(KEY_PENDING_EVENTS, array.toString()).apply()
        }
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
        prefs.edit().remove(KEY_PENDING_EVENTS).apply()
        return list
    }
}
