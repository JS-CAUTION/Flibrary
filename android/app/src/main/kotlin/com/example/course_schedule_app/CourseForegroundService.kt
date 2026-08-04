package com.example.course_schedule_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the app alive in the background.
 * The actual schedule checking is done by a Dart Timer.periodic —
 * this service just prevents vivo's task killer from pausing the Dart isolate.
 */
class CourseForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "course_service"
        const val NOTIFY_ID = 9000
        const val ACTION_STOP = "com.example.course_schedule_app.STOP_SERVICE"
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课程服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持课程提醒在后台运行"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFY_ID, buildForegroundNotification())
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(): android.app.Notification {
        val appInfo = packageManager.getApplicationInfo(packageName, 0)
        val appLabel = packageManager.getApplicationLabel(appInfo)

        val bmp = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(bmp)
            .setContentTitle(appLabel)
            .setContentText("流转")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
