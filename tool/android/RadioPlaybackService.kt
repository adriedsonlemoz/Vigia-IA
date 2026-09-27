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
        const val actionPause = "com.vigiaia.app.RADIO_PAUSE"
        const val actionResume = "com.vigiaia.app.RADIO_RESUME"
        const val actionSetVolume = "com.vigiaia.app.RADIO_SET_VOLUME"
        const val actionStop = "com.vigiaia.app.RADIO_STOP"
        const val extraUrl = "url"
        const val extraName = "name"
        const val extraVolume = "volume"
        private const val channelId = "vigiaia_radio"
        private const val notificationId = 7302
        @Volatile var station: String = ""
            private set
        @Volatile var state: String = "parado"
            private set
        @Volatile var streamUrl: String = ""
            private set
        @Volatile var volume: Float = 0.8f
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
        if (intent.action == actionPause) {
            val current = player
            if (current == null) {
                state = "parado"
                stopSelf()
                return START_NOT_STICKY
            }
            if (current.isPlaying) current.pause()
            state = "pausado"
            promote()
            return START_NOT_STICKY
        }
        if (intent.action == actionResume) {
            val current = player
            if (current == null) {
                state = "parado"
                stopSelf()
                return START_NOT_STICKY
            }
            try {
                current.start()
                state = "tocando"
                promote()
            } catch (_: IllegalStateException) {
                state = "indisponível"
                stopSelf()
            }
            return START_NOT_STICKY
        }
        if (intent.action == actionSetVolume) {
            volume = intent.getFloatExtra(extraVolume, volume).coerceIn(0f, 1f)
            player?.setVolume(volume, volume)
            return START_NOT_STICKY
        }
        val url = intent.getStringExtra(extraUrl).orEmpty()
        val parsed = android.net.Uri.parse(url)
        if (parsed.scheme !in listOf("https", "http") || parsed.host.isNullOrBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        station = intent.getStringExtra(extraName)?.take(80).orEmpty().ifBlank { "Rádio online" }
        streamUrl = url
        volume = intent.getFloatExtra(extraVolume, volume).coerceIn(0f, 1f)
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
                setVolume(RadioPlaybackService.volume, RadioPlaybackService.volume)
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
        val toggleAction = if (state == "tocando") actionPause else actionResume
        val toggleLabel = if (state == "tocando") "Pausar" else "Continuar"
        val toggleIcon = if (state == "tocando") android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        val toggle = PendingIntent.getService(this, 2,
            Intent(this, RadioPlaybackService::class.java).setAction(toggleAction),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Vigia IA · $station")
            .setContentText(when (state) {
                "tocando" -> "Rádio ao vivo"
                "pausado" -> "Reprodução pausada"
                else -> "Conectando ao stream…"
            })
            .setContentIntent(open)
            .addAction(toggleIcon, toggleLabel, toggle)
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
        streamUrl = ""
        state = "parado"
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
