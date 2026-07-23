package com.puchall.puchall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.graphics.Color
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import java.lang.SecurityException
import kotlin.math.sqrt

class WorkoutTrackingService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private lateinit var preferences: SharedPreferences
    private var exerciseType: String = DEFAULT_EXERCISE_TYPE
    private var status: String = STATUS_IDLE
    private var count: Int = 0
    private var startedAtMillis: Long = 0L
    private var endedAtMillis: Long = 0L
    private var latestGyroscopeMagnitude: Double = 0.0
    private var counter: WorkoutCounter = defaultCounter()

    override fun onCreate() {
        super.onCreate()
        activeService = this
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startTracking(intent)
            ACTION_STOP -> stopTracking(storeCompletedSession = true)
            ACTION_PAUSE -> pauseTracking()
            ACTION_RESUME -> resumeTracking()
            ACTION_RESET -> resetTracking()
            else -> emitState()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        unregisterSensors()
        activeService = null
        super.onDestroy()
    }

    fun stopFromChannel(): Map<String, Any?> = stopTracking(storeCompletedSession = false)

    override fun onSensorChanged(event: SensorEvent) {
        if (status != STATUS_MEASURING) return

        val magnitude = magnitude(event.values)
        when (event.sensor.type) {
            Sensor.TYPE_GYROSCOPE -> latestGyroscopeMagnitude = magnitude
            Sensor.TYPE_ACCELEROMETER -> {
                if (counter.update(magnitude, latestGyroscopeMagnitude)) {
                    count += 1
                    updateNotification()
                    emitState()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun startTracking(intent: Intent) {
        exerciseType = intent.getStringExtra(EXTRA_EXERCISE_TYPE) ?: DEFAULT_EXERCISE_TYPE
        val accelerationThreshold = intent.getDoubleExtra(EXTRA_ACCELERATION_THRESHOLD, 18.0)
        val gyroscopeThreshold = intent.getDoubleExtra(EXTRA_GYROSCOPE_THRESHOLD, 1.2)
        val releaseRatio = intent.getDoubleExtra(EXTRA_RELEASE_RATIO, 0.55)
        val cooldownMs = intent.getLongExtra(EXTRA_COOLDOWN_MS, 600L)

        counter = WorkoutCounter(
            threshold = accelerationThreshold,
            gyroscopeThreshold = gyroscopeThreshold,
            releaseRatio = releaseRatio,
            cooldownMs = cooldownMs,
        )
        count = 0
        latestGyroscopeMagnitude = 0.0
        startedAtMillis = System.currentTimeMillis()
        endedAtMillis = 0L
        status = STATUS_MEASURING

        try {
            startForegroundCompat()
        } catch (error: SecurityException) {
            status = STATUS_FAILED
            unregisterSensors()
            emitState()
            stopSelf()
            return
        }
        registerSensors()
        emitState()
    }

    private fun stopTracking(storeCompletedSession: Boolean): Map<String, Any?> {
        if (status == STATUS_IDLE) {
            emitState()
            stopSelf()
            return stateMap()
        }

        unregisterSensors()
        endedAtMillis = System.currentTimeMillis()
        status = STATUS_COMPLETED
        val completedState = stateMap()
        if (storeCompletedSession && count > 0) {
            preferences.edit()
                .putString(KEY_COMPLETED_EXERCISE_TYPE, exerciseType)
                .putString(KEY_COMPLETED_STATUS, status)
                .putInt(KEY_COMPLETED_COUNT, count)
                .putLong(KEY_COMPLETED_STARTED_AT, startedAtMillis)
                .putLong(KEY_COMPLETED_ENDED_AT, endedAtMillis)
                .apply()
        }
        emitState()
        stopForegroundCompat()
        stopSelf()
        return completedState
    }

    private fun pauseTracking() {
        if (status != STATUS_MEASURING) return
        status = STATUS_PAUSED
        unregisterSensors()
        updateNotification()
        emitState()
    }

    private fun resumeTracking() {
        if (status != STATUS_PAUSED) return
        status = STATUS_MEASURING
        registerSensors()
        updateNotification()
        emitState()
    }

    private fun resetTracking() {
        count = 0
        counter.reset()
        updateNotification()
        emitState()
    }

    private fun registerSensors() {
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.also {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.also {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    private fun unregisterSensors() {
        sensorManager.unregisterListener(this)
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            pendingIntentFlags(),
        )
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, WorkoutTrackingService::class.java).setAction(ACTION_STOP),
            pendingIntentFlags(),
        )
        val pauseOrResumeAction = if (status == STATUS_PAUSED) ACTION_RESUME else ACTION_PAUSE
        val pauseOrResumeLabel = if (status == STATUS_PAUSED) "재개" else "일시정지"
        val pauseOrResumeIcon = if (status == STATUS_PAUSED) {
            android.R.drawable.ic_media_play
        } else {
            android.R.drawable.ic_media_pause
        }
        val pauseOrResumePendingIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, WorkoutTrackingService::class.java).setAction(pauseOrResumeAction),
            pendingIntentFlags(),
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
            .setColor(Color.BLACK)
            .setContentTitle(exerciseLabel())
            .setContentText("${count}개")
            .setOngoing(status == STATUS_MEASURING || status == STATUS_PAUSED)
            .setContentIntent(openPendingIntent)
            .addAction(
                Notification.Action.Builder(
                    pauseOrResumeIcon,
                    pauseOrResumeLabel,
                    pauseOrResumePendingIntent,
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "종료",
                    stopPendingIntent,
                ).build(),
            )
            .build()
    }

    private fun exerciseLabel(): String {
        return when (exerciseType) {
            "pull-up" -> "풀업"
            else -> "푸쉬업"
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "운동 측정",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun emitState() {
        WorkoutTrackingBridge.emit(stateMap())
    }

    private fun stateMap(): Map<String, Any?> {
        return mapOf(
            "exerciseType" to exerciseType,
            "status" to status,
            "count" to count,
            "startedAtMillis" to startedAtMillis,
            "endedAtMillis" to endedAtMillis,
        )
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }
    }

    companion object {
        const val ACTION_START = "com.puchall.puchall.workout.START"
        const val ACTION_STOP = "com.puchall.puchall.workout.STOP"
        const val ACTION_PAUSE = "com.puchall.puchall.workout.PAUSE"
        const val ACTION_RESUME = "com.puchall.puchall.workout.RESUME"
        const val ACTION_RESET = "com.puchall.puchall.workout.RESET"

        const val EXTRA_EXERCISE_TYPE = "exerciseType"
        const val EXTRA_ACCELERATION_THRESHOLD = "accelerationThreshold"
        const val EXTRA_GYROSCOPE_THRESHOLD = "gyroscopeThreshold"
        const val EXTRA_RELEASE_RATIO = "releaseRatio"
        const val EXTRA_COOLDOWN_MS = "cooldownMs"

        private const val CHANNEL_ID = "workout_tracking"
        private const val NOTIFICATION_ID = 1201
        private const val PREFERENCES_NAME = "workout_tracking_service"
        private const val KEY_COMPLETED_EXERCISE_TYPE = "completedExerciseType"
        private const val KEY_COMPLETED_STATUS = "completedStatus"
        private const val KEY_COMPLETED_COUNT = "completedCount"
        private const val KEY_COMPLETED_STARTED_AT = "completedStartedAt"
        private const val KEY_COMPLETED_ENDED_AT = "completedEndedAt"
        private const val DEFAULT_EXERCISE_TYPE = "push-up"
        private const val STATUS_IDLE = "idle"
        private const val STATUS_MEASURING = "measuring"
        private const val STATUS_PAUSED = "paused"
        private const val STATUS_COMPLETED = "completed"
        private const val STATUS_FAILED = "failed"
        private var activeService: WorkoutTrackingService? = null

        fun startIntent(
            context: Context,
            exerciseType: String,
            accelerationThreshold: Double,
            gyroscopeThreshold: Double,
            releaseRatio: Double,
            cooldownMs: Long,
        ): Intent {
            return Intent(context, WorkoutTrackingService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_EXERCISE_TYPE, exerciseType)
                .putExtra(EXTRA_ACCELERATION_THRESHOLD, accelerationThreshold)
                .putExtra(EXTRA_GYROSCOPE_THRESHOLD, gyroscopeThreshold)
                .putExtra(EXTRA_RELEASE_RATIO, releaseRatio)
                .putExtra(EXTRA_COOLDOWN_MS, cooldownMs)
        }

        fun commandIntent(context: Context, action: String): Intent {
            return Intent(context, WorkoutTrackingService::class.java).setAction(action)
        }

        fun idleState(): Map<String, Any?> {
            return mapOf(
                "exerciseType" to DEFAULT_EXERCISE_TYPE,
                "status" to STATUS_IDLE,
                "count" to 0,
                "startedAtMillis" to 0L,
                "endedAtMillis" to 0L,
            )
        }

        fun consumeCompletedSession(context: Context): Map<String, Any?>? {
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            if (!preferences.contains(KEY_COMPLETED_COUNT)) return null
            val state = mapOf(
                "exerciseType" to preferences.getString(KEY_COMPLETED_EXERCISE_TYPE, DEFAULT_EXERCISE_TYPE),
                "status" to preferences.getString(KEY_COMPLETED_STATUS, STATUS_COMPLETED),
                "count" to preferences.getInt(KEY_COMPLETED_COUNT, 0),
                "startedAtMillis" to preferences.getLong(KEY_COMPLETED_STARTED_AT, 0L),
                "endedAtMillis" to preferences.getLong(KEY_COMPLETED_ENDED_AT, 0L),
            )
            preferences.edit().clear().apply()
            return state
        }

        fun currentState(): Map<String, Any?> = WorkoutTrackingBridge.currentState()

        fun stopRunningFromChannel(): Map<String, Any?> {
            return activeService?.stopFromChannel() ?: currentState()
        }

        private fun defaultCounter(): WorkoutCounter {
            return WorkoutCounter(
                threshold = 18.0,
                gyroscopeThreshold = 1.2,
                releaseRatio = 0.55,
                cooldownMs = 600L,
            )
        }

        private fun magnitude(values: FloatArray): Double {
            val x = values.getOrNull(0)?.toDouble() ?: 0.0
            val y = values.getOrNull(1)?.toDouble() ?: 0.0
            val z = values.getOrNull(2)?.toDouble() ?: 0.0
            return sqrt(x * x + y * y + z * z)
        }

        private fun pendingIntentFlags(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        }
    }
}
