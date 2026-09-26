package com.vigiaia.app

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import kotlin.math.PI

/**
 * Stream nativo de orientacao fisica do aparelho.
 *
 * Prefere TYPE_ROTATION_VECTOR (fusão de sensores do Android) e usa
 * acelerometro + magnetometro como fallback. Nenhum valor sintetico e emitido:
 * sem sensores compativeis o canal informa indisponibilidade ao Flutter.
 */
class CompassStreamHandler(private val activity: Activity) :
    EventChannel.StreamHandler,
    SensorEventListener {

    private val sensorManager =
        activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var eventSink: EventChannel.EventSink? = null
    private var rotationSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var magnetometer: Sensor? = null
    private var gravityValues: FloatArray? = null
    private var magneticValues: FloatArray? = null
    private var lastEmitNanos: Long = 0L
    private var sensorLabel: String = "indisponivel"

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        stopSensors()

        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (rotationSensor != null) {
            sensorLabel = "rotation_vector"
            sensorManager.registerListener(
                this,
                rotationSensor,
                SensorManager.SENSOR_DELAY_UI,
            )
            return
        }

        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (accelerometer != null && magnetometer != null) {
            sensorLabel = "accelerometer+magnetometer"
            sensorManager.registerListener(
                this,
                accelerometer,
                SensorManager.SENSOR_DELAY_UI,
            )
            sensorManager.registerListener(
                this,
                magnetometer,
                SensorManager.SENSOR_DELAY_UI,
            )
            return
        }

        events?.error(
            "compass_unavailable",
            "O aparelho nao fornece sensores compativeis com bussola.",
            null,
        )
    }

    override fun onCancel(arguments: Any?) {
        stopSensors()
        eventSink = null
    }

    fun dispose() {
        stopSensors()
        eventSink = null
    }

    private fun stopSensors() {
        sensorManager.unregisterListener(this)
        gravityValues = null
        magneticValues = null
        lastEmitNanos = 0L
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        val heading = when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> headingFromRotationVector(event.values)
            Sensor.TYPE_ACCELEROMETER -> {
                gravityValues = event.values.clone()
                headingFromAccelerometerAndMagnetometer()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                magneticValues = event.values.clone()
                headingFromAccelerometerAndMagnetometer()
            }
            else -> null
        } ?: return

        // Limita atualizacoes nativas a ~5 Hz para evitar rebuild/camera excessivos.
        val now = event.timestamp
        if (lastEmitNanos != 0L && now - lastEmitNanos < 200_000_000L) return
        lastEmitNanos = now

        eventSink?.success(
            mapOf(
                "headingDegrees" to heading,
                "sensor" to sensorLabel,
                "timestampMs" to System.currentTimeMillis(),
            ),
        )
    }

    private fun headingFromRotationVector(values: FloatArray): Double? {
        val rotationMatrix = FloatArray(9)
        return try {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, values)
            headingFromRotationMatrix(rotationMatrix)
        } catch (_: Throwable) {
            null
        }
    }

    private fun headingFromAccelerometerAndMagnetometer(): Double? {
        val gravity = gravityValues ?: return null
        val magnetic = magneticValues ?: return null
        val rotationMatrix = FloatArray(9)
        if (!SensorManager.getRotationMatrix(rotationMatrix, null, gravity, magnetic)) {
            return null
        }
        return headingFromRotationMatrix(rotationMatrix)
    }

    @Suppress("DEPRECATION")
    private fun headingFromRotationMatrix(matrix: FloatArray): Double {
        val adjusted = FloatArray(9)
        val rotation = activity.windowManager.defaultDisplay.rotation
        val remapped = when (rotation) {
            Surface.ROTATION_90 -> SensorManager.remapCoordinateSystem(
                matrix,
                SensorManager.AXIS_Y,
                SensorManager.AXIS_MINUS_X,
                adjusted,
            )
            Surface.ROTATION_180 -> SensorManager.remapCoordinateSystem(
                matrix,
                SensorManager.AXIS_MINUS_X,
                SensorManager.AXIS_MINUS_Y,
                adjusted,
            )
            Surface.ROTATION_270 -> SensorManager.remapCoordinateSystem(
                matrix,
                SensorManager.AXIS_MINUS_Y,
                SensorManager.AXIS_X,
                adjusted,
            )
            else -> false
        }
        val orientation = FloatArray(3)
        SensorManager.getOrientation(if (remapped) adjusted else matrix, orientation)
        val degrees = orientation[0].toDouble() * 180.0 / PI
        return ((degrees % 360.0) + 360.0) % 360.0
    }
}
