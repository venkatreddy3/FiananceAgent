package com.fintrack.frontend

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.Locale

class TransactionNotificationService : NotificationListenerService() {

    private val targetPackages = setOf(
        "com.phonepe.app",
        "com.google.android.apps.nbu.paisa.user",
        "net.one97.paytm",
        "com.dreamplug.androidapp", // CRED
        "com.csam.icici.bank.imobile",
        "com.hdfcbank.mobile",
        "com.sbi.lotusintouch",
        "com.axis.mobile",
        "com.kotak.mobile"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkg = sbn.packageName ?: ""
        val extras = sbn.notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        val combinedContent = "$title : $text $bigText".trim()
        
        // Either matches known payment app package or contains explicit financial keywords
        val isTargetApp = targetPackages.contains(pkg)
        if (isFinancialText(combinedContent) || (isTargetApp && isTransactionLike(combinedContent))) {
            val sourceName = getSourceName(pkg)
            CaptureBus.onEventCaptured(
                context = applicationContext,
                source = sourceName,
                rawText = combinedContent,
                packageName = pkg
            )
        }
    }

    private fun isFinancialText(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        val hasCurrency = lower.contains("rs") || lower.contains("inr") || lower.contains("₹")
        val hasKeywords = lower.contains("debited") || 
                          lower.contains("paid") || 
                          lower.contains("spent") || 
                          lower.contains("sent") ||
                          lower.contains("payment of")
        val isOtp = lower.contains("otp") || lower.contains("verification code")
        return hasCurrency && hasKeywords && !isOtp
    }

    private fun isTransactionLike(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        val hasCurrency = lower.contains("rs") || lower.contains("inr") || lower.contains("₹")
        return hasCurrency && !lower.contains("cashback") && !lower.contains("offer")
    }

    private fun getSourceName(pkg: String): String {
        return when (pkg) {
            "com.phonepe.app" -> "PhonePe"
            "com.google.android.apps.nbu.paisa.user" -> "Google Pay"
            "net.one97.paytm" -> "Paytm"
            "com.dreamplug.androidapp" -> "CRED"
            else -> "Notification"
        }
    }
}
