package com.example.course_schedule_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val launchChannel = "com.example.course_schedule_app/launch"
    private val alarmChannel = "com.example.course_schedule_app/alarm"
    private val serviceChannel = "com.example.course_schedule_app/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launchChannel).setMethodCallHandler { call, result ->
            if (call.method == "bringToForeground") {
                moveTaskToBack(false)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannel).setMethodCallHandler { call, result ->
            if (call.method == "fireImmediate") {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any> ?: run {
                    result.error("ARGS_ERROR", "arguments is not a Map", null)
                    return@setMethodCallHandler
                }
                val notifyId = (args["notifyId"] as? Number)?.toInt() ?: 0
                val title = args["title"] as? String ?: "通知"
                val body = args["body"] as? String ?: ""
                val channelId = args["channelId"] as? String ?: "course_ongoing"
                val channelName = args["channelName"] as? String ?: "上课常驻"
                val channelDesc = args["channelDesc"] as? String ?: ""
                val type = args["type"] as? String ?: "ongoing"
                val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val ch = android.app.NotificationChannel(
                    channelId, channelName, NotificationManager.IMPORTANCE_LOW
                ).apply { description = channelDesc }
                mgr.createNotificationChannel(ch)

                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val largeIcon = Icon.createWithResource(packageName, R.mipmap.ic_launcher)

                val notification = NotificationCompat.Builder(this, channelId)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setLargeIcon(largeIcon)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setAutoCancel(type != "ongoing")
                    .setOngoing(true)
                    .setSilent(type == "dismiss")
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setCategory(NotificationCompat.CATEGORY_SERVICE)
                    .build()
                mgr.notify(notifyId, notification)
                result.success(null)
            } else if (call.method == "cancelNotification") {
                val notifyId = (call.arguments as? Map<*, *>)?.get("notifyId") as? Number
                if (notifyId != null) {
                    val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    mgr.cancel(notifyId.toInt())
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, serviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val intent = Intent(this, CourseForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopForegroundService" -> {
                    val intent = Intent(this, CourseForegroundService::class.java).apply {
                        action = CourseForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        stopService(Intent(this, CourseForegroundService::class.java))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
