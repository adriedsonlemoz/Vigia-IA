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
class AlertAudioPlayer(
    private val context: Context,
    private val bundledResources: Map<String, Int>,
) {
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
    private var lastErrorCode: String? = null
    private var lastErrorPhase: String? = null
    private var lastMediaWhat: Int? = null
    private var lastMediaExtra: Int? = null
    private var lastPlaybackResult: String? = null
    private var lastPlaybackUsedFallback = false
    private var lastFallbackReason: String? = null
    private var lastFocusResult: Int? = null
    private var lastFocusError: String? = null
    private var lastSource: String? = null
    private var lastFileName: String? = null
    private var lastFileBytes: Long? = null
    private var lastResource: Int? = null
    private var lastResourceError: String? = null
    private val events = ArrayDeque<Map<String, Any?>>()

    private class Request(val slot: String, val override: File?, val resource: Int,
                          val priority: Int, val capturedAt: Long?, val result: MethodChannel.Result) {
        val queuedAt = SystemClock.elapsedRealtime()
        var completed = false
        var attempt = 0
        var usingOverride = override != null
        var phase = "queued"
        val requestId = "${System.currentTimeMillis()}-${SystemClock.elapsedRealtime()}"
        fun complete(handled: Boolean) {
            if (!completed) { completed = true; result.success(handled) }
        }
    }

    fun play(slot: String, override: File?, priority: Int,
             capturedAt: Long?, result: MethodChannel.Result) {
        if (closed || slot.isBlank()) { result.success(false); return }
        val resource = bundledResources[slot] ?: 0
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
        request.phase = "audio_focus"
        lastPlaybackResult = "preparing"
        lastPlaybackUsedFallback = false
        lastFallbackReason = null
        lastError = null
        lastErrorCode = null
        lastErrorPhase = null
        lastMediaWhat = null
        lastMediaExtra = null
        lastFocusError = null
        lastSource = null
        lastFileName = null
        lastFileBytes = null
        lastResource = null
        lastResourceError = null
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
                lastFocusError = throwableLabel(error)
                trace(request, "audio_focus_exception")
                AudioManager.AUDIOFOCUS_REQUEST_FAILED
            }
        lastFocusResult = granted
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            // Alguns fabricantes negam foco transitório mesmo com o app visível.
            // O MediaPlayer ainda pode reproduzir; a ocorrência fica na telemetria.
            focus = null
            trace(request, "audio_focus_not_granted")
        } else {
            lastFocusError = null
            trace(request, "audio_focus_granted")
        }
        prepare(request)
    }

    private fun prepare(request: Request) {
        val attempt = ++request.attempt
        request.phase = "resolve_source"
        lastSource = if (request.usingOverride) "override" else "bundled"
        armTimeout(request, 5000, "prepare_timeout")
        io.execute {
            val file = try {
                if (request.usingOverride) request.override else bundledFile(request)
            } catch (error: Exception) {
                lastResourceError = "${error.javaClass.simpleName}: ${error.message}"
                null
            }
            main.post {
                if (active !== request || request.completed || closed || attempt != request.attempt) return@post
                if (file == null || !file.exists() || file.length() == 0L) {
                    fail(request, "audio_file_unavailable", code = "FILE_UNAVAILABLE")
                    return@post
                }
                lastFileName = file.name
                lastFileBytes = file.length()
                request.phase = "configure_player"
                trace(request, "source_ready")
                try {
                    val next = MediaPlayer()
                    player = next
                    next.setAudioAttributes(attributes)
                    next.setVolume(1f, 1f)
                    request.phase = "set_data_source"
                    next.setDataSource(file.absolutePath)
                    next.setOnPreparedListener { prepared ->
                        if (active !== request || player !== prepared) return@setOnPreparedListener
                        val capturedAt = request.capturedAt
                        if (capturedAt != null && System.currentTimeMillis() - capturedAt > 5000) {
                            finish(request, true, "expired_before_start")
                            return@setOnPreparedListener
                        }
                        try {
                            request.phase = "start"
                            prepared.start()
                            state = "playing"
                            lastPlaybackResult = "playing"
                            trace(request, "started", prepared.routedDevice?.type)
                            armTimeout(request, (prepared.duration.toLong() + 3000).coerceIn(4000, 65000), "playback_timeout")
                        } catch (error: Exception) {
                            fail(request, "start: ${throwableLabel(error)}", code = "START_EXCEPTION")
                        }
                    }
                    next.setOnCompletionListener {
                        if (active === request && player === it) finish(request, true, "completed")
                    }
                    next.setOnErrorListener { failed, what, extra ->
                        if (active === request && player === failed) {
                            lastMediaWhat = what
                            lastMediaExtra = extra
                            fail(
                                request,
                                "${mediaErrorName(what)} / ${mediaErrorExtraName(extra)}",
                                code = mediaErrorExtraName(extra),
                            )
                        }
                        true
                    }
                    request.phase = "prepare_async"
                    next.prepareAsync()
                } catch (error: Exception) {
                    fail(request, "prepare: ${throwableLabel(error)}", code = "PREPARE_EXCEPTION")
                }
            }
        }
    }

    private fun bundledFile(request: Request): File? {
        lastResource = request.resource
        if (request.resource == 0) {
            lastResourceError = if (bundledResources.containsKey(request.slot)) {
                "resource_id_zero:${request.slot}"
            } else {
                "slot_not_mapped:${request.slot}"
            }
            return null
        }
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
        lastResourceError = null
        return target
    }

    private fun fail(
        request: Request,
        reason: String,
        retryBundled: Boolean = true,
        code: String = "PLAYBACK_FAILED",
    ) {
        if (active !== request) return
        lastError = reason
        lastErrorCode = code
        lastErrorPhase = request.phase
        lastPlaybackResult = "failed"
        trace(request, "error:$reason")
        releasePlayer()
        if (retryBundled && request.usingOverride && request.resource != 0) {
            lastPlaybackUsedFallback = true
            lastFallbackReason = reason
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
        lastPlaybackResult = reason
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
        events.addLast(mapOf("timestampMs" to now, "requestId" to request.requestId,
            "slot" to request.slot, "event" to event, "phase" to request.phase,
            "source" to if (request.usingOverride) "override" else "bundled",
            "attempt" to request.attempt, "priority" to request.priority, "routeType" to route,
            "fileName" to lastFileName, "fileBytes" to lastFileBytes,
            "mediaVolume" to audio.getStreamVolume(AudioManager.STREAM_MUSIC),
            "mediaMaxVolume" to audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
            "mediaMuted" to audio.isStreamMute(AudioManager.STREAM_MUSIC),
            "frameToEventMs" to request.capturedAt?.let { now - it },
            "requestToEventMs" to SystemClock.elapsedRealtime() - request.queuedAt))
        while (events.size > 60) events.removeFirst()
    }

    fun diagnostics(): Map<String, Any?> = mapOf(
        "state" to state, "lastError" to lastError, "activeSlot" to active?.slot,
        "lastErrorCode" to lastErrorCode, "lastErrorPhase" to lastErrorPhase,
        "lastMediaWhat" to lastMediaWhat, "lastMediaExtra" to lastMediaExtra,
        "lastMediaWhatName" to lastMediaWhat?.let(::mediaErrorName),
        "lastMediaExtraName" to lastMediaExtra?.let(::mediaErrorExtraName),
        "lastPlaybackResult" to lastPlaybackResult,
        "lastPlaybackUsedFallback" to lastPlaybackUsedFallback,
        "lastFallbackReason" to lastFallbackReason,
        "lastFocusResult" to lastFocusResult,
        "lastFocusResultName" to focusResultName(lastFocusResult),
        "lastFocusError" to lastFocusError,
        "lastSource" to lastSource, "lastFileName" to lastFileName,
        "lastFileBytes" to lastFileBytes,
        "lastResource" to lastResource, "lastResourceError" to lastResourceError,
        "bundledResourceCount" to bundledResources.size,
        "bundledMissingSlots" to bundledResources.filterValues { it == 0 }.keys.sorted(),
        "pendingSlot" to pending?.slot, "activePriority" to active?.priority, "usage" to "USAGE_MEDIA",
        "mediaVolume" to audio.getStreamVolume(AudioManager.STREAM_MUSIC),
        "mediaMaxVolume" to audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
        "mediaMuted" to audio.isStreamMute(AudioManager.STREAM_MUSIC),
        "ringerMode" to audio.ringerMode,
        "interruptionFilter" to context.getSystemService(NotificationManager::class.java).currentInterruptionFilter,
        "audioMode" to audio.mode,
        "musicActive" to audio.isMusicActive,
        "speakerphoneOn" to audio.isSpeakerphoneOn,
        "availableOutputTypes" to audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type },
        "events" to events.toList()
    )

    private fun throwableLabel(error: Throwable): String =
        "${error.javaClass.simpleName}: ${error.message ?: "sem mensagem"}"

    private fun focusResultName(value: Int?): String? = when (value) {
        AudioManager.AUDIOFOCUS_REQUEST_GRANTED -> "GRANTED"
        AudioManager.AUDIOFOCUS_REQUEST_DELAYED -> "DELAYED"
        AudioManager.AUDIOFOCUS_REQUEST_FAILED -> "FAILED"
        null -> null
        else -> "UNKNOWN_$value"
    }

    private fun mediaErrorName(value: Int): String = when (value) {
        MediaPlayer.MEDIA_ERROR_UNKNOWN -> "MEDIA_ERROR_UNKNOWN"
        MediaPlayer.MEDIA_ERROR_SERVER_DIED -> "MEDIA_ERROR_SERVER_DIED"
        else -> "MEDIA_ERROR_WHAT_$value"
    }

    private fun mediaErrorExtraName(value: Int): String = when (value) {
        -1004 -> "MEDIA_ERROR_IO"
        -1007 -> "MEDIA_ERROR_MALFORMED"
        -1010 -> "MEDIA_ERROR_UNSUPPORTED"
        -110 -> "MEDIA_ERROR_TIMED_OUT"
        Int.MIN_VALUE -> "MEDIA_ERROR_SYSTEM"
        0 -> "MEDIA_ERROR_EXTRA_NONE"
        else -> "MEDIA_ERROR_EXTRA_$value"
    }
}
