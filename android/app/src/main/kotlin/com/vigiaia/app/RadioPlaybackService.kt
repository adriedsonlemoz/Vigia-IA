package com.vigiaia.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder

/** Streaming escolhido pelo usuário; uma notificação permite interromper a reprodução. */
class RadioPlaybackService : Service() {
    companion object {
        const val actionPlay = "com.vigiaia.app.RADIO_PLAY"
        const val actionStop = "com.vigiaia.app.RADIO_STOP"
        const val extraUrl = "url"
        const val extraName = "name"
        private const val channelId = "vigiaia_radio"
        private const val notificationId = 7302
        @Volatile var station: String = ""
            private set
        @Volatile var state: String = "parado"
            private set
    }

    private var player: MediaPlayer? = null
    private var audioManager: AudioManager? = null

    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(channelId, "Rádio online", NotificationManager.IMPORTANCE_LOW)
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == actionStop || intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val url = intent.getStringExtra(extraUrl).orEmpty()
        val parsed = android.net.Uri.parse(url)
        if (parsed.scheme !in listOf("https", "http") || parsed.host.isNullOrBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        station = intent.getStringExtra(extraName)?.take(80).orEmpty().ifBlank { "Rádio online" }
        state = "conectando"
        promote()
        player?.release()
        player = null
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        @Suppress("DEPRECATION")
        audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        try {
            player = MediaPlayer().apply {
                setAudioStreamType(AudioManager.STREAM_MUSIC)
                setDataSource(url)
                setOnPreparedListener {
                    it.start()
                    state = "tocando"
                    promote()
                }
                setOnErrorListener { _, _, _ ->
                    state = "indisponível"
                    stopSelf()
                    true
                }
                prepareAsync()
            }
        } catch (_: Exception) {
            state = "indisponível"
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun promote() {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1,
            Intent(this, RadioPlaybackService::class.java).setAction(actionStop),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Vigia IA · $station")
            .setContentText(if (state == "tocando") "Rádio ao vivo" else "Conectando ao stream…")
            .setContentIntent(open)
            .addAction(android.R.drawable.ic_media_pause, "Parar", stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(notificationId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(notificationId, notification)
        }
    }

    override fun onDestroy() {
        player?.release()
        player = null
        @Suppress("DEPRECATION")
        audioManager?.abandonAudioFocus(null)
        audioManager = null
        station = ""
        state = "parado"
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
