package com.example.room_ease

import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.content.Context
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val NOTIFICATION_CHANNEL = "payment_notification_channel"
    private val SMS_CHANNEL = "sms_detection_channel"
    private var smsReceiver: SmsReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for notification listener
        val notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        NotificationListener.methodChannel = notificationChannel
        
        notificationChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                "hasNotificationPermission" -> {
                    result.success(hasNotificationPermission())
                }
                "startNotificationListener" -> {
                    // The listener is automatically active when permission is granted
                    result.success(true)
                }
                "stopNotificationListener" -> {
                    // The listener stops when permission is revoked
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // SMS channel
        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startSmsListener" -> {
                    startSmsListener(smsChannel)
                    result.success(true)
                }
                "stopSmsListener" -> {
                    stopSmsListener()
                    result.success(true)
                }
                "processRecentSms" -> {
                    // For now, just return success
                    // Could implement reading recent SMS from content provider
                    result.success(true)
                }
                "getPendingSmsPayload" -> {
                    val prefs = getSharedPreferences("sms_detection_store", Context.MODE_PRIVATE)
                    result.success(prefs.getString("pending_sms_payload", null))
                }
                "clearPendingSmsPayload" -> {
                    val prefs = getSharedPreferences("sms_detection_store", Context.MODE_PRIVATE)
                    prefs.edit().remove("pending_sms_payload").apply()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startSmsListener(methodChannel: MethodChannel) {
        try {
            Log.d("MainActivity", "Starting SMS listener")
            
            // Set the method channel for the SmsReceiver
            SmsReceiver.setMethodChannel(methodChannel)
            
            if (smsReceiver == null) {
                smsReceiver = SmsReceiver()
            }
            
            val intentFilter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
            intentFilter.priority = 1000
            
            registerReceiver(smsReceiver, intentFilter)
            Log.d("MainActivity", "SMS receiver registered successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting SMS listener: ${e.message}")
        }
    }

    private fun stopSmsListener() {
        try {
            Log.d("MainActivity", "Stopping SMS listener")
            
            smsReceiver?.let {
                unregisterReceiver(it)
                Log.d("MainActivity", "SMS receiver unregistered successfully")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error stopping SMS listener: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopSmsListener()
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    private fun hasNotificationPermission(): Boolean {
        val packageName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":").toTypedArray()
            for (name in names) {
                val componentName = ComponentName.unflattenFromString(name)
                if (componentName != null) {
                    if (TextUtils.equals(packageName, componentName.packageName)) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
