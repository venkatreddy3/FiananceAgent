package com.fintrack.frontend

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.Locale
import java.util.regex.Pattern

class TransactionNotificationService : NotificationListenerService() {

    private val currencyRegex = Pattern.compile("(\\b(rs\\.?|inr)\\s?\\d|₹\\s?\\d)", Pattern.CASE_INSENSITIVE)

    private val targetPaymentPackages = setOf(
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

    private val ignoredSmsPackages = setOf(
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.android.mms",
        "com.android.messaging"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        // 1. Ignore ongoing notifications (e.g. downloads, background sync)
        if (sbn.isOngoing) return

        val pkg = sbn.packageName ?: ""

        // 2. Ignore our own package
        if (pkg == packageName) return

        // 3. Ignore SMS app notifications to avoid duplicate capture with SmsReceiver
        if (ignoredSmsPackages.contains(pkg)) return

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        val combinedContent = "$title : $text $bigText".trim()
        val postTime = sbn.postTime

        val isTargetApp = targetPaymentPackages.contains(pkg)
        if (isFinancialText(combinedContent) || (isTargetApp && isTransactionLike(combinedContent))) {
            val sourceName = getSourceName(pkg)
            CaptureBus.onEventCaptured(
                context = applicationContext,
                source = sourceName,
                rawText = combinedContent,
                packageName = pkg,
                timestamp = postTime
            )
        }
    }

    private fun isFinancialText(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        if (lower.contains("otp") || lower.contains("verification code")) return false

        val hasCurrency = currencyRegex.matcher(text).find()
        if (!hasCurrency) return false

        val hasKeywords = lower.contains("debited") || 
                          lower.contains("paid") || 
                          lower.contains("spent") || 
                          lower.contains("sent") ||
                          lower.contains("payment of") ||
                          lower.contains("txn of") ||
                          lower.contains("trf to")
        return hasKeywords
    }

    private fun isTransactionLike(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        val hasCurrency = currencyRegex.matcher(text).find()
        return hasCurrency && !lower.contains("cashback") && !lower.contains("offer") && !lower.contains("reward")
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
