package com.vigiaia.app

import android.content.Context
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Um player e uma próxima mensagem, sem fila de alertas antigos. */
class AlertAudioPlayer(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val audio = context.getSystemService(AudioManager::class.java)
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private var active: Request? = null
    private var pending: Request? = null
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var timeout: Runnable? = null
    private var closed = false
    private var state = "idle"
    private var lastError: String? = null
    private val events = ArrayDeque<Map<String, Any?>>()

    private class Request(val slot: String, val override: File?, val resource: Int,
                          val priority: Int, val capturedAt: Long?, val result: MethodChannel.Result) {
        val queuedAt = SystemClock.elapsedRealtime()
        var completed = false
        var attempt = 0
        var usingOverride = override != null
        fun complete(handled: Boolean) {
            if (!completed) { completed = true; result.success(handled) }
        }
    }

    fun play(slot: String, override: File?, resource: Int, priority: Int,
             capturedAt: Long?, result: MethodChannel.Result) {
        if (closed || slot.isBlank()) { result.success(false); return }
        val request = Request(slot, override, resource, priority, capturedAt, result)
        val current = active
        if (current != null) {
            if (priority < current.priority || (slot == current.slot && priority <= current.priority)) {
                trace(request, "suppressed_priority_or_duplicate")
                request.complete(true)
                return
            }
            if (priority > current.priority || priority == 2) {
                stop("preempted")
            } else {
                pending?.complete(true)
                pending = request
                trace(request, "queued_latest")
                return
            }
        }
        begin(request)
    }

    private fun begin(request: Request) {
        active = request
        state = "preparing"
        trace(request, state)
        val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener({ change ->
                if (active === request && (change == AudioManager.AUDIOFOCUS_LOSS ||
                    change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT)) stop("focus_lost")
            }, main).build()
        focus = focusRequest
        val granted = try { audio.requestAudioFocus(focusRequest) }
            catch (error: Exception) {
                fail(request, "audio_focus: ${error.message}", retryBundled = false)
                return
            }
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            fail(request, "audio_focus_denied", retryBundled = false)
            return
        }
        prepare(request)
    }

    private fun prepare(request: Request) {
        val attempt = ++request.attempt
        armTimeout(request, 5000, "prepare_timeout")
        io.execute {
            val file = try {
                if (request.usingOverride) request.override else bundledFile(request)
            } catch (_: Exception) { null }
            main.post {
                if (active !== request || request.completed || closed || attempt != request.attempt) return@post
                if (file == null || !file.exists() || file.length() == 0L) {
                    fail(request, "audio_file_unavailable")
                    return@post
                }
                try {
                    val next = MediaPlayer()
                    player = next
                    next.setAudioAttributes(attributes)
                    next.setVolume(1f, 1f)
                    next.setDataSource(file.absolutePath)
                    next.setOnPreparedListener { prepared ->
                        if (active !== request || player !== prepared) return@setOnPreparedListener
                        val capturedAt = request.capturedAt
                        if (capturedAt != null && System.currentTimeMillis() - capturedAt > 5000) {
                            finish(request, true, "expired_before_start")
                            return@setOnPreparedListener
                        }
                        try {
                            prepared.start()
                            state = "playing"
                            lastError = null
                            trace(request, "started", prepared.routedDevice?.type)
                            armTimeout(request, (prepared.duration.toLong() + 3000).coerceIn(4000, 65000), "playback_timeout")
                        } catch (error: Exception) { fail(request, "start: ${error.message}") }
                    }
                    next.setOnCompletionListener {
                        if (active === request && player === it) finish(request, true, "completed")
                    }
                    next.setOnErrorListener { failed, what, extra ->
                        if (active === request && player === failed) fail(request, "media_error:$what/$extra")
                        true
                    }
                    next.prepareAsync()
                } catch (error: Exception) { fail(request, "prepare: ${error.message}") }
            }
        }
    }

    private fun bundledFile(request: Request): File? {
        if (request.resource == 0) return null
        // O carimbo muda em uma atualização do APK; não reusa áudio de versão anterior.
        val stamp = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        val directory = File(context.cacheDir, "bundled_alert_audio/$stamp").also { it.mkdirs() }
        val target = File(directory, "${request.slot}.m4a")
        if (target.exists() && target.length() > 0) return target
        val temporary = File(directory, ".${request.slot}.tmp")
        context.resources.openRawResource(request.resource).use { input ->
            temporary.outputStream().use { output -> input.copyTo(output) }
        }
        if (temporary.length() == 0L) { temporary.delete(); return null }
        if (!temporary.renameTo(target)) { temporary.copyTo(target, overwrite = true); temporary.delete() }
        return target
    }

    private fun fail(request: Request, reason: String, retryBundled: Boolean = true) {
        if (active !== request) return
        lastError = reason
        trace(request, "error:$reason")
        releasePlayer()
        if (retryBundled && request.usingOverride && request.resource != 0) {
            request.usingOverride = false
            trace(request, "fallback_bundled")
            prepare(request)
        } else {
            finish(request, false, "failed") // Dart recebe a falha, inclusive a assíncrona.
        }
    }

    private fun armTimeout(request: Request, delay: Long, reason: String) {
        timeout?.let { main.removeCallbacks(it) }
        timeout = Runnable { if (active === request) fail(request, reason) }
        main.postDelayed(timeout!!, delay)
    }

    private fun releasePlayer() {
        timeout?.let { main.removeCallbacks(it) }; timeout = null
        player?.let {
            it.setOnPreparedListener(null); it.setOnCompletionListener(null); it.setOnErrorListener(null)
            try { it.stop() } catch (_: Exception) {}
            it.release()
        }
        player = null
    }

    private fun finish(request: Request, handled: Boolean, reason: String) {
        if (active !== request) return
        trace(request, reason)
        releasePlayer()
        focus?.let { audio.abandonAudioFocusRequest(it) }; focus = null
        active = null
        state = reason
        request.complete(handled)
        val next = pending
        pending = null
        if (next != null) {
            if (SystemClock.elapsedRealtime() - next.queuedAt > 3000) {
                trace(next, "expired_queue"); next.complete(true)
            } else begin(next)
        }
    }

    fun stop(reason: String = "stopped") {
        pending?.complete(true); pending = null
        active?.let { finish(it, true, reason) }
    }

    fun close() { closed = true; stop("disposed"); io.shutdownNow() }

    private fun trace(request: Request, event: String, route: Int? = null) {
        val now = System.currentTimeMillis()
        events.addLast(mapOf("timestampMs" to now, "slot" to request.slot,
            "event" to event, "priority" to request.priority, "routeType" to route,
            "mediaVolume" to audio.getStreamVolume(AudioManager.STREAM_MUSIC),
            "mediaMuted" to audio.isStreamMute(AudioManager.STREAM_MUSIC),
            "frameToEventMs" to request.capturedAt?.let { now - it },
            "requestToEventMs" to SystemClock.elapsedRealtime() - request.queuedAt))
        while (events.size > 60) events.removeFirst()
    }

    fun diagnostics(): Map<String, Any?> = mapOf(
        "state" to state, "lastError" to lastError, "activeSlot" to active?.slot,
        "pendingSlot" to pending?.slot, "activePriority" to active?.priority, "usage" to "USAGE_MEDIA",
        "mediaVolume" to audio.getStreamVolume(AudioManager.STREAM_MUSIC),
        "mediaMaxVolume" to audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
        "mediaMuted" to audio.isStreamMute(AudioManager.STREAM_MUSIC),
        "ringerMode" to audio.ringerMode,
        "interruptionFilter" to context.getSystemService(NotificationManager::class.java).currentInterruptionFilter,
        "availableOutputTypes" to audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type },
        "events" to events.toList()
    )
}
