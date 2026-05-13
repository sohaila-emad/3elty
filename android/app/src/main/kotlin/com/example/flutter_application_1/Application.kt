package com.example.flutter_application_1

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import android.os.Build

/**
 * Custom Application class.
 *
 * Creates all notification channels at process start — before Flutter or any
 * BroadcastReceiver runs. This is the only reliable way to guarantee channels
 * exist on OEM ROMs (MIUI, OneUI, ColorOS, etc.) and after device reboot,
 * when the ScheduledNotificationReceiver fires before Flutter initialises.
 */
class Application : Application() {

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannels()
        }
    }

    private fun createNotificationChannels() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val channels = listOf(
            Triple(
                "medications_channel",
                "تذكيرات الأدوية",
                NotificationManager.IMPORTANCE_HIGH
            ) to Color.rgb(0, 121, 107),   // teal

            Triple(
                "appointments_channel",
                "تذكيرات المواعيد",
                NotificationManager.IMPORTANCE_HIGH
            ) to Color.rgb(21, 101, 192),   // blue

            Triple(
                "vitals_channel",
                "تذكيرات العلامات الحيوية",
                NotificationManager.IMPORTANCE_DEFAULT
            ) to Color.rgb(230, 81, 0),     // orange

            Triple(
                "vaccinations_channel",
                "التطعيمات",
                NotificationManager.IMPORTANCE_DEFAULT
            ) to Color.rgb(21, 101, 192)    // blue
        )

        for ((triple, ledColor) in channels) {
            val (id, name, importance) = triple
            // Only create if not already registered — safe to call repeatedly
            if (nm.getNotificationChannel(id) == null) {
                val channel = NotificationChannel(id, name, importance).apply {
                    enableLights(true)
                    lightColor = ledColor
                    enableVibration(true)
                    setShowBadge(true)
                }
                nm.createNotificationChannel(channel)
            }
        }
    }
}