package com.vigiaia.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock

class MonitoringForegroundService : Service() {
    companion object {
        const val channelId = "monitoramento_ia"
        const val notificationId = 7301
        const val extraUsesCamera = "uses_camera"
        const val extraStatusText = "status_text"
        const val defaultStatusText = "Serviço de monitoramento ativo."

        @Volatile var isRunning: Boolean = false
            private set
        @Volatile var usesCamera: Boolean = false
            private set
        @Volatile var startedAtElapsedRealtime: Long = 0L
            private set
        @Volatile var lastStatusText: String = defaultStatusText
            private set

        fun updateNotification(context: Context, text: String) {
            lastStatusText = text.ifBlank { defaultStatusText }
            if (!isRunning) return
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(notificationId, buildNotification(context, lastStatusText))
        }

        private fun buildNotification(context: Context, text: String): Notification {
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return Notification.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.presence_video_online)
                .setContentTitle("Vigia IA ativo")
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var foregroundStarted = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "VigiaIA:BackgroundMonitor",
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
        startedAtElapsedRealtime = SystemClock.elapsedRealtime()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        val camera = intent?.getBooleanExtra(extraUsesCamera, usesCamera) ?: usesCamera
        usesCamera = camera
        val text = intent?.getStringExtra(extraStatusText)
            ?.takeIf { it.isNotBlank() }
            ?: if (camera) {
                "Monitoramento ativo. A câmera pode continuar com o app minimizado."
            } else {
                "Monitoramento ativo em segundo plano."
            }
        lastStatusText = text
        promoteToForeground(camera, buildNotification(this, text))
        return START_NOT_STICKY
    }

    private fun promoteToForeground(camera: Boolean, notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val type = when {
                camera -> ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                Build.VERSION.SDK_INT >= 34 -> ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                else -> 0
            }
            startForeground(notificationId, notification, type)
        } else {
            startForeground(notificationId, notification)
        }
        foregroundStarted = true
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Não tenta reabrir a câmera a partir do background. Android 14+ bloqueia
        // a criação de um FGS de câmera fora de uma Activity visível. Em vez disso,
        // a recuperação solicita uma ação explícita do usuário quando necessário.
        sendBroadcast(Intent(this, MonitorRecoveryReceiver::class.java).apply {
            action = "com.vigiaia.app.RECOVER_MONITOR"
        })
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        usesCamera = false
        startedAtElapsedRealtime = 0L
        lastStatusText = defaultStatusText
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (foregroundStarted) {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        foregroundStarted = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            channelId,
            "Monitoramento em segundo plano",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Indica quando o Vigia IA mantém um monitoramento ativo em primeiro plano."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
