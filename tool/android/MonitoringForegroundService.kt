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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock

class MonitoringForegroundService : Service() {
    data class Lease(
        val usesCamera: Boolean,
        var statusText: String,
    )

    companion object {
        const val channelId = "monitoramento_ia"
        const val notificationId = 7301
        const val extraUsesCamera = "uses_camera"
        const val extraStatusText = "status_text"
        const val extraOwner = "owner"
        const val actionAcquire = "com.vigiaia.app.MONITOR_ACQUIRE"
        const val actionRelease = "com.vigiaia.app.MONITOR_RELEASE"
        const val defaultStatusText = "Serviço de monitoramento ativo."

        private const val heartbeatStaleMs = 15_000L
        private const val orphanStopMs = 60_000L
        private val leases = linkedMapOf<String, Lease>()

        @Volatile var isRunning: Boolean = false
            private set
        @Volatile var usesCamera: Boolean = false
            private set
        @Volatile var startedAtElapsedRealtime: Long = 0L
            private set
        @Volatile var lastStatusText: String = defaultStatusText
            private set
        @Volatile var lastFlutterHeartbeatElapsedRealtime: Long = 0L
            private set
        @Volatile var leaseCount: Int = 0
            private set

        fun flutterHeartbeatFresh(): Boolean {
            if (!isRunning || lastFlutterHeartbeatElapsedRealtime <= 0L) return false
            return SystemClock.elapsedRealtime() - lastFlutterHeartbeatElapsedRealtime <= heartbeatStaleMs
        }

        fun recordFlutterHeartbeat(context: Context) {
            lastFlutterHeartbeatElapsedRealtime = SystemClock.elapsedRealtime()
            if (isRunning && lastStatusText.contains("sem resposta", ignoreCase = true)) {
                val text = synchronized(leases) {
                    leases.values.lastOrNull()?.statusText ?: defaultStatusText
                }
                updateNotification(context, text)
            }
        }

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
    private val handler = Handler(Looper.getMainLooper())
    private val healthCheck = object : Runnable {
        override fun run() {
            if (!isRunning) return
            val now = SystemClock.elapsedRealtime()
            val reference = if (lastFlutterHeartbeatElapsedRealtime > 0L) {
                lastFlutterHeartbeatElapsedRealtime
            } else {
                startedAtElapsedRealtime
            }
            val age = now - reference
            if (age > heartbeatStaleMs) {
                updateNotification(
                    this@MonitoringForegroundService,
                    "Serviço Android ativo • Vigia IA sem resposta; abra o app para confirmar câmera e IA.",
                )
            }
            if (age > orphanStopMs) {
                sendBroadcast(Intent(this@MonitoringForegroundService, MonitorRecoveryReceiver::class.java).apply {
                    action = "com.vigiaia.app.RECOVER_MONITOR"
                })
                stopSelf()
                return
            }
            handler.postDelayed(this, 5_000L)
        }
    }

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
        handler.postDelayed(healthCheck, 5_000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        if (intent == null) {
            // Reinício START_STICKY após o processo Flutter ter sido removido.
            // Não afirmamos que câmera/IA continuam funcionando.
            synchronized(leases) { leases.clear() }
            usesCamera = false
            leaseCount = 0
            lastStatusText = "Serviço reiniciado • abra o Vigia IA para retomar câmera e IA."
            promoteToForeground(false, buildNotification(this, lastStatusText))
            return START_STICKY
        }

        when (intent.action) {
            actionRelease -> {
                val owner = intent.getStringExtra(extraOwner).orEmpty()
                if (owner.isNotBlank()) {
                    synchronized(leases) { leases.remove(owner) }
                }
                if (!refreshFromLeases()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
            else -> {
                val owner = intent.getStringExtra(extraOwner).orEmpty().ifBlank { "legacy" }
                val camera = intent.getBooleanExtra(extraUsesCamera, true)
                val text = intent.getStringExtra(extraStatusText)
                    ?.takeIf { it.isNotBlank() }
                    ?: if (camera) {
                        "Monitoramento ativo • câmera em uso."
                    } else {
                        "Monitoramento ativo em segundo plano."
                    }
                synchronized(leases) { leases[owner] = Lease(camera, text) }
                lastFlutterHeartbeatElapsedRealtime = SystemClock.elapsedRealtime()
                refreshFromLeases()
            }
        }
        return START_STICKY
    }

    private fun refreshFromLeases(): Boolean {
        val snapshot = synchronized(leases) { leases.values.toList() }
        leaseCount = snapshot.size
        if (snapshot.isEmpty()) {
            usesCamera = false
            return false
        }
        usesCamera = snapshot.any { it.usesCamera }
        val text = snapshot.last().statusText.ifBlank { defaultStatusText }
        lastStatusText = text
        promoteToForeground(usesCamera, buildNotification(this, text))
        return true
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
        sendBroadcast(Intent(this, MonitorRecoveryReceiver::class.java).apply {
            action = "com.vigiaia.app.RECOVER_MONITOR"
        })
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        synchronized(leases) { leases.clear() }
        isRunning = false
        usesCamera = false
        leaseCount = 0
        startedAtElapsedRealtime = 0L
        lastFlutterHeartbeatElapsedRealtime = 0L
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
