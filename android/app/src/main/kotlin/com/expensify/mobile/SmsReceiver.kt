package com.expensify.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "expensify_transactions"
        const val CHANNEL_NAME = "Transaction Alerts"
        const val PREFS_NAME = "expensify_sms_prefs"
        const val KEY_SMS_TRACKING_ENABLED = "sms_tracking_enabled"

        // Keywords indicating OTP/Promo to immediately discard
        private val OTP_PATTERNS = listOf(
            Pattern.compile("\\b(otp|one time password|verification code|secret code|login code|do not share)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(code is|use otp|your otp)\\b", Pattern.CASE_INSENSITIVE)
        )

        private val PROMO_PATTERNS = listOf(
            Pattern.compile("\\b(apply now|pre-approved|instant loan|congratulations|discount|flat off|offer valid|cashback up to|zero interest)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(win|lottery|free voucher|upgrade your card|promo code)\\b", Pattern.CASE_INSENSITIVE)
        )

        // Debit signals
        private val DEBIT_PATTERNS = listOf(
            Pattern.compile("\\b(debited|debit|withdrawn|spent|paid|payment of|sent to|transferred to|purchase at|charged to|deducted)\\b", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(vpa|upi payment|txn of|txn successful)\\b", Pattern.CASE_INSENSITIVE)
        )

        // Amount regex: matches Rs. 500, Rs 500.00, INR 1,250, ₹ 450, INR 1200.00, etc.
        private val AMOUNT_PATTERN = Pattern.compile(
            "(?:rs\\.?|inr|₹)\\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\\.[0-9]{1,2})?|[0-9]+(?:\\.[0-9]{1,2})?)",
            Pattern.CASE_INSENSITIVE
        )

        // Account pattern: A/c XX1234, Acct ending 1234, card ending 4321
        private val ACCOUNT_PATTERN = Pattern.compile(
            "(?:a\\/c|acct|account|card)\\s*(?:no\\.?)?\\s*(?:ending\\s*)?(?:[xX*]*([0-9]{3,4}))",
            Pattern.CASE_INSENSITIVE
        )

        // Reference pattern: Ref: 123456, UPI Ref 123456, RRN: 123456, URN: 123456
        private val REF_PATTERN = Pattern.compile(
            "(?:ref(?:\\s*no)?|rrn|urn|txn\\s*(?:id)?|reference\\s*(?:no)?)\\s*[:\\-]?\\s*([a-zA-Z0-9]{6,25})",
            Pattern.CASE_INSENSITIVE
        )

        // Payee pattern: to <Payee>, at <Payee>, VPA <UPI_ID>
        private val PAYEE_PATTERN = Pattern.compile(
            "(?:to|at|vpa|paid to)\\s+([a-zA-Z0-9._@\\-\\s]{3,30})(?:\\s+on|\\s+ref|\\s+avl|\\s+available|\\.|\\,|$)",
            Pattern.CASE_INSENSITIVE
        )

        // UPI ID pattern: abc@upi, user@okhdfcbank, etc.
        private val UPI_ID_PATTERN = Pattern.compile(
            "([a-zA-Z0-9._\\-]+@[a-zA-Z0-9]+)",
            Pattern.CASE_INSENSITIVE
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_SMS_TRACKING_ENABLED, false)
        if (!isEnabled) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val fullBody = messages.joinToString("") { it.displayMessageBody ?: "" }
        val sender = messages.firstOrNull()?.displayOriginatingAddress ?: ""
        val timestamp = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()

        processIncomingSms(context, sender, fullBody, timestamp)
    }

    fun processIncomingSms(context: Context, sender: String, body: String, timestamp: Long): String {
        if (body.isBlank()) return "IGNORED_EMPTY"

        // 1. Exclude OTP messages
        for (pattern in OTP_PATTERNS) {
            if (pattern.matcher(body).find()) return "IGNORED_OTP"
        }

        // 2. Exclude promotional messages
        for (pattern in PROMO_PATTERNS) {
            if (pattern.matcher(body).find()) return "IGNORED_PROMO"
        }

        // 3. Must have a debit signal
        var isDebit = false
        for (pattern in DEBIT_PATTERNS) {
            if (pattern.matcher(body).find()) {
                isDebit = true
                break
            }
        }
        if (!isDebit) return "IGNORED_NOT_DEBIT"

        // 4. Extract Amount
        val amountMatcher = AMOUNT_PATTERN.matcher(body)
        if (!amountMatcher.find()) return "FAILED_NO_AMOUNT"

        val rawAmount = amountMatcher.group(1)?.replace(",", "") ?: return "FAILED_INVALID_AMOUNT"
        val amount = rawAmount.toDoubleOrNull() ?: return "FAILED_INVALID_AMOUNT"
        if (amount <= 0.0) return "FAILED_INVALID_AMOUNT"

        // 5. Extract Account Identifier
        var accountId: String? = null
        val accountMatcher = ACCOUNT_PATTERN.matcher(body)
        if (accountMatcher.find()) {
            accountId = "XX" + accountMatcher.group(1)
        }

        // 6. Extract Reference ID
        var refId: String? = null
        val refMatcher = REF_PATTERN.matcher(body)
        if (refMatcher.find()) {
            refId = refMatcher.group(1)?.trim()
        }

        // 7. Extract UPI ID or Payee
        var upiId: String? = null
        val upiMatcher = UPI_ID_PATTERN.matcher(body)
        if (upiMatcher.find()) {
            upiId = upiMatcher.group(1)?.trim()
        }

        var payee: String? = null
        val payeeMatcher = PAYEE_PATTERN.matcher(body)
        if (payeeMatcher.find()) {
            val candidate = payeeMatcher.group(1)?.trim()
            if (candidate != null && !candidate.equals("your account", ignoreCase = true) && !candidate.equals("a/c", ignoreCase = true)) {
                payee = candidate
            }
        }

        // 8. Bank Name from Sender
        val bankName = cleanSenderToBankName(sender)

        // 9. Store in SQLite & check duplicates
        val dbPath = context.getDatabasePath("expensify_offline.db")
        if (!dbPath.exists()) return "FAILED_DB_NOT_FOUND"

        val fp = if (!refId.isNullOrBlank()) {
            "REF_${refId.trim().uppercase(Locale.US)}"
        } else {
            val acct = accountId?.trim()?.uppercase(Locale.US) ?: "NA"
            val payeeKey = (upiId ?: "NA").trim().lowercase(Locale.US)
            val timeBucket = timestamp / 300000L
            "FP_${acct}_${payeeKey}_${String.format(Locale.US, "%.2f", amount)}_$timeBucket"
        }

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)

            // Duplicate Check
            if (isDuplicateTransaction(db, refId, amount, accountId ?: upiId ?: sender, timestamp, fp)) {
                return "DUPLICATE"
            }

            // Learned Payee lookup
            val lookupKey = upiId ?: accountId ?: payee
            var learnedPayee: String? = null
            if (lookupKey != null) {
                val cursor = db.rawQuery(
                    "SELECT payee_name FROM payee_mappings WHERE identifier = ? LIMIT 1",
                    arrayOf(lookupKey)
                )
                if (cursor.moveToFirst()) {
                    learnedPayee = cursor.getString(0)
                }
                cursor.close()
            }

            val finalPayee = learnedPayee ?: payee
            val pendingId = UUID.randomUUID().toString()

            val values = ContentValues().apply {
                put("id", pendingId)
                put("amount", amount)
                put("transaction_type", "debit")
                put("sender", sender)
                put("bank_name", bankName)
                put("account_identifier", accountId)
                put("payee_identifier", upiId ?: accountId)
                put("parsed_payee", finalPayee)
                put("reference_id", refId)
                put("sms_timestamp", timestamp)
                put("raw_sms", body)
                put("status", "pending")
                put("created_at", System.currentTimeMillis())
                put("fingerprint", fp)
            }

            db.insert("pending_transactions", null, values)

            // 10. Show Notification
            showTransactionNotification(context, pendingId, amount, finalPayee ?: bankName ?: "account")

            // 11. Notify active Flutter instance if any
            MainActivity.notifyPendingTransactionCreated(pendingId)

            return "SUCCESS"
        } catch (e: Exception) {
            return "FAILED_EXCEPTION: ${e.message}"
        } finally {
            db?.close()
        }
    }

    private fun isDuplicateTransaction(
        db: SQLiteDatabase,
        refId: String?,
        amount: Double,
        identifier: String,
        timestamp: Long,
        fingerprint: String
    ): Boolean {
        // Priority 1: Check by reference ID
        if (!refId.isNullOrBlank()) {
            val cursor = db.rawQuery(
                "SELECT id FROM pending_transactions WHERE reference_id = ? LIMIT 1",
                arrayOf(refId.trim())
            )
            val exists = cursor.count > 0
            cursor.close()
            if (exists) return true
        }

        // Priority 2: Check by fingerprint
        if (fingerprint.isNotBlank()) {
            val cursor = db.rawQuery(
                "SELECT id FROM pending_transactions WHERE fingerprint = ? LIMIT 1",
                arrayOf(fingerprint)
            )
            val exists = cursor.count > 0
            cursor.close()
            if (exists) return true
        }

        // Priority 3: Check by amount + identifier within 5 minutes (300,000 ms)
        val minTimeMs = timestamp - 300000L
        val maxTimeMs = timestamp + 300000L

        val cursor = db.rawQuery(
            """
            SELECT id FROM pending_transactions 
            WHERE amount = ? 
            AND (account_identifier = ? OR sender = ? OR payee_identifier = ?) 
            AND sms_timestamp BETWEEN ? AND ? 
            AND status != 'ignored' 
            LIMIT 1
            """.trimIndent(),
            arrayOf(
                amount.toString(),
                identifier,
                identifier,
                identifier,
                minTimeMs.toString(),
                maxTimeMs.toString()
            )
        )
        val exists = cursor.count > 0
        cursor.close()
        return exists
    }

    private fun showTransactionNotification(
        context: Context,
        pendingId: String,
        amount: Double,
        target: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts for detected payment and debit transactions"
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("pending_transaction_id", pendingId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            pendingId.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val formattedAmount = if (amount % 1.0 == 0.0) {
            String.format(Locale.getDefault(), "%.0f", amount)
        } else {
            String.format(Locale.getDefault(), "%.2f", amount)
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle("Payment detected")
            .setContentText("₹$formattedAmount was debited from your account.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("₹$formattedAmount was debited from your account. Tap to confirm and add details."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(pendingId.hashCode(), notification)
    }

    private fun cleanSenderToBankName(sender: String): String? {
        val clean = sender.uppercase(Locale.US).replace("-", "").replace("_", "")
        return when {
            clean.contains("HDFC") -> "HDFC Bank"
            clean.contains("SBI") -> "SBI"
            clean.contains("ICICI") -> "ICICI Bank"
            clean.contains("AXIS") -> "Axis Bank"
            clean.contains("KOTAK") -> "Kotak Bank"
            clean.contains("PAYTM") -> "Paytm Bank"
            clean.contains("PNB") -> "PNB"
            clean.contains("BOB") || clean.contains("BARODA") -> "Bank of Baroda"
            clean.contains("CANARA") -> "Canara Bank"
            clean.contains("UNION") -> "Union Bank"
            clean.contains("IDFC") -> "IDFC First"
            clean.contains("INDUS") -> "IndusInd Bank"
            clean.isNotEmpty() -> clean.takeLast(6)
            else -> null
        }
    }
}
