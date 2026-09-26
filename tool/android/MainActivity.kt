package com.vigiaia.app

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.media.RingtoneManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.os.Environment
import android.os.PowerManager
import android.os.SystemClock
import android.os.StatFs
import android.os.VibratorManager
import android.os.Vibrator
import android.os.VibrationEffect
import android.provider.Settings
import android.provider.OpenableColumns
import android.provider.MediaStore
import android.net.Uri
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val backgroundChannelName = "vigiaia/background"
    private val nativeChannelName = "vigiaia/native"
    private val compassChannelName = "vigiaia/compass"
    private var pendingNotificationPermission: MethodChannel.Result? = null
    private var pendingCameraPermission: MethodChannel.Result? = null
    private var pendingLocalNetworkPermission: MethodChannel.Result? = null
    private var cameraPermissionRequestInFlight: Boolean = false
    private var localNetworkPermissionRequestInFlight: Boolean = false
    private var resumeMonitorRequested: Boolean = false
    private val alertAudio by lazy { AlertAudioPlayer(this, AudioResourceCatalog.all) }
    private var monitorFullscreen = false
    private var pendingAudioImportResult: MethodChannel.Result? = null
    private var pendingAudioImportSlot: String? = null
    private var pendingDocumentSaveResult: MethodChannel.Result? = null
    private var pendingOfflineMapImportResult: MethodChannel.Result? = null
    private var pendingDocumentBytes: ByteArray? = null
    private var pendingDocumentMimeType: String? = null
    private var pendingRecordingPermissionResult: MethodChannel.Result? = null
    private var pendingRecordingPermissionSlot: String? = null
    private var audioRecorder: MediaRecorder? = null
    private var audioRecordingTempFile: File? = null
    private var audioRecordingSlot: String? = null
    private var bikeBrightnessOverride: Float? = null
    private var lastCpuWallMs: Long? = null
    private var lastCpuProcessMs: Long? = null
    private var compassStreamHandler: CompassStreamHandler? = null

    private val notificationPermissionRequestCode = 4412
    private val cameraPermissionRequestCode = 4413
    private val localNetworkPermissionRequestCode = 4414
    private val audioImportRequestCode = 4415
    private val recordAudioPermissionRequestCode = 4416
    private val documentSaveRequestCode = 4417
    private val offlineMapImportRequestCode = 4418

    override fun onCreate(savedInstanceState: Bundle?) {
        resumeMonitorRequested = intent?.getBooleanExtra("resume_monitor", false) == true
        super.onCreate(savedInstanceState)
    }

    override fun onPostResume() {
        super.onPostResume()
        volumeControlStream = AudioManager.STREAM_MUSIC
        window.decorView.post { MonitorSystemUi.apply(window, monitorFullscreen) }
    }

    override fun onDestroy() {
        compassStreamHandler?.dispose()
        compassStreamHandler = null
        alertAudio.close()
        try { audioRecorder?.stop() } catch (_: Throwable) {}
        try { audioRecorder?.release() } catch (_: Throwable) {}
        audioRecorder = null
        audioRecordingTempFile?.delete()
        audioRecordingTempFile = null
        audioRecordingSlot = null
        super.onDestroy()
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
                    "acquire", "start" -> {
                        val usesCamera = call.argument<Boolean>("usesCamera") ?: true
                        if (usesCamera && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val owner = call.argument<String>("owner")?.takeIf { it.isNotBlank() } ?: "legacy"
                        val statusText = call.argument<String>("statusText")
                            ?: if (usesCamera) "Preparando câmera e IA…" else "Preparando monitoramento…"
                        val serviceIntent = Intent(this, MonitoringForegroundService::class.java).apply {
                            action = MonitoringForegroundService.actionAcquire
                            putExtra(MonitoringForegroundService.extraOwner, owner)
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
                    "release" -> {
                        val owner = call.argument<String>("owner")?.takeIf { it.isNotBlank() } ?: "legacy"
                        if (MonitoringForegroundService.isRunning) {
                            startService(Intent(this, MonitoringForegroundService::class.java).apply {
                                action = MonitoringForegroundService.actionRelease
                                putExtra(MonitoringForegroundService.extraOwner, owner)
                            })
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        if (MonitoringForegroundService.isRunning) {
                            startService(Intent(this, MonitoringForegroundService::class.java).apply {
                                action = MonitoringForegroundService.actionRelease
                                putExtra(MonitoringForegroundService.extraOwner, "legacy")
                            })
                        }
                        result.success(null)
                    }
                    "heartbeat" -> {
                        MonitoringForegroundService.recordFlutterHeartbeat(this)
                        result.success(true)
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
                            "flutterHeartbeatFresh" to MonitoringForegroundService.flutterHeartbeatFresh(),
                            "lastFlutterHeartbeatElapsedRealtime" to MonitoringForegroundService.lastFlutterHeartbeatElapsedRealtime,
                            "leaseCount" to MonitoringForegroundService.leaseCount,
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

        compassStreamHandler?.dispose()
        compassStreamHandler = CompassStreamHandler(this).also { handler ->
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, compassChannelName)
                .setStreamHandler(handler)
        }
    }

    private fun handleNativeCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "appVersionInfo" -> {
                try {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val versionCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        info.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        info.versionCode.toLong()
                    }
                    result.success(mapOf(
                        "versionName" to (info.versionName ?: ""),
                        "versionCode" to versionCode,
                    ))
                } catch (error: Throwable) {
                    result.error("app_version", error.message, null)
                }
            }
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
            "openExternalUrl" -> {
                val value = call.argument<String>("url")?.trim().orEmpty()
                try {
                    val uri = Uri.parse(value)
                    if (uri.scheme != "https" && uri.scheme != "http") {
                        result.success(false)
                    } else {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(true)
                    }
                } catch (error: Throwable) {
                    result.error("open_external_url", error.message, null)
                }
            }
            "onboardingCompleted" -> result.success(onboardingCompleted())
            "markOnboardingCompleted" -> result.success(markOnboardingCompleted())
            "saveBytesToDownloads" -> {
                val fileName = call.argument<String>("fileName") ?: "vigiaia_relatorio.bin"
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes") ?: byteArrayOf()
                try {
                    result.success(saveBytesToDownloads(fileName, mimeType, bytes))
                } catch (error: Throwable) {
                    result.error("save_downloads", error.message, null)
                }
            }
            "saveBytesWithPicker" -> {
                val fileName = call.argument<String>("fileName") ?: "vigiaia_relatorio.bin"
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes") ?: byteArrayOf()
                beginDocumentSave(fileName, mimeType, bytes, result)
            }
            "pickOfflineMapPackage" -> beginOfflineMapImport(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "notificationsAllowed" -> result.success(notificationsAllowed())
            "localNetworkPermissionStatus" -> result.success(localNetworkPermissionStatus())
            "requestLocalNetworkPermission" -> requestLocalNetworkPermission(result)
            "playCustomAlertAudio" -> {
                val slot = call.argument<String>("slot") ?: ""
                val normalized = normalizeAudioSlot(slot)
                alertAudio.play(normalized, findAudioOverride(normalized),
                    call.argument<Int>("priority") ?: 0,
                    call.argument<Number>("capturedAtMs")?.toLong(), result)
            }
            "stopAlertAudio" -> { alertAudio.stop(); result.success(true) }
            "audioDiagnostics" -> result.success(alertAudio.diagnostics())
            "setMonitorFullscreen" -> {
                monitorFullscreen = call.argument<Boolean>("enabled") ?: false
                MonitorSystemUi.apply(window, monitorFullscreen)
                result.success(true)
            }
            "audioOverrideSlots" -> result.success(listAudioOverrideSlots())
            "importAudioOverride" -> {
                val slot = normalizeAudioSlot(call.argument<String>("slot") ?: "")
                if (slot.isBlank()) result.success(false) else beginAudioImport(slot, result)
            }
            "removeAudioOverride" -> {
                val slot = normalizeAudioSlot(call.argument<String>("slot") ?: "")
                result.success(slot.isNotBlank() && removeAudioOverrides(slot))
            }
            "removeAllAudioOverrides" -> result.success(removeAllAudioOverrides())
            "startAudioRecording" -> {
                val slot = normalizeAudioSlot(call.argument<String>("slot") ?: "")
                if (slot.isBlank()) result.success(false) else requestOrStartAudioRecording(slot, result)
            }
            "stopAudioRecording" -> result.success(stopAudioRecording(call.argument<Boolean>("save") ?: true))
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
            "setBikeScreenBrightness" -> {
                val value = call.argument<Number>("value")?.toFloat()
                setBikeScreenBrightness(value)
                result.success(true)
            }
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
            "canRequest" to (!granted && !localNetworkPermissionRequestInFlight),
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
            return
        }
        if (requestCode == recordAudioPermissionRequestCode) {
            val pending = pendingRecordingPermissionResult
            val slot = pendingRecordingPermissionSlot
            pendingRecordingPermissionResult = null
            pendingRecordingPermissionSlot = null
            if (pending != null) {
                if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && !slot.isNullOrBlank()) {
                    pending.success(startAudioRecordingInternal(slot))
                } else {
                    pending.success(false)
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == audioImportRequestCode) {
            val pending = pendingAudioImportResult
            val slot = pendingAudioImportSlot
            pendingAudioImportResult = null
            pendingAudioImportSlot = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null || slot.isNullOrBlank()) {
                pending.success(false)
                return
            }
            pending.success(copyAudioOverride(slot, data.data!!))
            return
        }
        if (requestCode == offlineMapImportRequestCode) {
            val pending = pendingOfflineMapImportResult
            pendingOfflineMapImportResult = null
            if (pending == null) return
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                pending.success(null)
                return
            }
            Thread {
                val payload = copyOfflineMapToCache(uri)
                runOnUiThread {
                    if (payload == null) {
                        pending.error("offline_map_import", "Não foi possível importar o pacote MBTiles.", null)
                    } else {
                        pending.success(payload)
                    }
                }
            }.start()
            return
        }
        if (requestCode == documentSaveRequestCode) {
            val pending = pendingDocumentSaveResult
            val bytes = pendingDocumentBytes
            pendingDocumentSaveResult = null
            pendingDocumentBytes = null
            pendingDocumentMimeType = null
            if (pending == null) return
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
                pending.success(null)
                return
            }
            try {
                contentResolver.openOutputStream(uri, "w")?.use { output ->
                    output.write(bytes)
                    output.flush()
                } ?: error("Não foi possível abrir o destino escolhido.")
                pending.success(uri.toString())
            } catch (error: Throwable) {
                pending.error("save_document", error.message, null)
            }
        }
    }

    private fun onboardingMarkerFile(): File = File(noBackupFilesDir, "access_guide_completed_v2")

    private fun onboardingCompleted(): Boolean = onboardingMarkerFile().exists()

    private fun markOnboardingCompleted(): Boolean = try {
        val marker = onboardingMarkerFile()
        marker.parentFile?.mkdirs()
        marker.writeText("completed")
        marker.exists()
    } catch (_: Throwable) {
        false
    }

    private fun saveBytesToDownloads(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
    ): String {
        require(bytes.isNotEmpty()) { "Arquivo vazio." }
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + File.separator + "Vigia IA",
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("Android não criou o arquivo em Downloads.")
        try {
            resolver.openOutputStream(uri, "w")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: error("Não foi possível gravar em Downloads.")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Downloads/Vigia IA/$fileName"
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun beginDocumentSave(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (pendingDocumentSaveResult != null || bytes.isEmpty()) {
            result.success(null)
            return
        }
        pendingDocumentSaveResult = result
        pendingDocumentBytes = bytes
        pendingDocumentMimeType = mimeType
        try {
            startActivityForResult(
                Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, fileName)
                },
                documentSaveRequestCode,
            )
        } catch (error: Throwable) {
            pendingDocumentSaveResult = null
            pendingDocumentBytes = null
            pendingDocumentMimeType = null
            result.error("save_document", error.message, null)
        }
    }

    private fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return (getSystemService(NotificationManager::class.java)).areNotificationsEnabled()
    }


    private fun normalizeAudioSlot(raw: String): String =
        raw.lowercase().replace(Regex("[^a-z0-9_]"), "")

    private fun audioOverrideDirectory(): File = File(filesDir, "audio_overrides").also { it.mkdirs() }

    private fun listAudioOverrideSlots(): List<String> =
        audioOverrideDirectory().listFiles()
            ?.filter { it.isFile && !it.name.startsWith(".") }
            ?.map { it.name.substringBeforeLast('.') }
            ?.filter { it.isNotBlank() }
            ?.distinct()
            ?.sorted()
            ?: emptyList()

    private fun findAudioOverride(slot: String): File? {
        val normalized = normalizeAudioSlot(slot)
        if (normalized.isBlank()) return null
        return audioOverrideDirectory().listFiles()
            ?.firstOrNull { file ->
                file.isFile && !file.name.startsWith(".") && file.name.substringBeforeLast('.') == normalized
            }
    }

    private fun removeAudioOverrides(slot: String): Boolean {
        val normalized = normalizeAudioSlot(slot)
        if (normalized.isBlank()) return false
        var found = false
        var ok = true
        audioOverrideDirectory().listFiles()?.forEach { file ->
            if (file.isFile && !file.name.startsWith(".") && file.name.substringBeforeLast('.') == normalized) {
                found = true
                if (!file.delete()) ok = false
            }
        }
        return found && ok
    }

    private fun removeAllAudioOverrides(): Boolean {
        var ok = true
        audioOverrideDirectory().listFiles()?.forEach { file ->
            if (file.isFile && !file.name.startsWith(".")) {
                if (!file.delete()) ok = false
            }
        }
        return ok
    }

    private fun beginOfflineMapImport(result: MethodChannel.Result) {
        if (pendingOfflineMapImportResult != null) {
            result.success(null)
            return
        }
        pendingOfflineMapImportResult = result
        try {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                    "application/octet-stream",
                    "application/vnd.sqlite3",
                    "application/x-sqlite3",
                    "*/*",
                ))
            }, offlineMapImportRequestCode)
        } catch (_: Throwable) {
            pendingOfflineMapImportResult = null
            result.success(null)
        }
    }

    private fun copyOfflineMapToCache(uri: Uri): Map<String, Any>? {
        return try {
            var displayName: String? = null
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) displayName = cursor.getString(index)
                }
            }
            val normalizedName = displayName?.takeIf { it.isNotBlank() } ?: "mapa_offline.mbtiles"
            val target = File(cacheDir, "offline_map_import_${System.currentTimeMillis()}.mbtiles")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            if (!target.exists() || target.length() <= 0L) {
                target.delete()
                return null
            }
            mapOf(
                "path" to target.absolutePath,
                "name" to normalizedName,
                "sizeBytes" to target.length(),
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun beginAudioImport(slot: String, result: MethodChannel.Result) {
        if (pendingAudioImportResult != null) {
            result.success(false)
            return
        }
        pendingAudioImportResult = result
        pendingAudioImportSlot = slot
        try {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/*"
            }, audioImportRequestCode)
        } catch (_: Throwable) {
            pendingAudioImportResult = null
            pendingAudioImportSlot = null
            result.success(false)
        }
    }

    private fun copyAudioOverride(slot: String, uri: Uri): Boolean {
        return try {
            val resolver = contentResolver
            val mime = resolver.getType(uri)
            val mimeExtension = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            val pathExtension = uri.lastPathSegment?.substringAfterLast('.', "")?.lowercase()
            val supported = setOf("wav", "mp3", "ogg", "m4a", "aac", "mp4")
            val extension = listOfNotNull(mimeExtension?.lowercase(), pathExtension)
                .firstOrNull { it in supported }
                ?: "m4a"
            val directory = audioOverrideDirectory()
            val temporary = File(directory, ".import_${slot}.tmp")
            resolver.openInputStream(uri)?.use { input ->
                temporary.outputStream().use { output -> input.copyTo(output) }
            } ?: return false
            if (temporary.length() <= 0L) {
                temporary.delete()
                return false
            }
            removeAudioOverrides(slot)
            val target = File(directory, "$slot.$extension")
            if (target.exists()) target.delete()
            if (!temporary.renameTo(target)) {
                temporary.copyTo(target, overwrite = true)
                temporary.delete()
            }
            target.exists() && target.length() > 0L
        } catch (_: Throwable) {
            false
        }
    }

    private fun requestOrStartAudioRecording(slot: String, result: MethodChannel.Result) {
        if (audioRecorder != null || pendingRecordingPermissionResult != null) {
            result.success(false)
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            result.success(startAudioRecordingInternal(slot))
            return
        }
        pendingRecordingPermissionResult = result
        pendingRecordingPermissionSlot = slot
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), recordAudioPermissionRequestCode)
    }

    @Suppress("DEPRECATION")
    private fun startAudioRecordingInternal(slot: String): Boolean {
        if (audioRecorder != null) return false
        val normalized = normalizeAudioSlot(slot)
        if (normalized.isBlank()) return false
        val directory = audioOverrideDirectory()
        val temporary = File(directory, ".recording_${normalized}.m4a")
        if (temporary.exists()) temporary.delete()
        return try {
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                MediaRecorder()
            }
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioChannels(1)
            recorder.setAudioSamplingRate(24000)
            recorder.setAudioEncodingBitRate(96000)
            recorder.setOutputFile(temporary.absolutePath)
            recorder.prepare()
            recorder.start()
            audioRecorder = recorder
            audioRecordingTempFile = temporary
            audioRecordingSlot = normalized
            true
        } catch (_: Throwable) {
            try { audioRecorder?.release() } catch (_: Throwable) {}
            audioRecorder = null
            temporary.delete()
            audioRecordingTempFile = null
            audioRecordingSlot = null
            false
        }
    }

    private fun stopAudioRecording(save: Boolean): Boolean {
        val recorder = audioRecorder ?: return false
        val temporary = audioRecordingTempFile
        val slot = audioRecordingSlot
        var stopped = false
        try {
            recorder.stop()
            stopped = true
        } catch (_: Throwable) {
            stopped = false
        } finally {
            try { recorder.release() } catch (_: Throwable) {}
            audioRecorder = null
            audioRecordingTempFile = null
            audioRecordingSlot = null
        }
        if (!save || !stopped || temporary == null || slot.isNullOrBlank() || temporary.length() <= 0L) {
            temporary?.delete()
            return !save && stopped
        }
        return try {
            removeAudioOverrides(slot)
            val target = File(audioOverrideDirectory(), "$slot.m4a")
            if (target.exists()) target.delete()
            if (!temporary.renameTo(target)) {
                temporary.copyTo(target, overwrite = true)
                temporary.delete()
            }
            target.exists() && target.length() > 0L
        } catch (_: Throwable) {
            temporary.delete()
            false
        }
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

    private fun setBikeScreenBrightness(value: Float?) {
        val normalized = value?.coerceIn(0.01f, 1.0f)
        bikeBrightnessOverride = normalized
        runOnUiThread {
            val attributes = window.attributes
            attributes.screenBrightness = normalized ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window.attributes = attributes
        }
    }

    private fun activeConnectionType(): String {
        return try {
            val manager = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = manager.activeNetwork ?: return "Sem rede"
            val capabilities = manager.getNetworkCapabilities(network) ?: return "Sem rede"
            when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Dados móveis"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> "Bluetooth"
                else -> "Rede ativa"
            }
        } catch (_: Throwable) {
            "Indisponível"
        }
    }

    private fun readSystemHealth(): Map<String, Any?> {
        val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
        val battery = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).takeIf { it >= 0 }
        val intent = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val rawTemperature = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val batteryStatus = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
            ?: BatteryManager.BATTERY_STATUS_UNKNOWN
        val batteryCharging = batteryStatus == BatteryManager.BATTERY_STATUS_CHARGING ||
            batteryStatus == BatteryManager.BATTERY_STATUS_FULL
        val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val powerSource = when {
            plugged and BatteryManager.BATTERY_PLUGGED_USB != 0 -> "USB"
            plugged and BatteryManager.BATTERY_PLUGGED_AC != 0 -> "Carregador"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1 &&
                plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS != 0 -> "Sem fio"
            batteryCharging -> "Carregando"
            else -> "Bateria"
        }
        val currentMicroAmps = batteryManager
            .getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            .takeIf { it != Int.MIN_VALUE && it != 0 }
        val batteryCurrentMa = currentMicroAmps?.let { abs(it.toDouble()) / 1000.0 }

        val processMemory = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
        val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        val deviceMemory = ActivityManager.MemoryInfo().also { activityManager.getMemoryInfo(it) }
        val stat = StatFs(filesDir.absolutePath)

        val overrideBrightness = bikeBrightnessOverride
        val systemBrightness = try {
            Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS).coerceIn(0, 255)
        } catch (_: Throwable) {
            null
        }
        val brightnessPercent = overrideBrightness?.let { (it * 100f).toInt().coerceIn(1, 100) }
            ?: systemBrightness?.let { ((it / 255.0) * 100.0).toInt().coerceIn(0, 100) }
        val automaticBrightness = if (overrideBrightness != null) {
            false
        } else {
            try {
                Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE) ==
                    Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            } catch (_: Throwable) {
                null
            }
        }
        val screenInteractive = (getSystemService(POWER_SERVICE) as PowerManager).isInteractive

        val wallNow = SystemClock.elapsedRealtime()
        val processNow = android.os.Process.getElapsedCpuTime()
        val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
        val previousWall = lastCpuWallMs
        val previousProcess = lastCpuProcessMs
        val appCpuPercent = if (previousWall != null && previousProcess != null && wallNow > previousWall) {
            val processDelta = (processNow - previousProcess).coerceAtLeast(0L)
            val wallDelta = wallNow - previousWall
            ((processDelta.toDouble() / wallDelta.toDouble()) * 100.0 / cores.toDouble())
                .coerceIn(0.0, 100.0)
        } else {
            null
        }
        lastCpuWallMs = wallNow
        lastCpuProcessMs = processNow

        return mapOf(
            "deviceManufacturer" to Build.MANUFACTURER,
            "deviceModel" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,
            "androidSdk" to Build.VERSION.SDK_INT,
            "batteryPercent" to battery,
            "batteryCharging" to batteryCharging,
            "batteryPowerSource" to powerSource,
            "batteryCurrentMa" to batteryCurrentMa,
            "batteryTemperatureC" to if (rawTemperature == Int.MIN_VALUE) null else rawTemperature / 10.0,
            "screenBrightnessPercent" to brightnessPercent,
            "automaticBrightness" to automaticBrightness,
            "screenInteractive" to screenInteractive,
            "screenDimmedByBike" to (overrideBrightness != null),
            "appCpuPercent" to appCpuPercent,
            "processorCount" to cores,
            "memoryUsedBytes" to processMemory.totalPss.toLong() * 1024L,
            "memoryAvailableBytes" to deviceMemory.availMem,
            "memoryTotalBytes" to deviceMemory.totalMem,
            "freeStorageBytes" to stat.availableBytes,
            "totalStorageBytes" to stat.totalBytes,
            "connectionType" to activeConnectionType(),
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
