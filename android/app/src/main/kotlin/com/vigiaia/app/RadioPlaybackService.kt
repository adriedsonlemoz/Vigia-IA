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
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

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
        const val extraBitrate = "bitrate"
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
        @Volatile var bitrateKbps: Int = 0
            private set
        @Volatile var estimatedBytes: Long = 0L
            private set
    }

    private var player: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private val usageHandler = Handler(Looper.getMainLooper())
    private val usageTick = object : Runnable {
        override fun run() {
            if (state != "tocando") return
            val effectiveBitrate = bitrateKbps.takeIf { it > 0 } ?: 96
            estimatedBytes += (effectiveBitrate.toLong() * 1000L / 8L) * 5L
            usageHandler.postDelayed(this, 5000L)
        }
    }

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
            stopUsageTicker()
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
                startUsageTicker()
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
        bitrateKbps = intent.getIntExtra(extraBitrate, 0).coerceIn(0, 1024)
        state = "conectando"
        promote()
        stopUsageTicker()
        player?.release()
        player = null
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        requestRadioFocus()
        try {
            player = MediaPlayer().apply {
                setAudioStreamType(AudioManager.STREAM_MUSIC)
                setDataSource(url)
                setVolume(RadioPlaybackService.volume, RadioPlaybackService.volume)
                setOnPreparedListener {
                    it.start()
                    state = "tocando"
                    startUsageTicker()
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

    private fun startUsageTicker() {
        usageHandler.removeCallbacks(usageTick)
        usageHandler.postDelayed(usageTick, 5000L)
    }

    private fun requestRadioFocus() {
        val manager = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener { change ->
                    when (change) {
                        AudioManager.AUDIOFOCUS_GAIN ->
                            player?.setVolume(volume, volume)
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                            player?.setVolume(volume * 0.25f, volume * 0.25f)
                        AudioManager.AUDIOFOCUS_LOSS -> stopSelf()
                    }
                }
                .build()
            focusRequest = request
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun stopUsageTicker() {
        usageHandler.removeCallbacks(usageTick)
    }

    override fun onDestroy() {
        stopUsageTicker()
        player?.release()
        player = null
        val manager = audioManager
        val request = focusRequest
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null && request != null) {
            manager.abandonAudioFocusRequest(request)
        } else {
            @Suppress("DEPRECATION")
            manager?.abandonAudioFocus(null)
        }
        focusRequest = null
        audioManager = null
        station = ""
        streamUrl = ""
        bitrateKbps = 0
        state = "parado"
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
