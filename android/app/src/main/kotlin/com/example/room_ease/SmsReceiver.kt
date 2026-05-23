package com.example.room_ease

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "SmsReceiver"
        private var methodChannel: MethodChannel? = null
        
        // Set the method channel from MainActivity
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d(TAG, "SMS received, processing...")
        
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                
                for (message in messages) {
                    val sender = message.originatingAddress ?: "Unknown"
                    val body = message.messageBody ?: ""
                    
                    Log.d(TAG, "SMS from $sender: $body")
                    
                    // Check if this looks like a payment SMS
                    if (isPaymentSms(sender, body)) {
                        Log.d(TAG, "Payment SMS detected, sending to Flutter")
                        
                        // Send to Flutter if method channel is available
                        methodChannel?.let { channel ->
                            val smsData = mapOf(
                                "sender" to sender,
                                "body" to body,
                                "timestamp" to System.currentTimeMillis()
                            )
                            
                            try {
                                channel.invokeMethod("onSmsReceived", smsData)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error sending SMS to Flutter: ${e.message}")
                            }
                        } ?: run {
                            Log.w(TAG, "Method channel not available, cannot send SMS to Flutter")
                        }
                    } else {
                        Log.d(TAG, "Not a payment SMS, ignoring")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing SMS: ${e.message}")
            }
        }
    }
    
    private fun isPaymentSms(sender: String, body: String): Boolean {
        val upperSender = sender.uppercase()
        val lowerBody = body.lowercase()
        
        // Check for supported senders (bank names, payment apps)
        val supportedSenders = listOf(
            "NABIL", "NIC ASIA", "NMB", "GLOBAL", "EVEREST", "NEPAL BANK",
            "RBB", "SANIMA", "SCB", "HIMALAYAN", "NIB", "MACHHAPUCHCHHRE",
            "ESEWA", "KHALTI", "IMEPAY", "CONNECTIPS", "FONEPAY", "IPAY",
            "BANK", "BANKING", "ATM", "CARD", "ALERT", "NOTIFICATION"
        )
        
        var hasSupportedSender = supportedSenders.any { 
            upperSender.contains(it) || it.contains(upperSender)
        }
        
        // If sender not in list, check if it's numeric (banks often use short codes or phone numbers)
        if (!hasSupportedSender) {
            // Check if sender is numeric (remove + and country code)
            val cleanSender = sender.replace("+", "").replace("-", "").replace(" ", "")
            val isNumeric = cleanSender.matches(Regex("\\d+"))
            if (isNumeric) {
                Log.d(TAG, "Numeric sender detected: $sender - treating as potential bank SMS")
                hasSupportedSender = true
            }
        }
        
        // Check for payment keywords
        val paymentKeywords = listOf(
            "credited", "debited", "paid", "payment", "transaction",
            "successful", "amount", "npr", "rs.", "transfer", "sent",
            "received", "balance", "has been", "account", "debit", "credit"
        )
        
        val hasPaymentKeywords = paymentKeywords.any { 
            lowerBody.contains(it)
        }
        
        val result = hasSupportedSender && hasPaymentKeywords
        Log.d(TAG, "Payment SMS check - Sender: $sender ($hasSupportedSender), Keywords: $hasPaymentKeywords, Result: $result")
        
        return result
    }
}