package com.puchall.puchall

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.graphics.Color
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.lang.SecurityException
import java.util.Locale
import kotlin.math.abs
import kotlin.math.sqrt

class WorkoutTrackingService : Service(), SensorEventListener, LocationListener {
    private lateinit var sensorManager: SensorManager
    private lateinit var locationManager: LocationManager
    private lateinit var preferences: SharedPreferences
    private var exerciseType: String = DEFAULT_EXERCISE_TYPE
    private var status: String = STATUS_IDLE
    private var count: Int = 0
    private var startedAtMillis: Long = 0L
    private var endedAtMillis: Long = 0L
    private var repDetector: RepDetector = defaultRepDetector()
    private var verticalAccelerationSource: VerticalAccelerationSource? = null
    private val handler = Handler(Looper.getMainLooper())
    private var accumulatedElapsedSeconds: Long = 0L
    private var resumedAtMillis: Long = 0L
    private var distanceMeters: Double = 0.0
    private var caloriesKcal: Double = 0.0

    /** 워킹 전용 누적 칼로리. 구간마다 그 순간 속도의 계수로 적산한다(세션 평균 소급 적용 금지). */
    private var walkingBaseCaloriesKcal: Double = 0.0

    /** 상승 고도에 대한 추가 칼로리. 러닝/워킹 공통으로 적산한다. */
    private var elevationCaloriesKcal: Double = 0.0
    private var elevationGainMeters: Double = 0.0
    private var previousAltitudeMeters: Double? = null

    /** 거리 계산용으로 EMA 스무딩한 좌표. GPS 지터로 인한 거리 과대추정을 줄인다. */
    private var smoothedLatitude: Double? = null
    private var smoothedLongitude: Double? = null
    private var steps: Int = 0
    private var weightKg: Double = 70.0

    /** 0이면 "입력 안 함"으로 보고 고정 기본 보폭을 쓴다. */
    private var heightCm: Double = 0.0
    private var previousLocation: Location? = null
    private var stepCounterBaseline: Int? = null
    private var lastStepSampleSteps: Int = 0
    private var lastStepSampleMillis: Long = 0L
    private var lastGpsSteps: Int = 0
    private var lastGpsMillis: Long = 0L
    private var lastShadowCompensationSteps: Int = 0
    private var lastWalkingDistanceSteps: Int = 0
    private var averageStrideMeters: Double = DEFAULT_RUNNING_STRIDE_METERS
    private var gpsShadowDistanceMeters: Double = 0.0
    private val stepWindow = ArrayDeque<Pair<Long, Int>>()
    private val accelerationWindow = ArrayDeque<Pair<Long, Double>>()
    private var currentSpeedMetersPerSecond: Double = 0.0
    private var smoothedSpeedMetersPerSecond: Double = 0.0
    private var averageSpeedMetersPerSecond: Double = 0.0
    private var averagePaceSecondsPerKm: Double = 0.0
    private var cadenceSpm: Int = 0
    private var motionState: String = MOTION_STATIONARY
    private var pendingMotionState: String = MOTION_STATIONARY
    private var pendingMotionStateSinceMillis: Long = 0L
    private var autoPaused: Boolean = false
    private var stationarySinceMillis: Long = 0L
    private var movingSinceMillis: Long = 0L
    private var movingDurationMillis: Long = 0L
    private var movingDurationSeconds: Long = 0L
    private var lastCardioMetricsMillis: Long = 0L
    private val cardioTicker = object : Runnable {
        override fun run() {
            if (status != STATUS_MEASURING || !isCardioExercise()) return
            updateCardioMetrics()
            updateNotification()
            emitState()
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        activeService = this
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
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
        stopCardioTicker()
        unregisterLocationUpdates()
        unregisterSensors()
        activeService = null
        super.onDestroy()
    }

    fun stopFromChannel(): Map<String, Any?> = stopTracking(storeCompletedSession = false)

    override fun onSensorChanged(event: SensorEvent) {
        if (status != STATUS_MEASURING) return

        // 근력 운동은 VerticalAccelerationSource가 따로 처리한다.
        // 여기서는 유산소 측정용 센서만 받는다.
        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> handleStepCounter(event.values.firstOrNull()?.toInt() ?: 0)
            Sensor.TYPE_ACCELEROMETER -> {
                if (isCardioExercise()) {
                    handleCardioAcceleration(magnitude(event.values))
                }
            }
        }
    }

