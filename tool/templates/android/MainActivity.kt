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
                val sensor = manager?.getDefaultSensor(sensorType)
                if (manager == null || sensor == null) {
                    events?.error(
                        "SENSOR_UNAVAILABLE",
                        "The requested sensor is unavailable",
                        null,
                    )
                    return
                }

                val newListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        events?.success(
                            mapOf(
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble(),
                            ),
                        )
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

                listener = newListener
                manager.registerListener(
                    newListener,
                    sensor,
                    SensorManager.SENSOR_DELAY_UI,
                )
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
