package com.puchall.puchall

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var calibrationSource: VerticalAccelerationSource? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "puchall/workout_tracking",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    val exerciseType = args["exerciseType"] as? String ?: "push-up"
                    requestNotificationPermissionIfNeeded()
                    val missingPermissions = missingWorkoutPermissions(exerciseType)
                    if (missingPermissions.isNotEmpty()) {
                        requestPermissions(missingPermissions.toTypedArray(), 1202)
                        result.error(
                            "PERMISSION_REQUIRED",
                            "Workout permissions are required.",
                            missingPermissions,
                        )
                        return@setMethodCallHandler
                    }
                    val intent = WorkoutTrackingService.startIntent(
                        context = this,
                        exerciseType = exerciseType,
                        amplitudeThreshold = (args["amplitudeThreshold"] as? Number)?.toDouble() ?: 0.8,
                        minHalfPeriodMs = (args["minHalfPeriodMs"] as? Number)?.toLong() ?: 250L,
                        maxHalfPeriodMs = (args["maxHalfPeriodMs"] as? Number)?.toLong() ?: 2500L,
                        cooldownMs = (args["cooldownMs"] as? Number)?.toLong() ?: 800L,
                        lowPassCutoffHz = (args["lowPassCutoffHz"] as? Number)?.toDouble()
                            ?: RepDetectorConfig.DEFAULT_LOW_PASS_CUTOFF_HZ,
                        verticalAccelerationScale =
                            (args["verticalAccelerationScale"] as? Number)?.toDouble() ?: 1.0,
                        weightKg = (args["weightKg"] as? Number)?.toDouble() ?: 70.0,
                        heightCm = (args["heightCm"] as? Number)?.toDouble() ?: 0.0,
                    )
                    startWorkoutService(intent)
                    result.success(null)
                }
                "startCalibration" -> {
                    startCalibration()
                    result.success(null)
                }
                "stopCalibration" -> {
                    stopCalibration()
                    result.success(null)
                }
                "stopTracking" -> {
                    result.success(WorkoutTrackingService.stopRunningFromChannel())
                }
                "pauseTracking" -> {
                    startWorkoutService(
                        WorkoutTrackingService.commandIntent(
                            this,
                            WorkoutTrackingService.ACTION_PAUSE,
                        ),
                    )
                    result.success(null)
                }
                "resumeTracking" -> {
                    startWorkoutService(
                        WorkoutTrackingService.commandIntent(
                            this,
                            WorkoutTrackingService.ACTION_RESUME,
                        ),
                    )
                    result.success(null)
                }
                "resetTracking" -> {
                    startWorkoutService(
                        WorkoutTrackingService.commandIntent(
                            this,
                            WorkoutTrackingService.ACTION_RESET,
                        ),
                    )
                    result.success(null)
                }
                "getTrackingState" -> result.success(WorkoutTrackingService.currentState())
                "consumeCompletedSession" -> {
                    result.success(WorkoutTrackingService.consumeCompletedSession(this))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "puchall/workout_tracking_events",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    WorkoutTrackingBridge.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    WorkoutTrackingBridge.setEventSink(null)
                }
            },
        )
    }

    /**
     * 기준치 캘리브레이션용 센서 수집.
     *
     * 측정과 **같은** [VerticalAccelerationSource]를 같은 샘플링 간격으로 돌려서,
     * 여기서 뽑은 기준치가 실제 측정에 그대로 적용되도록 한다.
     * 30초짜리 화면 안 작업이라 포그라운드 서비스는 띄우지 않는다.
     */
    private fun startCalibration() {
        stopCalibration()
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val source = VerticalAccelerationSource(sensorManager) { verticalAcceleration, timestampMs ->
            WorkoutTrackingBridge.emitCalibrationSample(verticalAcceleration, timestampMs)
        }
        source.start()
        calibrationSource = source
    }

    private fun stopCalibration() {
        calibrationSource?.stop()
        calibrationSource = null
    }

    override fun onDestroy() {
        stopCalibration()
        super.onDestroy()
    }

    private fun startWorkoutService(intent: Intent) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            intent.action == WorkoutTrackingService.ACTION_START
        ) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            return
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1201)
    }

    private fun missingWorkoutPermissions(exerciseType: String): List<String> {
        if (exerciseType != "running" && exerciseType != "walking") return emptyList()

        val permissions = mutableListOf<String>()
        if (
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions += Manifest.permission.ACCESS_FINE_LOCATION
            permissions += Manifest.permission.ACCESS_COARSE_LOCATION
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions += Manifest.permission.ACTIVITY_RECOGNITION
        }

        return permissions
    }
}
