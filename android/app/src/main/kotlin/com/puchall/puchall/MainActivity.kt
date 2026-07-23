package com.puchall.puchall

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "puchall/workout_tracking",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    requestNotificationPermissionIfNeeded()
                    val intent = WorkoutTrackingService.startIntent(
                        context = this,
                        exerciseType = args["exerciseType"] as? String ?: "push-up",
                        accelerationThreshold = (args["accelerationThreshold"] as? Number)?.toDouble() ?: 18.0,
                        gyroscopeThreshold = (args["gyroscopeThreshold"] as? Number)?.toDouble() ?: 1.2,
                        releaseRatio = (args["releaseRatio"] as? Number)?.toDouble() ?: 0.55,
                        cooldownMs = (args["cooldownMs"] as? Number)?.toLong() ?: 600L,
                    )
                    startWorkoutService(intent)
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
}
