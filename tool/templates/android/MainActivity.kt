package com.gushiyu01.app_for_android_a_and_ios

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {
    private var sensorManager: SensorManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app_for_android_a_and_ios/accelerometer",
        ).setStreamHandler(sensorHandler(Sensor.TYPE_ACCELEROMETER))

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app_for_android_a_and_ios/gyroscope",
        ).setStreamHandler(sensorHandler(Sensor.TYPE_GYROSCOPE))
    }

    private fun sensorHandler(sensorType: Int): EventChannel.StreamHandler {
        return object : EventChannel.StreamHandler {
            private var listener: SensorEventListener? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                val manager = sensorManager
                // Android gravity/accelerometer use specific-force signs. Negate
                // their gravity component to match Core Motion's physical gravity.
                val sensor = if (sensorType == Sensor.TYPE_ACCELEROMETER) {
                    manager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        ?: manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                } else {
                    manager?.getDefaultSensor(sensorType)
                }
                if (manager == null || sensor == null) {
                    events?.error(
                        "SENSOR_UNAVAILABLE",
                        "The requested sensor is unavailable",
                        null,
                    )
                    return
                }

                val gravity = DoubleArray(3)
                var lastTimestamp: Long? = null
                val newListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        val values = DoubleArray(3) { event.values[it].toDouble() }
                        if (sensorType == Sensor.TYPE_ACCELEROMETER) {
                            if (sensor.type == Sensor.TYPE_ACCELEROMETER) {
                                val previous = lastTimestamp
                                val dt = if (previous == null) 0.0 else
                                    (event.timestamp - previous) / 1_000_000_000.0
                                val alpha = if (previous == null) 0.0 else 0.25 / (0.25 + dt)
                                for (axis in 0..2) {
                                    gravity[axis] = alpha * gravity[axis] + (1 - alpha) * values[axis]
                                    values[axis] = gravity[axis]
                                }
                                lastTimestamp = event.timestamp
                            }
                            for (axis in 0..2) values[axis] = -values[axis]
                        }
                        events?.success(
                            mapOf("x" to values[0], "y" to values[1], "z" to values[2]),
                        )
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

                listener = newListener
                val registered = manager.registerListener(
                    newListener,
                    sensor,
                    SensorManager.SENSOR_DELAY_UI,
                )
                if (!registered) {
                    listener = null
                    events?.error("SENSOR_UNAVAILABLE", "Cannot start sensor updates", null)
                }
            }

            override fun onCancel(arguments: Any?) {
                listener?.let { currentListener ->
                    sensorManager?.unregisterListener(currentListener)
                }
                listener = null
            }
        }
    }
}