    /** 중력이 제거된 수직 가속도 샘플 하나로 반복을 판정한다. */
    private fun handleVerticalAcceleration(verticalAcceleration: Double, timestampMs: Long) {
        if (status != STATUS_MEASURING) return

        if (repDetector.update(verticalAcceleration, timestampMs)) {
            count += 1
            caloriesKcal = calculateStrengthCalories()
            updateNotification()
            emitState()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onLocationChanged(location: Location) {
        if (status != STATUS_MEASURING || !usesGps()) return
        if (!isValidLocation(location)) return

        val previous = previousLocation
        if (previous == null) {
            previousLocation = location
            smoothedLatitude = location.latitude
            smoothedLongitude = location.longitude
            if (location.hasAltitude()) previousAltitudeMeters = location.altitude
            lastGpsSteps = steps
            lastGpsMillis = location.time
            lastShadowCompensationSteps = steps
            lastWalkingDistanceSteps = steps
            return
        }

        val deltaMillis = location.time - previous.time
        if (deltaMillis < minLocationDeltaMs()) {
            return
        }

        val deltaDistance = smoothedDistanceTo(location)
        val instantSpeedMetersPerSecond = if (location.hasSpeed() && location.speed >= 0f) {
            location.speed.toDouble()
        } else {
            deltaDistance / (deltaMillis / 1000.0)
        }

        handleAltitudeSample(location)

        if (exerciseType == "walking") {
            handleWalkingLocation(location, deltaDistance, instantSpeedMetersPerSecond)
            return
        }

        handleRunningLocation(location, deltaDistance, instantSpeedMetersPerSecond)
    }

    /**
     * 원시 좌표 대신 EMA로 스무딩한 좌표 사이의 거리를 계산한다.
     * 정지 상태에서도 원시 좌표는 몇 미터씩 흔들리는데, 그 흔들림이 방향과 무관하게
     * 전부 양수로 누적 거리에 더해지는 구조적 과대추정이 있다. 스무딩하면 이 편향이 줄어든다.
     */
    private fun smoothedDistanceTo(location: Location): Double {
        val previousLat = smoothedLatitude
        val previousLng = smoothedLongitude

        val newLat: Double
        val newLng: Double
        if (previousLat == null || previousLng == null) {
            newLat = location.latitude
            newLng = location.longitude
        } else {
            newLat = previousLat + POSITION_EMA_ALPHA * (location.latitude - previousLat)
            newLng = previousLng + POSITION_EMA_ALPHA * (location.longitude - previousLng)
        }

        val distance = if (previousLat == null || previousLng == null) {
            0.0
        } else {
            val results = FloatArray(1)
            Location.distanceBetween(previousLat, previousLng, newLat, newLng, results)
            results[0].toDouble()
        }

        smoothedLatitude = newLat
        smoothedLongitude = newLng
        return distance
    }

    /**
     * GPS 고도로 누적 상승고도를 추정해 칼로리에 오르막 보정치를 더한다.
     * GPS 고도는 수평 위치보다 오차가 크므로, 노이즈 수준의 미세 변화(1m 미만)는 무시하고
     * 한 번에 비정상적으로 큰 변화(15m 초과)도 튐으로 보고 버린다.
     */
    private fun handleAltitudeSample(location: Location) {
        if (!location.hasAltitude()) return

        val previousAltitude = previousAltitudeMeters
        previousAltitudeMeters = location.altitude
        if (previousAltitude == null) return

        val delta = location.altitude - previousAltitude
        if (delta < MIN_ELEVATION_GAIN_DELTA_METERS || delta > MAX_ELEVATION_GAIN_JUMP_METERS) return

        elevationGainMeters += delta
        elevationCaloriesKcal += weightKg * delta * ELEVATION_GAIN_CALORIES_PER_KG_METER
        refreshCardioCalories()
    }

    private fun handleRunningLocation(
        location: Location,
        deltaDistance: Double,
        speedMetersPerSecond: Double,
    ) {
        if (
            deltaDistance < MIN_LOCATION_DISTANCE_METERS ||
            speedMetersPerSecond > MAX_RUNNING_SPEED_METERS_PER_SECOND
        ) {
            previousLocation = location
            return
        }

        previousLocation = location
        updateStrideFromGps(deltaDistance, location.time)
        lastGpsMillis = location.time
        lastShadowCompensationSteps = steps
        updateSpeed(speedMetersPerSecond, SPEED_EMA_ALPHA)
        updateCardioMetrics()
        if (!autoPaused && motionState != MOTION_VEHICLE) {
            distanceMeters += deltaDistance
        }
        updateAverages()
        refreshCardioCalories()
        updateNotification()
        emitState()
    }

    private fun handleWalkingLocation(
        location: Location,
        deltaDistance: Double,
        speedMetersPerSecond: Double,
    ) {
        val stepDelta = (steps - lastGpsSteps).coerceAtLeast(0)
        val accelerationActive = accelerationRange() >= WALKING_ACCELERATION_ACTIVE_RANGE
        val speedKmh = speedMetersPerSecond * 3.6
        val vehicleCandidate = speedKmh >= WALKING_VEHICLE_SPEED_KMH && stepDelta == 0
        val validWalkingMove =
            !vehicleCandidate &&
                speedKmh <= WALKING_RUNNING_SPEED_KMH &&
                stepDelta > 0 &&
                accelerationActive &&
                deltaDistance <= WALKING_MAX_LOCATION_JUMP_METERS

        previousLocation = location
        lastGpsMillis = location.time
        updateSpeed(speedMetersPerSecond, WALKING_SPEED_EMA_ALPHA)

        if (validWalkingMove) {
            updateStrideFromGps(deltaDistance, location.time)
            if (!autoPaused && motionState != MOTION_VEHICLE) {
                distanceMeters += deltaDistance
                lastWalkingDistanceSteps = steps
                accumulateWalkingCalories(deltaDistance)
            }
        } else {
            lastGpsSteps = steps
        }

        updateCardioMetrics()
        updateNotification()
        emitState()
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    override fun onProviderEnabled(provider: String) = Unit

    override fun onProviderDisabled(provider: String) = Unit

    private fun startTracking(intent: Intent) {
        exerciseType = intent.getStringExtra(EXTRA_EXERCISE_TYPE) ?: DEFAULT_EXERCISE_TYPE
        weightKg = intent.getDoubleExtra(EXTRA_WEIGHT_KG, 70.0)
        heightCm = intent.getDoubleExtra(EXTRA_HEIGHT_CM, 0.0)

        repDetector = RepDetector(
            RepDetectorConfig(
                amplitudeThreshold = intent.getDoubleExtra(
                    EXTRA_AMPLITUDE_THRESHOLD,
                    DEFAULT_AMPLITUDE_THRESHOLD,
                ),
                minHalfPeriodMs = intent.getLongExtra(
                    EXTRA_MIN_HALF_PERIOD_MS,
                    DEFAULT_MIN_HALF_PERIOD_MS,
                ),
                maxHalfPeriodMs = intent.getLongExtra(
                    EXTRA_MAX_HALF_PERIOD_MS,
                    DEFAULT_MAX_HALF_PERIOD_MS,
                ),
                cooldownMs = intent.getLongExtra(EXTRA_COOLDOWN_MS, DEFAULT_COOLDOWN_MS),
                lowPassCutoffHz = intent.getDoubleExtra(
                    EXTRA_LOW_PASS_CUTOFF_HZ,
                    RepDetectorConfig.DEFAULT_LOW_PASS_CUTOFF_HZ,
                ),
                verticalAccelerationScale = intent.getDoubleExtra(
                    EXTRA_VERTICAL_ACCELERATION_SCALE,
                    DEFAULT_VERTICAL_ACCELERATION_SCALE,
                ),
            ),
        )
        count = 0
        accumulatedElapsedSeconds = 0L
        distanceMeters = 0.0
        caloriesKcal = 0.0
        walkingBaseCaloriesKcal = 0.0
        elevationCaloriesKcal = 0.0
        elevationGainMeters = 0.0
        previousAltitudeMeters = null
        smoothedLatitude = null
        smoothedLongitude = null
        steps = 0
        stepCounterBaseline = null
        lastStepSampleSteps = 0
        lastStepSampleMillis = 0L
        lastGpsSteps = 0
        lastGpsMillis = 0L
        lastShadowCompensationSteps = 0
        lastWalkingDistanceSteps = 0
        averageStrideMeters = defaultStrideMeters()
        gpsShadowDistanceMeters = 0.0
        stepWindow.clear()
        accelerationWindow.clear()
        currentSpeedMetersPerSecond = 0.0
        smoothedSpeedMetersPerSecond = 0.0
        averageSpeedMetersPerSecond = 0.0
        averagePaceSecondsPerKm = 0.0
        cadenceSpm = 0
        motionState = MOTION_STATIONARY
        pendingMotionState = MOTION_STATIONARY
        pendingMotionStateSinceMillis = 0L
        autoPaused = false
        stationarySinceMillis = 0L
        movingSinceMillis = 0L
        movingDurationMillis = 0L
        movingDurationSeconds = 0L
        previousLocation = null
        startedAtMillis = System.currentTimeMillis()
        resumedAtMillis = startedAtMillis
        lastCardioMetricsMillis = startedAtMillis
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
        if (isCardioExercise()) {
            registerCardioSensors()
            if (usesGps()) {
                registerLocationUpdates()
            }
            if (status == STATUS_MEASURING) {
                startCardioTicker()
            }
        } else {
            registerSensors()
        }
        emitState()
    }

    private fun stopTracking(storeCompletedSession: Boolean): Map<String, Any?> {
        if (status == STATUS_IDLE) {
            emitState()
            stopSelf()
            return stateMap()
        }

        unregisterSensors()
        stopCardioTicker()
        unregisterLocationUpdates()
        if (isCardioExercise() && status == STATUS_MEASURING) {
            updateCardioMetrics()
            accumulatedElapsedSeconds = elapsedSeconds()
            resumedAtMillis = 0L
        } else if (!isCardioExercise()) {
            caloriesKcal = calculateStrengthCalories()
        }
        endedAtMillis = System.currentTimeMillis()
        status = STATUS_COMPLETED
        val completedState = stateMap()
        if (storeCompletedSession && (count > 0 || elapsedSeconds() > 0)) {
            preferences.edit()
                .putString(KEY_COMPLETED_EXERCISE_TYPE, exerciseType)
                .putString(KEY_COMPLETED_STATUS, status)
                .putInt(KEY_COMPLETED_COUNT, count)
                .putLong(KEY_COMPLETED_ELAPSED_SECONDS, elapsedSeconds())
                .putLong(KEY_COMPLETED_ACTIVE_DURATION_SECONDS, elapsedSeconds())
                .putFloat(KEY_COMPLETED_DISTANCE_METERS, distanceMeters.toFloat())
                .putFloat(KEY_COMPLETED_CALORIES_KCAL, caloriesKcal.toFloat())
                .putInt(KEY_COMPLETED_STEPS, steps)
                .putLong(KEY_COMPLETED_MOVING_DURATION_SECONDS, movingDurationSeconds)
                .putFloat(KEY_COMPLETED_AVERAGE_SPEED_METERS_PER_SECOND, averageSpeedMetersPerSecond.toFloat())
                .putFloat(KEY_COMPLETED_AVERAGE_PACE_SECONDS_PER_KM, averagePaceSecondsPerKm.toFloat())
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
        if (isCardioExercise()) {
            updateCardioMetrics()
            accumulatedElapsedSeconds = elapsedSeconds()
            resumedAtMillis = 0L
            lastCardioMetricsMillis = 0L
            if (usesGps()) unregisterLocationUpdates()
            stopCardioTicker()
        }
        status = STATUS_PAUSED
        unregisterSensors()
        updateNotification()
        emitState()
    }

    private fun resumeTracking() {
        if (status != STATUS_PAUSED) return
        status = STATUS_MEASURING
        resumedAtMillis = System.currentTimeMillis()
        lastCardioMetricsMillis = resumedAtMillis
        if (isCardioExercise()) {
            registerCardioSensors()
            if (usesGps()) registerLocationUpdates()
            startCardioTicker()
        } else {
            registerSensors()
        }
        updateNotification()
        emitState()
    }

    private fun resetTracking() {
        count = 0
        accumulatedElapsedSeconds = 0L
        distanceMeters = 0.0
        caloriesKcal = 0.0
        walkingBaseCaloriesKcal = 0.0
        elevationCaloriesKcal = 0.0
        elevationGainMeters = 0.0
        previousAltitudeMeters = null
        smoothedLatitude = null
        smoothedLongitude = null
        steps = 0
        stepCounterBaseline = null
        lastStepSampleSteps = 0
        lastStepSampleMillis = 0L
        lastGpsSteps = 0
        lastGpsMillis = 0L
        lastShadowCompensationSteps = 0
        lastWalkingDistanceSteps = 0
        averageStrideMeters = defaultStrideMeters()
        gpsShadowDistanceMeters = 0.0
        stepWindow.clear()
        accelerationWindow.clear()
        currentSpeedMetersPerSecond = 0.0
        smoothedSpeedMetersPerSecond = 0.0
        averageSpeedMetersPerSecond = 0.0
        averagePaceSecondsPerKm = 0.0
        cadenceSpm = 0
        motionState = MOTION_STATIONARY
        pendingMotionState = MOTION_STATIONARY
        pendingMotionStateSinceMillis = 0L
        autoPaused = false
        stationarySinceMillis = 0L
        movingSinceMillis = 0L
        movingDurationMillis = 0L
        movingDurationSeconds = 0L
        lastCardioMetricsMillis = if (status == STATUS_MEASURING && isCardioExercise()) {
            System.currentTimeMillis()
        } else {
            0L
        }
        previousLocation = null
        if (status == STATUS_MEASURING && isCardioExercise()) {
            startedAtMillis = System.currentTimeMillis()
            resumedAtMillis = startedAtMillis
        }
        repDetector.reset()
        updateNotification()
        emitState()
    }

    private fun registerSensors() {
        verticalAccelerationSource?.stop()
        val source = VerticalAccelerationSource(sensorManager) { verticalAcceleration, timestampMs ->
            handleVerticalAcceleration(verticalAcceleration, timestampMs)
        }
        source.start()
        verticalAccelerationSource = source
    }

    private fun registerCardioSensors() {
        sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)?.also {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.also {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun unregisterSensors() {
        sensorManager.unregisterListener(this)
        verticalAccelerationSource?.stop()
        verticalAccelerationSource = null
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
            .setContentText(notificationText())
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
            "running" -> "런닝"
            "walking" -> "걷기"
            else -> "푸쉬업"
        }
    }

    private fun notificationText(): String {
        return when (exerciseType) {
            "running" -> "${formatKm(distanceMeters)} · ${formatPace(averagePaceSecondsPerKm)} · ${caloriesKcal.toInt()} kcal"
            "walking" -> "${formatNumber(steps)} 걸음 · ${formatDuration(elapsedSeconds())} · ${caloriesKcal.toInt()} kcal"
            else -> "${count}개 · ${caloriesKcal.toInt()} kcal"
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
            "elapsedSeconds" to elapsedSeconds(),
            "activeDurationSeconds" to elapsedSeconds(),
            "movingDurationSeconds" to movingDurationSeconds,
            "distanceMeters" to distanceMeters,
            "caloriesKcal" to caloriesKcal,
            "steps" to steps,
            "currentSpeedMetersPerSecond" to currentSpeedMetersPerSecond,
            "averageSpeedMetersPerSecond" to averageSpeedMetersPerSecond,
            "averagePaceSecondsPerKm" to averagePaceSecondsPerKm,
            "cadenceSpm" to cadenceSpm,
            "motionState" to motionState,
            "isAutoPaused" to autoPaused,
            "gpsShadowDistanceMeters" to gpsShadowDistanceMeters,
            "startedAtMillis" to startedAtMillis,
            "endedAtMillis" to endedAtMillis,
        )
    }

    private fun startCardioTicker() {
        handler.removeCallbacks(cardioTicker)
        handler.post(cardioTicker)
    }

    private fun stopCardioTicker() {
        handler.removeCallbacks(cardioTicker)
    }

    private fun updateCardioMetrics() {
        updateMovingDuration()
        if (exerciseType == "walking") {
            updateWalkingSpeed()
        }
        updateMotionState()
        if (exerciseType == "walking") {
            compensateWalkingStepDistance()
        }
        compensateGpsShadowDistance()
        updateAverages()
        // 워킹은 거리가 늘어난 그 순간(accumulateWalkingCalories)에 이미 적산되므로 여기서 다시 계산하지 않는다.
        // 세션 전체 평균속도를 전체 거리에 소급 적용하던 예전 방식으로 되돌아가지 않도록 주의.
        if (exerciseType != "walking") {
            refreshCardioCalories()
        }
    }

    private fun handleStepCounter(rawSteps: Int) {
        if (!isCardioExercise()) return

        val baseline = stepCounterBaseline
        if (baseline == null) {
            stepCounterBaseline = rawSteps
            lastStepSampleSteps = 0
            lastStepSampleMillis = System.currentTimeMillis()
            return
        }

        val now = System.currentTimeMillis()
        steps = (rawSteps - baseline).coerceAtLeast(0)
        stepWindow.addLast(now to steps)
        while (stepWindow.isNotEmpty() && now - stepWindow.first().first > STEP_WINDOW_MS) {
            stepWindow.removeFirst()
        }

        val oldest = stepWindow.firstOrNull()
        cadenceSpm = if (oldest == null) {
            0
        } else {
            ((steps - oldest.second).coerceAtLeast(0) * 60000.0 / STEP_WINDOW_MS).toInt()
        }
        lastStepSampleSteps = steps
        lastStepSampleMillis = now
    }

    private fun updateStrideFromGps(deltaDistance: Double, locationTimeMillis: Long) {
        if (!usesGps() || deltaDistance <= 0.0) return

        val stepDelta = (steps - lastGpsSteps).coerceAtLeast(0)
        val minSteps = if (exerciseType == "walking") {
            MIN_WALKING_STRIDE_SAMPLE_STEPS
        } else {
            MIN_STRIDE_SAMPLE_STEPS
        }
        val maxSteps = if (exerciseType == "walking") {
            MAX_WALKING_STRIDE_SAMPLE_STEPS
        } else {
            MAX_STRIDE_SAMPLE_STEPS
        }
        if (stepDelta in minSteps..maxSteps) {
            val stride = deltaDistance / stepDelta
            if (stride in minStrideMeters()..maxStrideMeters()) {
                averageStrideMeters = STRIDE_EMA_ALPHA * stride +
                    (1 - STRIDE_EMA_ALPHA) * averageStrideMeters
            }
        }

        lastGpsSteps = steps
        lastGpsMillis = locationTimeMillis
    }

    private fun compensateWalkingStepDistance() {
        if (exerciseType != "walking" || autoPaused || motionState == MOTION_VEHICLE) return
        if (accelerationRange() < WALKING_ACCELERATION_ACTIVE_RANGE && recentStepDelta() <= 0) return

        val uncompensatedSteps = (steps - lastWalkingDistanceSteps).coerceAtLeast(0)
        if (uncompensatedSteps <= 0) return

        val estimatedDistance = uncompensatedSteps * averageStrideMeters
        if (estimatedDistance > WALKING_MAX_STEP_COMPENSATION_METERS) return

        distanceMeters += estimatedDistance
        lastWalkingDistanceSteps = steps
        accumulateWalkingCalories(estimatedDistance)
    }

    private fun compensateGpsShadowDistance() {
        if (exerciseType != "running" || autoPaused || motionState == MOTION_VEHICLE) return

        val now = System.currentTimeMillis()
        if (lastGpsMillis <= 0L) return

        val gpsGapMillis = now - lastGpsMillis
        if (gpsGapMillis !in GPS_SHADOW_MIN_GAP_MS..GPS_SHADOW_MAX_GAP_MS) return

        val uncompensatedSteps = (steps - lastShadowCompensationSteps).coerceAtLeast(0)
        if (uncompensatedSteps <= 0) return

        val estimatedDistance = uncompensatedSteps * averageStrideMeters
        if (estimatedDistance > GPS_SHADOW_MAX_COMPENSATION_METERS) return

        distanceMeters += estimatedDistance
        gpsShadowDistanceMeters += estimatedDistance
        lastShadowCompensationSteps = steps
    }

    private fun handleCardioAcceleration(magnitude: Double) {
        val now = System.currentTimeMillis()
        accelerationWindow.addLast(now to magnitude)
        while (
            accelerationWindow.isNotEmpty() &&
            now - accelerationWindow.first().first > ACCELERATION_WINDOW_MS
        ) {
            accelerationWindow.removeFirst()
        }
    }

    /**
     * GPS 칩이 도플러 편이로 직접 계산한 속도(Location.speed)를 우선 쓴다.
     * 위치 두 점을 미분해서 구하는 속도보다 노이즈가 훨씬 적다 — 특히 업데이트 간격이
     * 1초 안팎으로 짧은 러닝에서는 위치 오차가 시간으로 나뉘며 크게 증폭되기 때문이다.
     * 기기가 유효한 속도를 못 주면 위치 차분으로 계산한 값으로 대체한다.
     */
    private fun updateSpeed(instantSpeedMetersPerSecond: Double, alpha: Double = SPEED_EMA_ALPHA) {
        currentSpeedMetersPerSecond = instantSpeedMetersPerSecond
        smoothedSpeedMetersPerSecond =
            if (smoothedSpeedMetersPerSecond <= 0.0) {
                instantSpeedMetersPerSecond
            } else {
                alpha * instantSpeedMetersPerSecond +
                    (1 - alpha) * smoothedSpeedMetersPerSecond
            }
    }

    private fun updateWalkingSpeed() {
        if (lastGpsMillis > 0L && System.currentTimeMillis() - lastGpsMillis <= WALKING_SPEED_GPS_FRESH_MS) {
            return
        }
        currentSpeedMetersPerSecond = cadenceSpm * averageStrideMeters / 60.0
        smoothedSpeedMetersPerSecond =
            if (smoothedSpeedMetersPerSecond <= 0.0) {
                currentSpeedMetersPerSecond
            } else {
                WALKING_SPEED_EMA_ALPHA * currentSpeedMetersPerSecond +
                    (1 - WALKING_SPEED_EMA_ALPHA) * smoothedSpeedMetersPerSecond
            }
    }

    private fun updateMovingDuration() {
        if (status != STATUS_MEASURING || !isCardioExercise()) return

        val now = System.currentTimeMillis()
        val previous = lastCardioMetricsMillis
        if (previous > 0L && !autoPaused && motionState != MOTION_VEHICLE) {
            movingDurationMillis += (now - previous).coerceAtLeast(0L)
        }
        lastCardioMetricsMillis = now
        movingDurationSeconds = movingDurationMillis / 1000L
    }

    private fun updateAverages() {
        averageSpeedMetersPerSecond = if (movingDurationSeconds <= 0L) {
            0.0
        } else {
            distanceMeters / movingDurationSeconds
        }
        // 평균 속도와 같은 시간 기준(이동 시간)을 써야 두 값이 서로 앞뒤가 맞는다.
        // 예전에는 러닝만 전체 경과시간(신호대기 등 정지 구간 포함)을 써서 평균 속도로
        // 역산한 페이스와 표시되는 페이스가 서로 맞지 않았다.
        averagePaceSecondsPerKm = if (distanceMeters <= 0.0 || movingDurationSeconds <= 0L) {
            0.0
        } else {
            movingDurationSeconds / (distanceMeters / 1000.0)
        }
    }

    private fun updateMotionState() {
        val now = System.currentTimeMillis()
        val speedKmh = smoothedSpeedMetersPerSecond * 3.6
        val accelerationActive = accelerationRange() >= accelerationActiveRange()
        val recentSteps = recentStepDelta()
        val candidate = if (exerciseType == "walking") {
            when {
                speedKmh >= WALKING_VEHICLE_SPEED_KMH && recentSteps == 0 && !accelerationActive -> MOTION_VEHICLE
                speedKmh >= WALKING_RUNNING_SPEED_KMH && cadenceSpm >= WALKING_RUNNING_MIN_CADENCE && accelerationActive -> MOTION_RUNNING
                speedKmh in FAST_WALKING_MIN_SPEED_KMH..FAST_WALKING_MAX_SPEED_KMH &&
                    cadenceSpm in FAST_WALKING_MIN_CADENCE..FAST_WALKING_MAX_CADENCE -> MOTION_FAST_WALKING
                speedKmh in WALKING_MIN_SPEED_KMH..WALKING_NORMAL_MAX_SPEED_KMH &&
                    cadenceSpm in WALKING_MIN_CADENCE..WALKING_NORMAL_MAX_CADENCE -> MOTION_WALKING
                speedKmh < WALKING_STATIONARY_MAX_SPEED_KMH && recentSteps == 0 && !accelerationActive -> MOTION_STATIONARY
                else -> motionState
            }
        } else {
            when {
                speedKmh >= VEHICLE_SPEED_KMH && recentSteps == 0 && !accelerationActive -> MOTION_VEHICLE
                speedKmh >= RUNNING_MIN_SPEED_KMH && cadenceSpm >= RUNNING_MIN_CADENCE && accelerationActive -> MOTION_RUNNING
                speedKmh in WALKING_MIN_SPEED_KMH..WALKING_MAX_SPEED_KMH &&
                    cadenceSpm in WALKING_MIN_CADENCE..WALKING_MAX_CADENCE -> MOTION_WALKING
                speedKmh < STATIONARY_MAX_SPEED_KMH && recentSteps == 0 && !accelerationActive -> MOTION_STATIONARY
                else -> motionState
            }
        }

        if (candidate != pendingMotionState) {
            pendingMotionState = candidate
            pendingMotionStateSinceMillis = now
        } else if (candidate != motionState && now - pendingMotionStateSinceMillis >= MOTION_CHANGE_HOLD_MS) {
            motionState = candidate
        }

        updateAutoPause(now)
    }

    private fun updateAutoPause(now: Long) {
        if (motionState == MOTION_STATIONARY) {
            if (stationarySinceMillis == 0L) stationarySinceMillis = now
            movingSinceMillis = 0L
            if (now - stationarySinceMillis >= autoPauseHoldMs()) {
                autoPaused = true
            }
            return
        }

        if (motionState == MOTION_RUNNING || motionState == MOTION_WALKING || motionState == MOTION_FAST_WALKING) {
            if (movingSinceMillis == 0L) movingSinceMillis = now
            stationarySinceMillis = 0L
            if (now - movingSinceMillis >= AUTO_RESUME_HOLD_MS) {
                autoPaused = false
            }
        }
    }

    private fun accelerationRange(): Double {
        if (accelerationWindow.isEmpty()) return 0.0
        var min = Double.MAX_VALUE
        var max = Double.MIN_VALUE
        for ((_, value) in accelerationWindow) {
            min = kotlin.math.min(min, value)
            max = kotlin.math.max(max, value)
        }
        return abs(max - min)
    }

    private fun recentStepDelta(): Int {
        val first = stepWindow.firstOrNull()?.second ?: steps
        return (steps - first).coerceAtLeast(0)
    }

    private fun elapsedSeconds(): Long {
        val liveSeconds = if (status == STATUS_MEASURING && resumedAtMillis > 0L) {
            ((System.currentTimeMillis() - resumedAtMillis) / 1000L).coerceAtLeast(0L)
        } else {
            0L
        }
        return accumulatedElapsedSeconds + liveSeconds
    }

    @Suppress("MissingPermission")
    private fun registerLocationUpdates() {
        if (!hasLocationPermission()) {
            status = STATUS_FAILED
            emitState()
            return
        }

        previousLocation = null
        val provider = when {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> null
        } ?: run {
            status = STATUS_FAILED
            emitState()
            return
        }

        locationManager.requestLocationUpdates(
            provider,
            minLocationDeltaMs(),
            minLocationDistanceMeters().toFloat(),
            this,
        )
    }

    private fun unregisterLocationUpdates() {
        locationManager.removeUpdates(this)
        previousLocation = null
    }

    private fun hasLocationPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun isValidLocation(location: Location): Boolean {
        return !location.hasAccuracy() || location.accuracy <= MAX_LOCATION_ACCURACY_METERS
    }

    /** 러닝은 페이스에 거의 무관하게 거리당 에너지 소비가 일정하다는 근사를 그대로 쓴다. */
    private fun calculateRunningCalories(distanceMeters: Double): Double {
        if (weightKg <= 0.0 || distanceMeters <= 0.0) return 0.0
        return weightKg * (distanceMeters / 1000.0)
    }

    /**
     * 워킹은 속도에 따라 거리당 에너지 소비 계수가 달라지므로, 거리가 늘어난 바로 그 구간의
     * 순간 속도로 계수를 정해 그 구간 거리에만 곱해 누적한다.
     *
     * 예전에는 "세션 전체 평균속도로 정한 계수"를 "지금까지의 전체 누적거리"에 매번 다시
     * 곱했다. 페이스가 바뀌면(대부분의 워킹이 그렇다) 이미 걸어온 거리 전체의 칼로리가
     * 새 계수로 소급 재계산되어, 페이스 변화 패턴과 무관하게 총 거리·총 시간만 같으면
     * 같은 칼로리가 나오는 부정확한 결과를 냈다.
     */
    private fun accumulateWalkingCalories(deltaDistanceMeters: Double) {
        if (weightKg <= 0.0 || deltaDistanceMeters <= 0.0) return

        val deltaKm = deltaDistanceMeters / 1000.0
        val speedKmh = smoothedSpeedMetersPerSecond * 3.6
        val coefficient = when {
            speedKmh < WALKING_CALORIE_NORMAL_SPEED_KMH -> WALKING_SLOW_CALORIE_COEFFICIENT
            speedKmh < WALKING_CALORIE_FAST_SPEED_KMH -> WALKING_NORMAL_CALORIE_COEFFICIENT
            else -> WALKING_FAST_CALORIE_COEFFICIENT
        }
        walkingBaseCaloriesKcal += weightKg * deltaKm * coefficient
        refreshCardioCalories()
    }

    /** 기본 칼로리(러닝은 재계산, 워킹은 누적값)에 고도 보정치를 더해 최종 표시값을 만든다. */
    private fun refreshCardioCalories() {
        val base = if (exerciseType == "walking") {
            walkingBaseCaloriesKcal
        } else {
            calculateRunningCalories(distanceMeters)
        }
        caloriesKcal = base + elevationCaloriesKcal
    }

    private fun calculateStrengthCalories(): Double {
        if (weightKg <= 0.0 || count <= 0) return 0.0

        val met = when (exerciseType) {
            "push-up" -> PUSH_UP_MET
            "pull-up" -> PULL_UP_MET
            else -> 0.0
        }
        val secondsPerRep = when (exerciseType) {
            "push-up" -> PUSH_UP_SECONDS_PER_REP
            "pull-up" -> PULL_UP_SECONDS_PER_REP
            else -> 0.0
        }
        if (met <= 0.0 || secondsPerRep <= 0.0) return 0.0

        val durationSeconds = elapsedSeconds().coerceAtLeast(0L).toDouble()
        if (durationSeconds <= 0.0) return 0.0

        val estimatedActiveSeconds = count * secondsPerRep * STRENGTH_ACTIVE_TIME_BUFFER
        val activeSeconds = kotlin.math.min(durationSeconds, estimatedActiveSeconds)
        val activeMinutes = activeSeconds / 60.0
        return met * 3.5 * weightKg / 200.0 * activeMinutes
    }

    private fun isCardioExercise(): Boolean {
        return exerciseType == "running" || exerciseType == "walking"
    }

    private fun usesGps(): Boolean {
        return exerciseType == "running" || exerciseType == "walking"
    }

    /**
     * GPS로 보폭이 학습되기 전까지 쓸 출발값. 키를 입력했다면 키 기반으로 추정하고,
     * 아니면 인구 평균에 해당하는 고정값을 쓴다. 키 기반 추정은 GPS 학습이 시작되면
     * 곧바로 사용자 실측값으로 대체되므로, 정밀할 필요 없이 방향만 맞으면 된다.
     */
    private fun defaultStrideMeters(): Double {
        if (heightCm > 0.0) {
            val factor = if (exerciseType == "walking") {
                WALKING_STRIDE_HEIGHT_FACTOR
            } else {
                RUNNING_STRIDE_HEIGHT_FACTOR
            }
            val estimate = heightCm * factor / 100.0
            return estimate.coerceIn(minStrideMeters(), maxStrideMeters())
        }
        return if (exerciseType == "walking") DEFAULT_WALKING_STRIDE_METERS else DEFAULT_RUNNING_STRIDE_METERS
    }

    private fun minStrideMeters(): Double {
        return if (exerciseType == "walking") MIN_WALKING_STRIDE_METERS else MIN_RUNNING_STRIDE_METERS
    }

    private fun maxStrideMeters(): Double {
        return if (exerciseType == "walking") MAX_WALKING_STRIDE_METERS else MAX_RUNNING_STRIDE_METERS
    }

    private fun minLocationDeltaMs(): Long {
        return if (exerciseType == "walking") WALKING_MIN_LOCATION_DELTA_MS else MIN_LOCATION_DELTA_MS
    }

    private fun minLocationDistanceMeters(): Double {
        return if (exerciseType == "walking") WALKING_MIN_LOCATION_DISTANCE_METERS else MIN_LOCATION_DISTANCE_METERS
    }

    private fun accelerationActiveRange(): Double {
        return if (exerciseType == "walking") WALKING_ACCELERATION_ACTIVE_RANGE else ACCELERATION_ACTIVE_RANGE
    }

    private fun autoPauseHoldMs(): Long {
        return if (exerciseType == "walking") WALKING_AUTO_PAUSE_HOLD_MS else AUTO_PAUSE_HOLD_MS
    }

    private fun formatKm(meters: Double): String {
        return String.format(Locale.US, "%.2f km", meters / 1000.0)
    }

    private fun formatDuration(seconds: Long): String {
        val minutes = (seconds / 60L) % 60L
        val remainingSeconds = seconds % 60L
        val hours = seconds / 3600L
        return if (hours <= 0L) {
            String.format(Locale.US, "%02d:%02d", minutes, remainingSeconds)
        } else {
            String.format(Locale.US, "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
    }

    private fun formatPace(secondsPerKm: Double): String {
        if (secondsPerKm <= 0.0 || secondsPerKm.isInfinite() || secondsPerKm.isNaN()) {
            return "--'--\"/km"
        }
        val minutes = (secondsPerKm / 60).toInt()
        val seconds = (secondsPerKm.toInt() % 60)
        return String.format(Locale.US, "%d'%02d\"/km", minutes, seconds)
    }

    private fun formatNumber(value: Int): String {
        return String.format(Locale.US, "%,d", value)
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
            val foregroundServiceType = if (usesGps()) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
            }
            startForeground(
                NOTIFICATION_ID,
                buildNotification(),
                foregroundServiceType,
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
        const val EXTRA_AMPLITUDE_THRESHOLD = "amplitudeThreshold"
        const val EXTRA_MIN_HALF_PERIOD_MS = "minHalfPeriodMs"
        const val EXTRA_MAX_HALF_PERIOD_MS = "maxHalfPeriodMs"
        const val EXTRA_LOW_PASS_CUTOFF_HZ = "lowPassCutoffHz"
        const val EXTRA_VERTICAL_ACCELERATION_SCALE = "verticalAccelerationScale"
        const val EXTRA_COOLDOWN_MS = "cooldownMs"
        const val EXTRA_WEIGHT_KG = "weightKg"
        const val EXTRA_HEIGHT_CM = "heightCm"

        // "초기 걷기 보폭 ≈ 키 x 0.40~0.43" (docs/walking_guide.md) 의 중간값.
        private const val WALKING_STRIDE_HEIGHT_FACTOR = 0.415

        // 조깅 페이스 기준 근사치. 워킹보다 보폭이 뚜렷이 길다는 방향만 반영한다.
        private const val RUNNING_STRIDE_HEIGHT_FACTOR = 0.57

        private const val DEFAULT_AMPLITUDE_THRESHOLD = 0.8
        private const val DEFAULT_MIN_HALF_PERIOD_MS = 250L
        private const val DEFAULT_MAX_HALF_PERIOD_MS = 2500L
        private const val DEFAULT_COOLDOWN_MS = 800L
        private const val DEFAULT_VERTICAL_ACCELERATION_SCALE = 1.0

        private const val CHANNEL_ID = "workout_tracking"
        private const val NOTIFICATION_ID = 1201
        private const val PREFERENCES_NAME = "workout_tracking_service"
        private const val KEY_COMPLETED_EXERCISE_TYPE = "completedExerciseType"
        private const val KEY_COMPLETED_STATUS = "completedStatus"
        private const val KEY_COMPLETED_COUNT = "completedCount"
        private const val KEY_COMPLETED_ELAPSED_SECONDS = "completedElapsedSeconds"
        private const val KEY_COMPLETED_ACTIVE_DURATION_SECONDS = "completedActiveDurationSeconds"
        private const val KEY_COMPLETED_MOVING_DURATION_SECONDS = "completedMovingDurationSeconds"
        private const val KEY_COMPLETED_DISTANCE_METERS = "completedDistanceMeters"
        private const val KEY_COMPLETED_CALORIES_KCAL = "completedCaloriesKcal"
        private const val KEY_COMPLETED_STEPS = "completedSteps"
        private const val KEY_COMPLETED_AVERAGE_SPEED_METERS_PER_SECOND = "completedAverageSpeedMetersPerSecond"
        private const val KEY_COMPLETED_AVERAGE_PACE_SECONDS_PER_KM = "completedAveragePaceSecondsPerKm"
        private const val KEY_COMPLETED_STARTED_AT = "completedStartedAt"
        private const val KEY_COMPLETED_ENDED_AT = "completedEndedAt"
        private const val WALKING_STEP_LENGTH_METERS = 0.7
        private const val DEFAULT_WALKING_STRIDE_METERS = 0.7
        private const val MIN_WALKING_STRIDE_METERS = 0.3
        private const val MAX_WALKING_STRIDE_METERS = 1.3
        private const val DEFAULT_RUNNING_STRIDE_METERS = 1.0
        private const val MIN_RUNNING_STRIDE_METERS = 0.6
        private const val MAX_RUNNING_STRIDE_METERS = 2.2
        private const val STRIDE_EMA_ALPHA = 0.2
        private const val MIN_STRIDE_SAMPLE_STEPS = 4
        private const val MAX_STRIDE_SAMPLE_STEPS = 120
        private const val MIN_WALKING_STRIDE_SAMPLE_STEPS = 4
        private const val MAX_WALKING_STRIDE_SAMPLE_STEPS = 160
        private const val GPS_SHADOW_MIN_GAP_MS = 5_000L
        private const val GPS_SHADOW_MAX_GAP_MS = 15_000L
        private const val GPS_SHADOW_MAX_COMPENSATION_METERS = 40.0
        private const val WALKING_MAX_STEP_COMPENSATION_METERS = 25.0
        private const val STEP_WINDOW_MS = 10_000L
        private const val ACCELERATION_WINDOW_MS = 3_000L
        private const val ACCELERATION_ACTIVE_RANGE = 1.2
        private const val WALKING_ACCELERATION_ACTIVE_RANGE = 0.8
        private const val SPEED_EMA_ALPHA = 0.35
        private const val WALKING_SPEED_EMA_ALPHA = 0.2
        private const val MIN_LOCATION_DELTA_MS = 1000L
        private const val WALKING_MIN_LOCATION_DELTA_MS = 2_000L
        private const val MIN_LOCATION_DISTANCE_METERS = 2.0
        private const val WALKING_MIN_LOCATION_DISTANCE_METERS = 1.0

        // 30m -> 20m. 스마트폰 GPS는 하늘이 트인 곳에서 보통 3~8m, 도심에서도 20m 안팎이라
        // 30m까지 허용하면 이미 상당히 나쁜 픽스도 거리 계산에 들어간다.
        private const val MAX_LOCATION_ACCURACY_METERS = 20.0f
        private const val MAX_RUNNING_SPEED_METERS_PER_SECOND = 8.0

        /** 거리 계산용 좌표 스무딩 계수. 기존 속도 EMA(0.2~0.35)와 비슷한 크기로 맞췄다. */
        private const val POSITION_EMA_ALPHA = 0.3

        // GPS 고도는 수평 위치보다 오차가 크다. 노이즈 수준의 미세 변화는 무시하고,
        // 한 번에 비정상적으로 큰 변화는 튐으로 보고 버린다.
        private const val MIN_ELEVATION_GAIN_DELTA_METERS = 1.0
        private const val MAX_ELEVATION_GAIN_JUMP_METERS = 15.0

        // 체중(kg) x 상승고도(m) x 계수. 상승에 드는 위치에너지(m*g*h)를 등반 시
        // 기계효율 약 20%로 나눠 대략적인 대사 비용으로 환산한 값이다. 정밀한 값이 아니라
        // "오르막이 평지보다 더 든다"는 방향을 반영하기 위한 근사치다.
        private const val ELEVATION_GAIN_CALORIES_PER_KG_METER = 0.01
        private const val WALKING_MAX_LOCATION_JUMP_METERS = 60.0
        private const val WALKING_SPEED_GPS_FRESH_MS = 10_000L
        private const val STATIONARY_MAX_SPEED_KMH = 1.0
        private const val WALKING_STATIONARY_MAX_SPEED_KMH = 0.8
        private const val WALKING_MIN_SPEED_KMH = 1.0
        private const val WALKING_NORMAL_MAX_SPEED_KMH = 5.5
        private const val WALKING_MAX_SPEED_KMH = 7.0
        private const val FAST_WALKING_MIN_SPEED_KMH = 4.5
        private const val FAST_WALKING_MAX_SPEED_KMH = 7.0
        private const val RUNNING_MIN_SPEED_KMH = 6.0
        private const val VEHICLE_SPEED_KMH = 20.0
        private const val WALKING_VEHICLE_SPEED_KMH = 15.0
        private const val WALKING_RUNNING_SPEED_KMH = 7.0
        private const val WALKING_MIN_CADENCE = 60
        private const val WALKING_NORMAL_MAX_CADENCE = 120
        private const val WALKING_MAX_CADENCE = 140
        private const val FAST_WALKING_MIN_CADENCE = 110
        private const val FAST_WALKING_MAX_CADENCE = 150
        private const val RUNNING_MIN_CADENCE = 140
        private const val WALKING_RUNNING_MIN_CADENCE = 150
        private const val MOTION_CHANGE_HOLD_MS = 3_000L
        private const val AUTO_PAUSE_HOLD_MS = 5_000L
        private const val WALKING_AUTO_PAUSE_HOLD_MS = 7_000L
        private const val AUTO_RESUME_HOLD_MS = 3_000L
        private const val MOTION_STATIONARY = "stationary"
        private const val MOTION_WALKING = "walking"
        private const val MOTION_FAST_WALKING = "fastWalking"
        private const val MOTION_RUNNING = "running"
        private const val MOTION_VEHICLE = "vehicle"
        private const val WALKING_CALORIE_NORMAL_SPEED_KMH = 4.0
        private const val WALKING_CALORIE_FAST_SPEED_KMH = 5.5
        private const val WALKING_SLOW_CALORIE_COEFFICIENT = 0.4
        private const val WALKING_NORMAL_CALORIE_COEFFICIENT = 0.5
        private const val WALKING_FAST_CALORIE_COEFFICIENT = 0.6
        private const val PUSH_UP_MET = 3.8
        private const val PULL_UP_MET = 6.0
        private const val PUSH_UP_SECONDS_PER_REP = 2.5
        private const val PULL_UP_SECONDS_PER_REP = 4.0
        private const val STRENGTH_ACTIVE_TIME_BUFFER = 1.3
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
            amplitudeThreshold: Double,
            minHalfPeriodMs: Long,
            maxHalfPeriodMs: Long,
            cooldownMs: Long,
            lowPassCutoffHz: Double,
            verticalAccelerationScale: Double,
            weightKg: Double,
            heightCm: Double,
        ): Intent {
            return Intent(context, WorkoutTrackingService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_EXERCISE_TYPE, exerciseType)
                .putExtra(EXTRA_AMPLITUDE_THRESHOLD, amplitudeThreshold)
                .putExtra(EXTRA_MIN_HALF_PERIOD_MS, minHalfPeriodMs)
                .putExtra(EXTRA_MAX_HALF_PERIOD_MS, maxHalfPeriodMs)
                .putExtra(EXTRA_COOLDOWN_MS, cooldownMs)
                .putExtra(EXTRA_LOW_PASS_CUTOFF_HZ, lowPassCutoffHz)
                .putExtra(EXTRA_VERTICAL_ACCELERATION_SCALE, verticalAccelerationScale)
                .putExtra(EXTRA_WEIGHT_KG, weightKg)
                .putExtra(EXTRA_HEIGHT_CM, heightCm)
        }

        fun commandIntent(context: Context, action: String): Intent {
            return Intent(context, WorkoutTrackingService::class.java).setAction(action)
        }

        fun idleState(): Map<String, Any?> {
            return mapOf(
                "exerciseType" to DEFAULT_EXERCISE_TYPE,
                "status" to STATUS_IDLE,
                "count" to 0,
                "elapsedSeconds" to 0L,
                "activeDurationSeconds" to 0L,
                "movingDurationSeconds" to 0L,
                "distanceMeters" to 0.0,
                "caloriesKcal" to 0.0,
                "steps" to 0,
                "currentSpeedMetersPerSecond" to 0.0,
                "averageSpeedMetersPerSecond" to 0.0,
                "averagePaceSecondsPerKm" to 0.0,
                "cadenceSpm" to 0,
                "motionState" to MOTION_STATIONARY,
                "isAutoPaused" to false,
                "gpsShadowDistanceMeters" to 0.0,
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
                "elapsedSeconds" to preferences.getLong(KEY_COMPLETED_ELAPSED_SECONDS, 0L),
                "activeDurationSeconds" to preferences.getLong(
                    KEY_COMPLETED_ACTIVE_DURATION_SECONDS,
                    preferences.getLong(KEY_COMPLETED_ELAPSED_SECONDS, 0L),
                ),
                "movingDurationSeconds" to preferences.getLong(KEY_COMPLETED_MOVING_DURATION_SECONDS, 0L),
                "distanceMeters" to preferences.getFloat(KEY_COMPLETED_DISTANCE_METERS, 0f).toDouble(),
                "caloriesKcal" to preferences.getFloat(KEY_COMPLETED_CALORIES_KCAL, 0f).toDouble(),
                "steps" to preferences.getInt(KEY_COMPLETED_STEPS, 0),
                "averageSpeedMetersPerSecond" to preferences.getFloat(KEY_COMPLETED_AVERAGE_SPEED_METERS_PER_SECOND, 0f).toDouble(),
                "averagePaceSecondsPerKm" to preferences.getFloat(KEY_COMPLETED_AVERAGE_PACE_SECONDS_PER_KM, 0f).toDouble(),
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

        private fun defaultRepDetector(): RepDetector {
            return RepDetector(
                RepDetectorConfig(
                    amplitudeThreshold = DEFAULT_AMPLITUDE_THRESHOLD,
                    minHalfPeriodMs = DEFAULT_MIN_HALF_PERIOD_MS,
                    maxHalfPeriodMs = DEFAULT_MAX_HALF_PERIOD_MS,
                    cooldownMs = DEFAULT_COOLDOWN_MS,
                ),
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
