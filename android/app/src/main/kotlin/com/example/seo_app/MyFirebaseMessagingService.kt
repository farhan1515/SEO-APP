package com.example.seo_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {
    companion object {
        private const val TAG = "FCM_SERVICE"
        private const val CHANNEL_ID = "high_importance_channel"
        private const val NOTIFICATION_ID = 101
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "Refreshed token: $token")
        // Store token in Firestore (handled in Flutter side)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "From: ${remoteMessage.from}")

        val data = remoteMessage.data
        val notification = remoteMessage.notification

        // Create notification channel for API 26+
        createNotificationChannel()

        // Prepare intent for navigation
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            data?.forEach { (key, value) ->
                putExtra(key, value)
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setSound(defaultSoundUri)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        // Handle specific notification types
        val type = data["type"] ?: ""
        when (type) {
            "chat" -> {
                notificationBuilder
                    .setContentTitle(notification?.title ?: "New Message")
                    .setContentText(notification?.body ?: data["body"] ?: "You received a new message")
                    .setStyle(NotificationCompat.BigTextStyle()
                        .bigText(notification?.body ?: data["body"] ?: "You received a new message"))
            }
            "project" -> {
                notificationBuilder
                    .setContentTitle("📢 New Flyer Update")
                    .setContentText("${data["senderName"] ?: "Someone"} updated the flyer")
            }
            "flyer_approval" -> {
                notificationBuilder
                    .setContentTitle("✅ Flyer Approved")
                    .setContentText("${data["senderName"] ?: "Someone"} approved your flyer")
            }
            "flyer_feedback" -> {
                notificationBuilder
                    .setContentTitle("❌ Flyer Feedback")
                    .setContentText("${data["senderName"] ?: "Someone"} provided feedback")
            }
            else -> {
                // Use notification payload if available, else data payload
                notificationBuilder
                    .setContentTitle(notification?.title ?: data["title"] ?: "New Message")
                    .setContentText(notification?.body ?: data["body"] ?: "You received a new message")
            }
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "High Importance Channel",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "This channel is used for important notifications"
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}