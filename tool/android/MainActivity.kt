package com.vigiaia.app

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.RingtoneManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.os.PowerManager
import android.os.StatFs
import android.os.VibratorManager
import android.os.Vibrator
import android.os.VibrationEffect
import android.provider.Settings
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val backgroundChannelName = "vigiaia/background"
    private val nativeChannelName = "vigiaia/native"
    private var pendingNotificationPermission: MethodChannel.Result? = null
    private var pendingCameraPermission: MethodChannel.Result? = null
    private var pendingLocalNetworkPermission: MethodChannel.Result? = null
    private var cameraPermissionRequestInFlight: Boolean = false
    private var localNetworkPermissionRequestInFlight: Boolean = false
    private var resumeMonitorRequested: Boolean = false

    private val notificationPermissionRequestCode = 4412
    private val cameraPermissionRequestCode = 4413
    private val localNetworkPermissionRequestCode = 4414

    override fun onCreate(savedInstanceState: Bundle?) {
        resumeMonitorRequested = intent?.getBooleanExtra("resume_monitor", false) == true
        super.onCreate(savedInstanceState)
    }

    override fun onPostResume() {
        super.onPostResume()
        maybePromptCameraPermissionOnFirstLaunch()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("resume_monitor", false)) resumeMonitorRequested = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backgroundChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val usesCamera = call.argument<Boolean>("usesCamera") ?: true
                        if (usesCamera && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val statusText = call.argument<String>("statusText")
                            ?: if (usesCamera) "Preparando câmera e IA…" else "Preparando monitoramento…"
                        val serviceIntent = Intent(this, MonitoringForegroundService::class.java).apply {
                            putExtra(MonitoringForegroundService.extraUsesCamera, usesCamera)
                            putExtra(MonitoringForegroundService.extraStatusText, statusText)
                        }
                        try {
                            startForegroundService(serviceIntent)
                            result.success(true)
                        } catch (error: Throwable) {
                            result.error("foreground_service", error.message, null)
                        }
                    }
                    "stop" -> {
                        stopService(Intent(this, MonitoringForegroundService::class.java))
                        result.success(null)
                    }
                    "updateStatus" -> {
                        val text = call.argument<String>("text") ?: MonitoringForegroundService.defaultStatusText
                        MonitoringForegroundService.updateNotification(this, text)
                        result.success(true)
                    }
                    "status" -> {
                        val powerManager = getSystemService(PowerManager::class.java)
                        result.success(mapOf(
                            "running" to MonitoringForegroundService.isRunning,
                            "usesCamera" to MonitoringForegroundService.usesCamera,
                            "statusText" to MonitoringForegroundService.lastStatusText,
                            "startedAtElapsedRealtime" to MonitoringForegroundService.startedAtElapsedRealtime,
                            "screenInteractive" to powerManager.isInteractive,
                        ))
                    }
                    "isRunning" -> result.success(MonitoringForegroundService.isRunning)
                    "consumeResumeRequest" -> {
                        val requested = resumeMonitorRequested || intent?.getBooleanExtra("resume_monitor", false) == true
                        resumeMonitorRequested = false
                        intent?.removeExtra("resume_monitor")
                        result.success(requested)
                    }
                    "configureRecovery" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val schedule = call.argument<String>("schedule") ?: ""
                        getSharedPreferences("monitor_recovery", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("enabled", enabled)
                            .putString("schedule", schedule)
                            .apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativeChannelName)
            .setMethodCallHandler { call, result -> handleNativeCall(call, result) }
    }

    private fun handleNativeCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "protectSecret" -> {
                try {
                    result.success(protectSecret(call.argument<String>("value") ?: ""))
                } catch (error: Throwable) {
                    result.error("keystore_encrypt", error.message, null)
                }
            }
            "unprotectSecret" -> {
                try {
                    result.success(unprotectSecret(call.argument<String>("value") ?: ""))
                } catch (error: Throwable) {
                    result.error("keystore_decrypt", error.message, null)
                }
            }
            "requestCameraPermission" -> requestCameraPermission(result)
            "cameraPermissionStatus" -> result.success(cameraPermissionStatus())
            "openAppSettings" -> {
                openAppSettings()
                result.success(true)
            }
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "notificationsAllowed" -> result.success(notificationsAllowed())
            "localNetworkPermissionStatus" -> result.success(localNetworkPermissionStatus())
            "requestLocalNetworkPermission" -> requestLocalNetworkPermission(result)
            "showAlertNotification" -> {
                try {
                    showAlertNotification(
                        title = call.argument<String>("title") ?: "Vigia IA",
                        message = call.argument<String>("message") ?: "Alerta detectado.",
                        notificationEnabled = call.argument<Boolean>("notification") ?: true,
                        sound = call.argument<Boolean>("sound") ?: false,
                        vibration = call.argument<Boolean>("vibration") ?: false,
                    )
                    result.success(true)
                } catch (error: Throwable) {
                    result.error("notification", error.message, null)
                }
            }
            "systemHealth" -> result.success(readSystemHealth())
            "shareText" -> {
                val subject = call.argument<String>("subject") ?: "Vigia IA - Diagnóstico"
                val text = call.argument<String>("text") ?: ""
                try {
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, subject)
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(shareIntent, "Compartilhar diagnóstico"))
                    result.success(true)
                } catch (error: Throwable) {
                    result.error("share_text", error.message, null)
                }
            }
            "encodeMp4" -> {
                Thread {
                    try {
                        val outputPath = call.argument<String>("outputPath") ?: error("outputPath ausente")
                        val fps = call.argument<Int>("fps") ?: 2
                        @Suppress("UNCHECKED_CAST")
                        val frames = call.argument<List<Map<String, Any?>>>("frames") ?: emptyList()
                        val ok = encodeMp4(outputPath, frames, fps)
                        runOnUiThread { result.success(ok) }
                    } catch (error: Throwable) {
                        runOnUiThread { result.error("mp4_encoder", error.message, null) }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun localNetworkPermissionName(): String? {
        if (Build.VERSION.SDK_INT >= 37) return "android.permission.ACCESS_LOCAL_NETWORK"
        if (Build.VERSION.SDK_INT >= 36) return Manifest.permission.NEARBY_WIFI_DEVICES
        return null
    }

    private fun localNetworkPermissionStatus(): Map<String, Any> {
        val permission = localNetworkPermissionName()
        val required = Build.VERSION.SDK_INT >= 36
        if (permission == null) {
            return mapOf(
                "required" to false,
                "granted" to true,
                "canRequest" to false,
            )
        }
        val granted = checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        return mapOf(
            "required" to required,
            "granted" to granted,
            "canRequest" to !granted && !localNetworkPermissionRequestInFlight,
        )
    }

    private fun requestLocalNetworkPermission(result: MethodChannel.Result) {
        val permission = localNetworkPermissionName()
        if (permission == null) {
            result.success(true)
            return
        }
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (localNetworkPermissionRequestInFlight) {
            result.success(false)
            return
        }
        localNetworkPermissionRequestInFlight = true
        pendingLocalNetworkPermission = result
        requestPermissions(arrayOf(permission), localNetworkPermissionRequestCode)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (pendingNotificationPermission != null) {
            result.success(false)
            return
        }
        pendingNotificationPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequestCode)
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            result.success(false)
            return
        }
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            markCameraPermissionPrompted()
            result.success(true)
            return
        }
        if (cameraPermissionRequestInFlight) {
            if (pendingCameraPermission == null) {
                pendingCameraPermission = result
            } else {
                result.success(false)
            }
            return
        }
        markCameraPermissionPrompted()
        cameraPermissionRequestInFlight = true
        pendingCameraPermission = result
        requestPermissions(arrayOf(Manifest.permission.CAMERA), cameraPermissionRequestCode)
    }

    private fun maybePromptCameraPermissionOnFirstLaunch() {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) return
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            markCameraPermissionPrompted()
            return
        }
        val preferences = getSharedPreferences("runtime_permission_state", Context.MODE_PRIVATE)
        if (preferences.getBoolean("camera_prompted", false) || cameraPermissionRequestInFlight) return
        markCameraPermissionPrompted()
        cameraPermissionRequestInFlight = true
        requestPermissions(arrayOf(Manifest.permission.CAMERA), cameraPermissionRequestCode)
    }

    private fun markCameraPermissionPrompted() {
        getSharedPreferences("runtime_permission_state", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("camera_prompted", true)
            .apply()
    }

    private fun cameraPermissionStatus(): Map<String, Any> {
        val granted = checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        val prompted = getSharedPreferences("runtime_permission_state", Context.MODE_PRIVATE)
            .getBoolean("camera_prompted", false)
        val showRationale = !granted && shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)
        return mapOf(
            "granted" to granted,
            "prompted" to prompted,
            "showRationale" to showRationale,
            "canRequest" to (!granted && (!prompted || showRationale)),
        )
    }

    private fun openAppSettings() {
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        })
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequestCode) {
            pendingNotificationPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingNotificationPermission = null
            return
        }
        if (requestCode == cameraPermissionRequestCode) {
            cameraPermissionRequestInFlight = false
            pendingCameraPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingCameraPermission = null
            return
        }
        if (requestCode == localNetworkPermissionRequestCode) {
            localNetworkPermissionRequestInFlight = false
            pendingLocalNetworkPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingLocalNetworkPermission = null
        }
    }

    private fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return (getSystemService(NotificationManager::class.java)).areNotificationsEnabled()
    }

    private fun showAlertNotification(title: String, message: String, notificationEnabled: Boolean, sound: Boolean, vibration: Boolean) {
        if (!notificationEnabled || !notificationsAllowed()) {
            playDirectAlertOutputs(sound, vibration)
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channelId = "monitor_alert_${if (sound) "s" else "q"}_${if (vibration) "v" else "n"}"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = if (sound || vibration) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(channelId, "Alertas do monitor", importance).apply {
                description = "Alertas de objetos, entrada, saída e integridade da câmera."
                enableVibration(vibration)
                if (sound) setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null) else setSound(null, null)
            }
            manager.createNotificationChannel(channel)
        }
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(this, 9001, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .build()
        manager.notify((System.currentTimeMillis() and 0x7FFFFFFF).toInt(), notification)
    }

    private fun playDirectAlertOutputs(sound: Boolean, vibration: Boolean) {
        if (sound) {
            try {
                RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)).play()
            } catch (_: Throwable) {}
        }
        if (vibration) {
            try {
                val vibrator = if (Build.VERSION.SDK_INT >= 31) {
                    getSystemService(VibratorManager::class.java).defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    getSystemService(VIBRATOR_SERVICE) as Vibrator
                }
                vibrator.vibrate(VibrationEffect.createOneShot(450, VibrationEffect.DEFAULT_AMPLITUDE))
            } catch (_: Throwable) {}
        }
    }

    private fun getSecretKey(): SecretKey {
        val alias = "vigiaia_aes"
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun protectSecret(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = ByteArray(cipher.iv.size + encrypted.size)
        System.arraycopy(cipher.iv, 0, payload, 0, cipher.iv.size)
        System.arraycopy(encrypted, 0, payload, cipher.iv.size, encrypted.size)
        return "gcm:" + Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun unprotectSecret(value: String): String? {
        if (!value.startsWith("gcm:")) return null
        val payload = Base64.decode(value.substring(4), Base64.NO_WRAP)
        if (payload.size <= 12) return null
        val iv = payload.copyOfRange(0, 12)
        val encrypted = payload.copyOfRange(12, payload.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun readSystemHealth(): Map<String, Any?> {
        val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
        val battery = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).takeIf { it >= 0 }
        val intent = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val rawTemperature = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val memoryInfo = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
        val stat = StatFs(filesDir.absolutePath)
        return mapOf(
            "batteryPercent" to battery,
            "batteryTemperatureC" to if (rawTemperature == Int.MIN_VALUE) null else rawTemperature / 10.0,
            "memoryUsedBytes" to memoryInfo.totalPss.toLong() * 1024L,
            "freeStorageBytes" to stat.availableBytes,
            "totalStorageBytes" to stat.totalBytes,
        )
    }

    private fun encodeMp4(outputPath: String, frames: List<Map<String, Any?>>, requestedFps: Int): Boolean {
        if (frames.size < 2) return false
        val width = ((frames.first()["width"] as Number).toInt() and 0xFFFFFFFE.toInt())
        val height = ((frames.first()["height"] as Number).toInt() and 0xFFFFFFFE.toInt())
        if (width < 2 || height < 2) return false
        val fps = requestedFps.coerceIn(1, 12)
        val mime = MediaFormat.MIMETYPE_VIDEO_AVC
        val codecInfo = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.firstOrNull { info ->
            info.isEncoder && info.supportedTypes.any { it.equals(mime, ignoreCase = true) }
        } ?: return false
        val capabilities = codecInfo.getCapabilitiesForType(mime)
        val preferred = listOf(
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar,
        )
        val colorFormat = preferred.firstOrNull { capabilities.colorFormats.contains(it) } ?: return false
        val semiPlanar = colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar

        File(outputPath).parentFile?.mkdirs()
        File(outputPath).delete()
        val format = MediaFormat.createVideoFormat(mime, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
            setInteger(MediaFormat.KEY_BIT_RATE, max(500_000, width * height * fps * 2))
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        val codec = MediaCodec.createByCodecName(codecInfo.name)
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        var muxerStarted = false
        val info = MediaCodec.BufferInfo()
        var completed = false
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            frames.take(120).forEachIndexed { index, frame ->
                val rgb = frame["bytes"] as? ByteArray ?: return@forEachIndexed
                val inIndex = codec.dequeueInputBuffer(20_000)
                if (inIndex >= 0) {
                    val buffer = codec.getInputBuffer(inIndex) ?: return@forEachIndexed
                    buffer.clear()
                    val yuv = rgbToYuv420(rgb, width, height, semiPlanar)
                    if (buffer.remaining() >= yuv.size) buffer.put(yuv)
                    codec.queueInputBuffer(inIndex, 0, yuv.size, index * 1_000_000L / fps, 0)
                }
                while (true) {
                    val outIndex = codec.dequeueOutputBuffer(info, 0)
                    if (outIndex == MediaCodec.INFO_TRY_AGAIN_LATER) break
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (!muxerStarted) {
                            trackIndex = muxer.addTrack(codec.outputFormat)
                            muxer.start()
                            muxerStarted = true
                        }
                        continue
                    }
                    if (outIndex >= 0) {
                        writeOutput(codec, muxer, trackIndex, muxerStarted, outIndex, info)
                    }
                }
            }
            val eosIndex = codec.dequeueInputBuffer(50_000)
            if (eosIndex >= 0) {
                codec.queueInputBuffer(eosIndex, 0, 0, frames.size * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
            var eos = false
            var attempts = 0
            while (!eos && attempts++ < 200) {
                val outIndex = codec.dequeueOutputBuffer(info, 20_000)
                when {
                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> if (!muxerStarted) {
                        trackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outIndex >= 0 -> {
                        eos = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                        writeOutput(codec, muxer, trackIndex, muxerStarted, outIndex, info)
                    }
                }
            }
            completed = muxerStarted && eos
        } finally {
            try { codec.stop() } catch (_: Throwable) {}
            try { codec.release() } catch (_: Throwable) {}
            if (muxerStarted) try { muxer.stop() } catch (_: Throwable) {}
            try { muxer.release() } catch (_: Throwable) {}
        }
        val output = File(outputPath)
        return completed && output.exists() && output.length() > 1024
    }

    private fun writeOutput(codec: MediaCodec, muxer: MediaMuxer, trackIndex: Int, muxerStarted: Boolean, index: Int, info: MediaCodec.BufferInfo) {
        val buffer = codec.getOutputBuffer(index)
        if (buffer != null && info.size > 0 && muxerStarted && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
            buffer.position(info.offset)
            buffer.limit(info.offset + info.size)
            muxer.writeSampleData(trackIndex, buffer, info)
        }
        codec.releaseOutputBuffer(index, false)
    }

    private fun rgbToYuv420(rgb: ByteArray, width: Int, height: Int, semiPlanar: Boolean): ByteArray {
        val frameSize = width * height
        val output = ByteArray(frameSize + frameSize / 2)
        var yIndex = 0
        var uIndex = frameSize
        var vIndex = if (semiPlanar) frameSize + 1 else frameSize + frameSize / 4
        var rgbIndex = 0
        for (j in 0 until height) {
            for (i in 0 until width) {
                val r = rgb[rgbIndex].toInt() and 0xFF
                val g = rgb[rgbIndex + 1].toInt() and 0xFF
                val b = rgb[rgbIndex + 2].toInt() and 0xFF
                rgbIndex += 3
                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                output[yIndex++] = y.coerceIn(0, 255).toByte()
                if (j % 2 == 0 && i % 2 == 0) {
                    if (semiPlanar) {
                        output[uIndex] = u.coerceIn(0, 255).toByte()
                        output[vIndex] = v.coerceIn(0, 255).toByte()
                        uIndex += 2
                        vIndex += 2
                    } else {
                        output[uIndex++] = u.coerceIn(0, 255).toByte()
                        output[vIndex++] = v.coerceIn(0, 255).toByte()
                    }
                }
            }
        }
        return output
    }
}
