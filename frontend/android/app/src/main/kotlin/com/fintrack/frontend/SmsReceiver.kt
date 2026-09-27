package com.fintrack.frontend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import java.util.Locale
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {

    private val currencyRegex = Pattern.compile("(\\b(rs\\.?|inr)\\s?\\d|₹\\s?\\d)", Pattern.CASE_INSENSITIVE)

    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val messages: Array<SmsMessage> = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            if (messages.isEmpty()) return

            // Group & join multipart PDUs from the same sender
            val senderMap = mutableMapOf<String, StringBuilder>()
            var captureTimestamp = System.currentTimeMillis()

            for (sms in messages) {
                val sender = sms.originatingAddress ?: "Bank SMS"
                val body = sms.messageBody ?: ""
                captureTimestamp = sms.timestampMillis

                if (!senderMap.containsKey(sender)) {
                    senderMap[sender] = StringBuilder()
                }
                senderMap[sender]?.append(body)
            }

            for ((sender, bodyBuilder) in senderMap) {
                val fullBody = bodyBuilder.toString()
                if (isFinancialTransaction(fullBody)) {
                    val fullPayload = "[$sender] $fullBody"
                    CaptureBus.onEventCaptured(
                        context = context,
                        source = "SMS",
                        rawText = fullPayload,
                        packageName = "com.android.mms",
                        timestamp = captureTimestamp
                    )
                }
            }
        }
    }

    private fun isFinancialTransaction(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        
        // Exclude OTPs
        if (lower.contains("otp") || lower.contains("verification code") || lower.contains("one time password")) {
            return false
        }

        // Currency Regex Check
        val hasCurrency = currencyRegex.matcher(text).find()
        if (!hasCurrency) return false

        // Debit Verb Check
        val hasDebitVerb = lower.contains("debited") || 
                           lower.contains("paid") || 
                           lower.contains("spent") || 
                           lower.contains("sent") || 
                           lower.contains("txn") || 
                           lower.contains("transferred") ||
                           lower.contains("trf") ||
                           lower.contains("towards")

        return hasDebitVerb
    }
}
