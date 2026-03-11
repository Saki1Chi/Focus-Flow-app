package com.example.calendario

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat

class AppBlockerService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences
    private var lastBlockedTime = 0L
    private val BLOCK_COOLDOWN_MS = 1000L // 1 second cooldown to avoid spam

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Don't block our own app or system UI
        if (packageName == "com.example.calendario" ||
            packageName == "com.android.systemui" ||
            packageName == "android") return

        val isBlockingActive = prefs.getBoolean("flutter.focusflow_blocking_active", false)
        if (!isBlockingActive) return

        val blockedAppsJson = prefs.getString("flutter.focusflow_blocked_apps", "[]") ?: "[]"
        val blockedApps = parseJsonArray(blockedAppsJson)

        if (blockedApps.contains(packageName)) {
            val now = System.currentTimeMillis()
            if (now - lastBlockedTime < BLOCK_COOLDOWN_MS) return
            lastBlockedTime = now

            redirectToFocusFlow()
        }
    }

    private fun redirectToFocusFlow() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_blocker", true)
        }
        startActivity(intent)
        showBlockedNotification()
    }

    private fun showBlockedNotification() {
        val channelId = "focusflow_blocker"
        val notifManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channel = NotificationChannel(
            channelId,
            "App Blocker",
            NotificationManager.IMPORTANCE_HIGH
        )
        notifManager.createNotificationChannel(channel)

        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("FocusFlow — Stay Focused!")
            .setContentText("Complete your tasks to unlock this app.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openIntent)
            .build()

        notifManager.notify(9999, notification)
    }

    private fun parseJsonArray(json: String): List<String> {
        val result = mutableListOf<String>()
        val trimmed = json.trim()
        if (trimmed == "[]" || trimmed.isEmpty()) return result
        val inner = trimmed.removePrefix("[").removeSuffix("]")
        inner.split(",").forEach { item ->
            val clean = item.trim().removeSurrounding("\"")
            if (clean.isNotEmpty()) result.add(clean)
        }
        return result
    }

    override fun onInterrupt() {}
}
