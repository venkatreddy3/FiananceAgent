package com.fintrack.frontend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import java.util.Locale

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val messages: Array<SmsMessage> = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            for (sms in messages) {
                val body = sms.messageBody ?: continue
                val sender = sms.originatingAddress ?: "Bank SMS"
                
                if (isFinancialTransaction(body)) {
                    val fullPayload = "[$sender] $body"
                    CaptureBus.onEventCaptured(
                        context = context,
                        source = "SMS",
                        rawText = fullPayload,
                        packageName = "com.android.mms"
                    )
                }
            }
        }
    }

    private fun isFinancialTransaction(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        val hasCurrency = lower.contains("rs") || lower.contains("inr") || lower.contains("₹")
        val hasKeywords = lower.contains("debited") || 
                          lower.contains("paid") || 
                          lower.contains("spent") || 
                          lower.contains("sent") || 
                          lower.contains("txn") || 
                          lower.contains("vpa") ||
                          lower.contains("transferred")
        val isOtp = lower.contains("otp") || lower.contains("verification code") || lower.contains("one time password")
        
        return hasCurrency && hasKeywords && !isOtp
    }
}
