package com.vigiaia.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

class MonitorRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences("monitor_recovery", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        if (!scheduleIsActive(prefs.getString("schedule", "") ?: "")) return
        showRecoveryNotification(context)
    }

    private fun showRecoveryNotification(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val channelId = "monitor_recovery"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Recuperação do monitoramento",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Avisa quando o Android exige ação do usuário para reabrir a câmera após reinício."
                },
            )
        }
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("resume_monitor", true)
        }
        val pending = PendingIntent.getActivity(
            context,
            7302,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("Monitoramento pronto para retomar")
            .setContentText("O Android exige abrir o app para liberar a câmera após o reinício.")
            .setStyle(Notification.BigTextStyle().bigText("O horário configurado está ativo. Toque para reabrir o Vigia IA e retomar câmera + IA."))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()
        manager.notify(7302, notification)
    }

    private fun scheduleIsActive(raw: String): Boolean {
        if (raw.isBlank()) return true
        return try {
            val json = JSONObject(raw)
            if (!json.optBoolean("enabled", false)) return true
            val weekdays = json.optJSONArray("weekdays") ?: return false
            val allowed = mutableSetOf<Int>()
            for (i in 0 until weekdays.length()) allowed.add(weekdays.optInt(i))
            val start = json.optInt("startMinute", 22 * 60)
            val end = json.optInt("endMinute", 6 * 60)
            val cal = Calendar.getInstance()
            val weekday = when (cal.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                else -> 7
            }
            val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            if (start == end) return allowed.contains(weekday)
            if (start < end) return allowed.contains(weekday) && minute >= start && minute < end
            if (minute >= start) return allowed.contains(weekday)
            if (minute < end) {
                val previous = if (weekday == 1) 7 else weekday - 1
                return allowed.contains(previous)
            }
            false
        } catch (_: Throwable) {
            true
        }
    }
}
