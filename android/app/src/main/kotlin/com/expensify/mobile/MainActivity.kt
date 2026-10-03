package com.expensify.mobile

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.expensify.mobile/sms"
        const val PREFS_NAME = "expensify_sms_prefs"
        const val KEY_SMS_TRACKING_ENABLED = "sms_tracking_enabled"
        private const val PERMISSION_REQUEST_CODE = 4041

        var methodChannel: MethodChannel? = null

        fun notifyPendingTransactionCreated(pendingId: String) {
            methodChannel?.invokeMethod("onPendingTransactionDetected", pendingId)
            methodChannel?.invokeMethod("onPendingTransactionReceived", pendingId)
        }
    }

    private var pendingResult: MethodChannel.Result? = null
    private var initialPendingTransactionId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSmsTrackingStatus", "checkPermissions" -> {
                        val status = getLivePermissionStatus()
                        result.success(status)
                    }

                    "isSmsTrackingEnabled" -> {
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        result.success(prefs.getBoolean(KEY_SMS_TRACKING_ENABLED, false))
                    }

                    "setSmsTrackingEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putBoolean(KEY_SMS_TRACKING_ENABLED, enabled).apply()
                        result.success(true)
                    }

                    "requestPermissions", "requestSmsPermissions" -> {
                        val permissionsToRequest = mutableListOf<String>()

                        if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
                            permissionsToRequest.add(Manifest.permission.RECEIVE_SMS)
                        }
                        if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                            permissionsToRequest.add(Manifest.permission.READ_SMS)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
                            }
                        }

                        // Requirement 7: If permissions are already granted, do not request them again
                        if (permissionsToRequest.isEmpty()) {
                            result.success(true)
                        } else {
                            pendingResult = result
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                permissionsToRequest.toTypedArray(),
                                PERMISSION_REQUEST_CODE
                            )
                        }
                    }

                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("APP_SETTINGS_ERROR", e.message, null)
                        }
                    }

                    "getInitialPendingId", "getInitialPendingTransactionId" -> {
                        val id = initialPendingTransactionId
                        initialPendingTransactionId = null
                        result.success(id)
                    }

                    "dismissNotification" -> {
                        val pendingId = call.argument<String>("pendingId")
                        val notifId = call.argument<Int>("id") ?: pendingId?.hashCode()
                        if (notifId != null) {
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            notificationManager.cancel(notifId)
                        }
                        result.success(true)
                    }

                    // Simulated incoming SMS for testing on physical devices or emulator without real bank transaction
                    "simulateIncomingSms" -> {
                        val sender = call.argument<String>("sender") ?: "HDFCBK"
                        val body = call.argument<String>("message") ?: call.argument<String>("body") ?: ""
                        val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
                        val status = SmsReceiver().processIncomingSms(this@MainActivity, sender, body, timestamp)
                        result.success(status)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // Check if intent launched with pending_transaction_id or extra_pending_id
        val pendingId = intent?.getStringExtra("pending_transaction_id")
            ?: intent?.getStringExtra("extra_pending_id")
        if (pendingId != null) {
            initialPendingTransactionId = pendingId
        }
    }

    private fun getLivePermissionStatus(): Map<String, Any> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_SMS_TRACKING_ENABLED, false)

        val hasReceiveSms = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
        val hasReadSms = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        // Requirement 1: If RECEIVE_SMS is granted, report SMS permission as granted
        val hasSms = hasReceiveSms

        // Requirement 2: If POST_NOTIFICATIONS is granted (or notifications enabled on pre-Tiramisu), report notification permission as granted
        val hasNotification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED &&
                NotificationManagerCompat.from(this).areNotificationsEnabled()
        } else {
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        }

        return mapOf(
            "enabled" to isEnabled,
            "isTrackingEnabled" to isEnabled,
            "hasSmsPermission" to hasSms,
            "hasReceiveSmsPermission" to hasReceiveSms,
            "hasReadSmsPermission" to hasReadSms,
            "hasNotificationPermission" to hasNotification,
            "areAllGranted" to (hasSms && hasNotification)
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val pendingId = intent.getStringExtra("pending_transaction_id")
            ?: intent.getStringExtra("extra_pending_id")
        if (pendingId != null) {
            methodChannel?.invokeMethod("onNotificationTapped", pendingId)
            methodChannel?.invokeMethod("onPendingTransactionTapped", pendingId)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val status = getLivePermissionStatus()
            val allGranted = status["areAllGranted"] as Boolean
            pendingResult?.success(allGranted)
            pendingResult = null
        }
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
