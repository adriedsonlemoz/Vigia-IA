package com.vigiaia.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession

/**
 * Streaming de rádio escolhido pelo usuário, reproduzido com Media3/ExoPlayer.
 *
 * - Foco de áudio, "ruído" ao desconectar fones e wake lock ficam a cargo do ExoPlayer.
 * - MediaSession expõe os controles na tela de bloqueio, no sistema e nos fones.
 * - Metadados ICY (música/artista) são publicados em [nowPlaying].
 * - Falhas do stream têm reconexão automática; sem rede o serviço aguarda a rede voltar.
 */
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
        private const val connectWatchdogMs = 30_000L
        private const val networkGiveUpMs = 5 * 60_000L
        private const val maxReconnectAttempts = 3
        private const val liveRestartAfterPauseMs = 5_000L
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
        @Volatile var nowPlaying: String = ""
            private set
    }

    private var player: ExoPlayer? = null
    private var mediaSession: MediaSession? = null
    private var reconnectAttempts = 0
    private var waitingForNetwork = false
    private var pausedAt = 0L
    private var connectivity: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private val handler = Handler(Looper.getMainLooper())

    private val usageTick = object : Runnable {
        override fun run() {
            if (state == "tocando") {
                val effectiveBitrate = bitrateKbps.takeIf { it > 0 } ?: 96
                estimatedBytes += (effectiveBitrate.toLong() * 1000L / 8L) * 5L
            }
            handler.postDelayed(this, 5000L)
        }
    }

    private val reconnectTask = Runnable {
        if (state == "conectando" && streamUrl.isNotBlank()) startPlayback()
    }

    private val connectWatchdog = Runnable {
        if (state == "conectando" && !waitingForNetwork) handleStreamFailure()
    }

    private val giveUpTask = Runnable {
        if (waitingForNetwork) giveUp()
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            val current = player ?: return
            when (playbackState) {
                Player.STATE_ENDED -> handleStreamFailure()
                Player.STATE_IDLE -> {
                    // Parada externa (ex.: comando "stop" de um controle de mídia).
                    if (current.playerError == null && (state == "tocando" || state == "pausado")) {
                        stopSelf()
                    }
                }
                else -> syncState()
            }
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            syncState()
        }

        override fun onPlayerError(error: PlaybackException) {
            handleStreamFailure()
        }

        override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
            updateNowPlaying(mediaMetadata)
        }
    }

    private val networkListener = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            handler.post { onNetworkBack() }
        }
    }

    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(channelId, "Rádio online", NotificationManager.IMPORTANCE_LOW),
        )
        try {
            val manager = getSystemService(ConnectivityManager::class.java)
            connectivity = manager
            manager?.registerDefaultNetworkCallback(networkListener)
            networkCallback = networkListener
        } catch (_: Exception) {
            networkCallback = null
        }
        handler.postDelayed(usageTick, 5000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == actionStop || intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent.action == actionPause) {
            if (player == null) {
                state = "parado"
                stopSelf()
                return START_NOT_STICKY
            }
            pausePlayback()
            return START_NOT_STICKY
        }
        if (intent.action == actionResume) {
            if (player == null && streamUrl.isNotBlank()) {
                reconnectAttempts = 0
                startPlayback()
            } else if (player == null) {
                state = "parado"
                stopSelf()
            } else {
                resumePlayback()
            }
            return START_NOT_STICKY
        }
        if (intent.action == actionSetVolume) {
            volume = intent.getFloatExtra(extraVolume, volume).coerceIn(0f, 1f)
            player?.volume = volume
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
        reconnectAttempts = 0
        startPlayback()
        return START_NOT_STICKY
    }

    /** Conecta (ou reconecta) ao stream atual reaproveitando o mesmo player. */
    private fun startPlayback() {
        handler.removeCallbacks(reconnectTask)
        handler.removeCallbacks(giveUpTask)
        waitingForNetwork = false
        nowPlaying = ""
        state = "conectando"
        promote()
        try {
            val current = ensurePlayer()
            current.volume = volume
            current.setMediaItem(buildMediaItem())
            current.prepare()
            current.play()
            scheduleWatchdog()
        } catch (_: Exception) {
            handleStreamFailure()
        }
    }

    private fun ensurePlayer(): ExoPlayer {
        player?.let { return it }
        val dataSource = DefaultHttpDataSource.Factory()
            .setUserAgent("VigiaIA-Radio")
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(15_000)
        val created = ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource))
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                true,
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
        created.addListener(playerListener)
        player = created
        mediaSession = MediaSession.Builder(this, created)
            .setId("vigiaia_radio")
            .setSessionActivity(openAppIntent())
            .build()
        return created
    }

    private fun buildMediaItem(): MediaItem =
        MediaItem.Builder()
            .setUri(streamUrl)
            .setMediaMetadata(MediaMetadata.Builder().setTitle(station).build())
            .build()

    private fun pausePlayback() {
        val current = player ?: return
        current.pause()
        pausedAt = SystemClock.elapsedRealtime()
        state = "pausado"
        cancelWatchdog()
        promote()
    }

    private fun resumePlayback() {
        val current = player
        if (current == null) {
            if (streamUrl.isNotBlank()) startPlayback() else stopSelf()
            return
        }
        // Rádio ao vivo: depois de uma pausa longa (ou erro) reconecta em vez de tocar o buffer antigo.
        val stale = SystemClock.elapsedRealtime() - pausedAt > liveRestartAfterPauseMs
        if (current.playerError != null || stale) {
            reconnectAttempts = 0
            startPlayback()
            return
        }
        current.play()
        syncState()
    }

    /** Alinha o estado exposto ao Dart com o estado real do ExoPlayer. */
    private fun syncState() {
        val current = player ?: return
        if (current.playerError != null) return
        val next = when {
            current.playbackState == Player.STATE_IDLE -> return
            current.playbackState == Player.STATE_ENDED -> return
            !current.playWhenReady -> "pausado"
            current.playbackState == Player.STATE_READY -> "tocando"
            else -> "conectando"
        }
        if (next == state) return
        state = next
        when (next) {
            "tocando" -> {
                reconnectAttempts = 0
                cancelWatchdog()
            }
            "pausado" -> {
                pausedAt = SystemClock.elapsedRealtime()
                cancelWatchdog()
            }
            else -> scheduleWatchdog()
        }
        promote()
    }

    private fun updateNowPlaying(metadata: MediaMetadata) {
        val title = metadata.title?.toString()?.trim().orEmpty()
        val artist = metadata.artist?.toString()?.trim().orEmpty()
        val text = when {
            title.isBlank() || title == station -> ""
            artist.isNotBlank() -> "$artist - $title"
            else -> title
        }.take(160)
        if (text == nowPlaying) return
        nowPlaying = text
        if (state == "tocando") promote()
    }

    /** Tenta reconectar; sem rede aguarda; esgotadas as tentativas, mantém "indisponível". */
    private fun handleStreamFailure() {
        cancelWatchdog()
        if (state == "pausado") return
        if (!isNetworkAvailable()) {
            waitForNetwork()
            return
        }
        if (reconnectAttempts < maxReconnectAttempts && streamUrl.isNotBlank()) {
            reconnectAttempts += 1
            state = "conectando"
            promote()
            handler.removeCallbacks(reconnectTask)
            handler.postDelayed(reconnectTask, 2000L * reconnectAttempts)
            return
        }
        giveUp()
    }

    private fun waitForNetwork() {
        handler.removeCallbacks(reconnectTask)
        waitingForNetwork = true
        state = "conectando"
        promote()
        handler.removeCallbacks(giveUpTask)
        handler.postDelayed(giveUpTask, networkGiveUpMs)
    }

    private fun onNetworkBack() {
        if (!waitingForNetwork) return
        handler.removeCallbacks(giveUpTask)
        reconnectAttempts = 0
        startPlayback()
    }

    private fun isNetworkAvailable(): Boolean {
        val manager = connectivity ?: return true
        val active = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(active) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun giveUp() {
        state = "indisponível"
        stopForeground(Service.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun scheduleWatchdog() {
        handler.removeCallbacks(connectWatchdog)
        handler.postDelayed(connectWatchdog, connectWatchdogMs)
    }

    private fun cancelWatchdog() {
        handler.removeCallbacks(connectWatchdog)
    }

    private fun openAppIntent(): PendingIntent =
        PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun promote() {
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, RadioPlaybackService::class.java).setAction(actionStop),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val toggleAction = if (state == "tocando") actionPause else actionResume
        val toggleLabel = if (state == "tocando") "Pausar" else "Continuar"
        val toggleIcon = if (state == "tocando") {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val toggle = PendingIntent.getService(
            this,
            2,
            Intent(this, RadioPlaybackService::class.java).setAction(toggleAction),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = when {
            state == "tocando" -> nowPlaying.ifBlank { "Rádio ao vivo" }
            state == "pausado" -> "Reprodução pausada"
            waitingForNetwork -> "Aguardando a rede voltar…"
            else -> "Conectando ao stream…"
        }
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Vigia IA · $station")
            .setContentText(text)
            .setContentIntent(openAppIntent())
            .addAction(toggleIcon, toggleLabel, toggle)
            .addAction(android.R.drawable.ic_media_pause, "Parar", stop)
            .setStyle(Notification.MediaStyle().setShowActionsInCompactView(0, 1))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .build()
        startForeground(notificationId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try {
            networkCallback?.let { connectivity?.unregisterNetworkCallback(it) }
        } catch (_: Exception) {
        }
        networkCallback = null
        connectivity = null
        mediaSession?.release()
        mediaSession = null
        player?.let {
            it.removeListener(playerListener)
            it.release()
        }
        player = null
        station = ""
        streamUrl = ""
        bitrateKbps = 0
        nowPlaying = ""
        waitingForNetwork = false
        // Mantém "indisponível" para o painel avisar o usuário; qualquer outro
        // encerramento volta para "parado".
        if (state != "indisponível") state = "parado"
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
