package com.example.room_ease

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class NotificationListener : NotificationListenerService() {
    
    companion object {
        private const val TAG = "NotificationListener"
        var methodChannel: MethodChannel? = null
        
        // Supported payment apps - including all possible eSewa package names
        private val SUPPORTED_PACKAGES = setOf(
            "com.f1soft.esewa",
            "com.esewa.android",
            "com.esewa",
            "esewa",
            "com.khalti.red",
            "com.khalti",
            "khalti",
            "com.imepay.wallet",
            "com.fonepay.wallet", 
            "com.connectips.mobile",
            "com.ipay.wallet",
            // Banking apps
            "com.f1soft.nmbbank",
            "com.sanimabank.mobile",
            "com.everestbankltd.mobile",
            "com.nepalbank.mobile",
            "com.rbb.mobile",
            "com.nabilbank.mobile",
            "com.scb.mobile",
            "com.himalayanbank.mobile",
            "com.nib.mobile",
            "com.machhapuchchhrebank.mobile"
        )
        
        // Payment keywords
        private val PAYMENT_KEYWORDS = setOf(
            "payment successful",
            "transaction successful", 
            "paid npr",
            "paid rs",
            "payment complete",
            "transaction complete",
            "successfully transferred",
            "successfully paid",
            "payment of",
            "transaction of",
            "debited",
            "credited",
            "balance",
            "amount"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        
        sbn?.let { notification ->
            try {
                val packageName = notification.packageName
                val extras = notification.notification.extras
                
                // Log ALL notifications for debugging
                Log.d(TAG, "=== NOTIFICATION RECEIVED ===")
                Log.d(TAG, "Package: $packageName")
                
                val title = extras.getCharSequence("android.title")?.toString() ?: ""
                val text = extras.getCharSequence("android.text")?.toString() ?: ""
                val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
                val subText = extras.getCharSequence("android.subText")?.toString() ?: ""
                val summaryText = extras.getCharSequence("android.summaryText")?.toString() ?: ""
                
                Log.d(TAG, "Title: $title")
                Log.d(TAG, "Text: $text")
                Log.d(TAG, "BigText: $bigText")
                Log.d(TAG, "SubText: $subText")
                Log.d(TAG, "SummaryText: $summaryText")
                
                // Check for payment app notifications (including Gmail notifications)
                val isPaymentNotification = isSupportedPackage(packageName) ||
                    (packageName.contains("gmail", ignoreCase = true) && 
                     isPaymentRelatedEmail(title, text, bigText))
                
                if (isPaymentNotification) {
                    val detectedApp = getAppNameFromNotification(packageName, title, text, bigText)
                    Log.d(TAG, "🎯 Payment notification detected from $detectedApp via $packageName! Sending to Flutter...")
                    
                    val combinedContent = listOf(title, text, bigText, subText, summaryText)
                        .filter { it.isNotEmpty() }
                        .joinToString(" ")
                    
                    Log.d(TAG, "Method channel available: ${methodChannel != null}")
                    
                    if (methodChannel != null) {
                        try {
                            methodChannel?.invokeMethod("onNotificationReceived", mapOf(
                                "packageName" to packageName,
                                "title" to title,
                                "content" to combinedContent
                            ))
                            Log.d(TAG, "✅ Successfully invoked method channel")
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Error invoking method channel: ${e.message}")
                        }
                    } else {
                        Log.e(TAG, "❌ Method channel is null!")
                    }
                    
                    Log.d(TAG, "✅ Sent $detectedApp notification to Flutter")
                    return
                }
                
                // Check if it's from a supported payment app
                if (!isSupportedPackage(packageName)) {
                    // Only log non-system packages to reduce noise
                    if (!packageName.startsWith("com.android") && 
                        !packageName.startsWith("android") &&
                        !packageName.contains("system")) {
                        Log.d(TAG, "Package not supported: $packageName")
                    }
                    return
                }
                
                val fullText = "$title $text $bigText $subText $summaryText".lowercase()
                
                Log.d(TAG, "Full combined text: $fullText")
                
                // Check if it contains payment keywords
                if (!isPaymentNotification(fullText)) {
                    Log.d(TAG, "Not a payment notification - no keywords found")
                    return
                }
                
                Log.d(TAG, "🎯 Payment notification detected from $packageName!")
                
                // Send to Flutter
                val combinedContent = listOf(title, text, bigText, subText, summaryText)
                    .filter { it.isNotEmpty() }
                    .joinToString(" ")
                
                methodChannel?.invokeMethod("onNotificationReceived", mapOf(
                    "packageName" to packageName,
                    "title" to title,
                    "content" to combinedContent
                ))
                
                Log.d(TAG, "✅ Sent payment notification to Flutter")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error processing notification", e)
            }
        }
    }
    
    private fun isSupportedPackage(packageName: String): Boolean {
        // Check for eSewa specifically
        if (packageName.contains("esewa", ignoreCase = true)) {
            return true
        }
        
        // Check for other supported packages
        return SUPPORTED_PACKAGES.any { supportedPackage ->
            packageName.contains(supportedPackage, ignoreCase = true) ||
            supportedPackage.contains(packageName, ignoreCase = true)
        }
    }
    
    private fun isPaymentNotification(text: String): Boolean {
        return PAYMENT_KEYWORDS.any { keyword ->
            text.contains(keyword, ignoreCase = true)
        }
    }
    
    private fun isPaymentRelatedEmail(title: String, text: String, bigText: String): Boolean {
        val combinedText = "$title $text $bigText".lowercase()
        
        // Check for payment app names in email notifications
        val paymentApps = listOf("esewa", "khalti", "ime pay", "fonepay", "connectips", "ipay")
        return paymentApps.any { app ->
            combinedText.contains(app, ignoreCase = true)
        } && isPaymentNotification(combinedText)
    }
    
    private fun getAppNameFromNotification(packageName: String, title: String, text: String, bigText: String): String {
        // If it's a direct app notification, use package name
        if (isSupportedPackage(packageName)) {
            return when {
                packageName.contains("esewa", ignoreCase = true) -> "eSewa"
                packageName.contains("khalti", ignoreCase = true) -> "Khalti"
                packageName.contains("imepay", ignoreCase = true) -> "IME Pay"
                packageName.contains("fonepay", ignoreCase = true) -> "FonePay"
                packageName.contains("connectips", ignoreCase = true) -> "ConnectIPS"
                packageName.contains("ipay", ignoreCase = true) -> "iPay"
                packageName.contains("nabil", ignoreCase = true) -> "Nabil Bank"
                packageName.contains("sanima", ignoreCase = true) -> "Sanima Bank"
                packageName.contains("nmb", ignoreCase = true) -> "NMB Bank"
                else -> "Payment App"
            }
        }
        
        // If it's an email notification, detect from content
        val combinedText = "$title $text $bigText".lowercase()
        return when {
            combinedText.contains("esewa", ignoreCase = true) -> "eSewa"
            combinedText.contains("khalti", ignoreCase = true) -> "Khalti"
            combinedText.contains("ime pay", ignoreCase = true) -> "IME Pay"
            combinedText.contains("fonepay", ignoreCase = true) -> "FonePay"
            combinedText.contains("connectips", ignoreCase = true) -> "ConnectIPS"
            combinedText.contains("ipay", ignoreCase = true) -> "iPay"
            else -> "Payment App"
        }
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connected!")
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected!")
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationListener service created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "NotificationListener service destroyed")
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}