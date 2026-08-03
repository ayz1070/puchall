import CoreLocation
import CoreMotion
import Foundation

/// Android `WorkoutTrackingService.kt`의 iOS 대응 구현.
///
/// iOS는 Android의 "포그라운드 서비스"에 해당하는 개념이 없다. DeviceMotion으로 카운트하는
/// 푸시업/풀업은 앱이 포그라운드에 있을 때만 동작하고(iOS가 백그라운드에서 모션 콜백
/// 전달을 보장하지 않음), GPS 기반인 러닝/워킹은 `location` 백그라운드 모드를 통해
/// Android와 동등하게 백그라운드에서도 계속 추적한다.
final class WorkoutTrackingManager: NSObject {
    static let shared = WorkoutTrackingManager()

    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    private let locationManager = CLLocationManager()

    private var exerciseType = WorkoutTrackingManager.defaultExerciseType
    private var status = WorkoutTrackingManager.statusIdle
    private var count = 0
    private var startedAtMillis: Double = 0
    private var endedAtMillis: Double = 0
    private var weightKg: Double = 70.0

    /// 0이면 "입력 안 함"으로 보고 고정 기본 보폭을 쓴다.
    private var heightCm: Double = 0.0
    private var repDetector = RepDetector(
        config: RepDetectorConfig(
            amplitudeThreshold: WorkoutTrackingManager.defaultAmplitudeThreshold,
            minHalfPeriodMs: WorkoutTrackingManager.defaultMinHalfPeriodMs,
            maxHalfPeriodMs: WorkoutTrackingManager.defaultMaxHalfPeriodMs,
            cooldownMs: WorkoutTrackingManager.defaultCooldownMs
        )
    )
    private var verticalAccelerationSource: VerticalAccelerationSource?

    private var distanceMeters: Double = 0.0
    private var caloriesKcal: Double = 0.0

    /// 워킹 전용 누적 칼로리. 구간마다 그 순간 속도의 계수로 적산한다(세션 평균 소급 적용 금지).
    private var walkingBaseCaloriesKcal: Double = 0.0

    /// 상승 고도에 대한 추가 칼로리. 러닝/워킹 공통으로 적산한다.
    private var elevationCaloriesKcal: Double = 0.0
    private var elevationGainMeters: Double = 0.0
    private var previousAltitudeMeters: Double?

    /// 거리 계산용으로 EMA 스무딩한 좌표. GPS 지터로 인한 거리 과대추정을 줄인다.
    private var smoothedLatitude: Double?
    private var smoothedLongitude: Double?
    private var steps: Int = 0
    private var previousLocation: CLLocation?
    private var lastGpsSteps: Int = 0
    private var lastGpsMillis: Double = 0
    private var lastShadowCompensationSteps: Int = 0
    private var lastWalkingDistanceSteps: Int = 0
    private var averageStrideMeters: Double = WorkoutTrackingManager.defaultRunningStrideMeters
    private var gpsShadowDistanceMeters: Double = 0.0
    private var currentSpeedMetersPerSecond: Double = 0.0
    private var smoothedSpeedMetersPerSecond: Double = 0.0
    private var averageSpeedMetersPerSecond: Double = 0.0
    private var averagePaceSecondsPerKm: Double = 0.0
    private var cadenceSpm: Int = 0
    private var stepWindow: [(millis: Double, steps: Int)] = []
    private var accelerationWindow: [(millis: Double, value: Double)] = []
    private var motionState = WorkoutTrackingManager.motionStationary
    private var pendingMotionState = WorkoutTrackingManager.motionStationary
    private var pendingMotionStateSinceMillis: Double = 0
    private var autoPaused = false
    private var stationarySinceMillis: Double = 0
    private var movingSinceMillis: Double = 0
    private var movingDurationMillis: Double = 0
    private var movingDurationSeconds: Int64 = 0
    private var cardioTicker: Timer?

    /// Flutter EventChannel로 상태를 흘려보내는 콜백. `nil`이면 아무도 구독하고 있지 않다는 뜻.
    var onStateChange: (([String: Any]) -> Void)?

    /// 캘리브레이션 중 원시 수직 가속도 샘플을 흘려보내는 콜백.
    var onCalibrationSample: ((Double, Double) -> Void)?

    /// 측정용과 분리해 두어야 캘리브레이션이 측정 세션을 건드리지 않는다.
    private let calibrationMotionManager = CMMotionManager()
    private var calibrationSource: VerticalAccelerationSource?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
    }

    // MARK: - Public API (MethodChannel에서 호출)

    enum StartError: Error {
        case permissionRequired
    }

    func start(args: [String: Any]) throws {
        let type = args["exerciseType"] as? String ?? Self.defaultExerciseType
        exerciseType = type
        weightKg = (args["weightKg"] as? NSNumber)?.doubleValue ?? 70.0
        heightCm = (args["heightCm"] as? NSNumber)?.doubleValue ?? 0.0

        if isCardioExercise() {
            let authorization = locationAuthorizationStatus()
            switch authorization {
            case .denied, .restricted:
                throw StartError.permissionRequired
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                throw StartError.permissionRequired
            case .authorizedWhenInUse:
                // 이번 세션은 포그라운드에서만 추적하고, "항상 허용"으로 승격을 요청해둔다.
                locationManager.requestAlwaysAuthorization()
            default:
                break
            }
        } else {
            repDetector = RepDetector(
                config: RepDetectorConfig(
                    amplitudeThreshold: (args["amplitudeThreshold"] as? NSNumber)?.doubleValue
                        ?? Self.defaultAmplitudeThreshold,
                    minHalfPeriodMs: (args["minHalfPeriodMs"] as? NSNumber)?.doubleValue
                        ?? Self.defaultMinHalfPeriodMs,
                    maxHalfPeriodMs: (args["maxHalfPeriodMs"] as? NSNumber)?.doubleValue
                        ?? Self.defaultMaxHalfPeriodMs,
                    cooldownMs: (args["cooldownMs"] as? NSNumber)?.doubleValue
                        ?? Self.defaultCooldownMs,
                    lowPassCutoffHz: (args["lowPassCutoffHz"] as? NSNumber)?.doubleValue
                        ?? RepDetectorConfig.defaultLowPassCutoffHz,
                    verticalAccelerationScale:
                        (args["verticalAccelerationScale"] as? NSNumber)?.doubleValue ?? 1.0
                )
            )
        }

        resetSessionState()
        startedAtMillis = nowMillis()
        endedAtMillis = 0
        status = Self.statusMeasuring

        if isCardioExercise() {
            startCardioTracking()
        } else {
            startStrengthTracking()
        }
        emitState()
    }

    func stop() -> [String: Any] {
        guard status == Self.statusMeasuring else {
            return stateMap()
        }

        stopAllUpdates()
        if isCardioExercise() {
            updateCardioMetrics()
        } else {
            caloriesKcal = calculateStrengthCalories()
        }
        endedAtMillis = nowMillis()
        status = Self.statusCompleted
        let completed = stateMap()
        emitState()
        return completed
    }

    func reset() {
        resetSessionState()
        if status == Self.statusMeasuring && isCardioExercise() {
            startedAtMillis = nowMillis()
        }
        repDetector.reset()
        emitState()
    }

    func currentStateMap() -> [String: Any] {
        stateMap()
    }

    // MARK: - 기준치 캘리브레이션

    /// 측정과 **같은** [VerticalAccelerationSource]를 같은 샘플링 간격으로 돌려서,
    /// 여기서 뽑은 기준치가 실제 측정에 그대로 적용되도록 한다.
    func startCalibration() {
        stopCalibration()
        let source = VerticalAccelerationSource(motionManager: calibrationMotionManager) {
            [weak self] verticalAcceleration, timestampMs in
            self?.onCalibrationSample?(verticalAcceleration, timestampMs)
        }
        source.start()
        calibrationSource = source
    }

    func stopCalibration() {
        calibrationSource?.stop()
        calibrationSource = nil
    }

    /// Android는 프로세스가 죽어도 완료된 세션을 SharedPreferences에서 복구하지만,
    /// iOS는 백그라운드 재시작 시점에 트래킹 프로세스 자체가 살아있지 않을 수 있어
    /// 동일한 보장을 하지 않는다. 현재 세션 내에서는 상태 스트림으로 완료 이벤트가 전달된다.
    func consumeCompletedSession() -> [String: Any]? {
        nil
    }

    // MARK: - 세션 초기화

    private func resetSessionState() {
        count = 0
        distanceMeters = 0.0
        caloriesKcal = 0.0
        walkingBaseCaloriesKcal = 0.0
        elevationCaloriesKcal = 0.0
        elevationGainMeters = 0.0
        previousAltitudeMeters = nil
        smoothedLatitude = nil
        smoothedLongitude = nil
        steps = 0
        previousLocation = nil
        lastGpsSteps = 0
        lastGpsMillis = 0
        lastShadowCompensationSteps = 0
        lastWalkingDistanceSteps = 0
        averageStrideMeters = defaultStrideMeters()
        gpsShadowDistanceMeters = 0.0
        currentSpeedMetersPerSecond = 0.0
        smoothedSpeedMetersPerSecond = 0.0
        averageSpeedMetersPerSecond = 0.0
        averagePaceSecondsPerKm = 0.0
        cadenceSpm = 0
        stepWindow.removeAll()
        accelerationWindow.removeAll()
        motionState = Self.motionStationary
        pendingMotionState = Self.motionStationary
        pendingMotionStateSinceMillis = 0
        autoPaused = false
        stationarySinceMillis = 0
        movingSinceMillis = 0
        movingDurationMillis = 0
        movingDurationSeconds = 0
    }

    // MARK: - 근력 운동 (푸시업/풀업) — 포그라운드 전용

    private func startStrengthTracking() {
        verticalAccelerationSource?.stop()
        let source = VerticalAccelerationSource(motionManager: motionManager) {
            [weak self] verticalAcceleration, timestampMs in
            guard let self, self.status == Self.statusMeasuring else { return }
            if self.repDetector.update(
                verticalAcceleration: verticalAcceleration,
                timestampMs: timestampMs
            ) {
                self.count += 1
                self.caloriesKcal = self.calculateStrengthCalories()
                self.emitState()
            }
        }
        source.start()
        verticalAccelerationSource = source
    }

    private func calculateStrengthCalories() -> Double {
        guard weightKg > 0, count > 0 else { return 0 }
        let met = exerciseType == "pull-up" ? Self.pullUpMet : Self.pushUpMet
        let secondsPerRep = exerciseType == "pull-up" ? Self.pullUpSecondsPerRep : Self.pushUpSecondsPerRep
        guard met > 0, secondsPerRep > 0 else { return 0 }

        let durationSeconds = max(elapsedSeconds(), 0)
        guard durationSeconds > 0 else { return 0 }

        let estimatedActiveSeconds = Double(count) * secondsPerRep * Self.strengthActiveTimeBuffer
        let activeSeconds = min(Double(durationSeconds), estimatedActiveSeconds)
        let activeMinutes = activeSeconds / 60.0
        return met * 3.5 * weightKg / 200.0 * activeMinutes
    }

    // MARK: - 유산소 운동 (러닝/워킹) — 백그라운드 지원

    private func startCardioTracking() {
        // "Always" 권한이 없는 상태에서 allowsBackgroundLocationUpdates를 true로 두면
        // 런타임 예외가 발생하므로, 실제로 "Always"가 승인된 경우에만 백그라운드를 켠다.
        locationManager.allowsBackgroundLocationUpdates = locationAuthorizationStatus() == .authorizedAlways
        locationManager.startUpdatingLocation()

        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date(timeIntervalSince1970: startedAtMillis / 1000.0)) { [weak self] data, _ in
                guard let self, let data, self.status == Self.statusMeasuring else { return }
                self.handleStepUpdate(data)
            }
        }

        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.2
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data, self.status == Self.statusMeasuring else { return }
                let magnitude = Self.magnitude(
                    data.acceleration.x * Self.gravity,
                    data.acceleration.y * Self.gravity,
                    data.acceleration.z * Self.gravity
                )
                self.recordAccelerationSample(magnitude)
            }
        }

        cardioTicker?.invalidate()
        cardioTicker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.status == Self.statusMeasuring, self.isCardioExercise() else { return }
            self.updateCardioMetrics()
            self.emitState()
        }
        if let cardioTicker {
            RunLoop.main.add(cardioTicker, forMode: .common)
        }
    }

    private func handleStepUpdate(_ data: CMPedometerData) {
        steps = max(data.numberOfSteps.intValue, 0)
        let now = nowMillis()
        stepWindow.append((now, steps))
        stepWindow.removeAll { now - $0.millis > Self.stepWindowMs }

        if let cadence = data.currentCadence?.doubleValue {
            cadenceSpm = Int(cadence * 60.0)
        } else if let oldest = stepWindow.first {
            cadenceSpm = Int(max(Double(steps - oldest.steps), 0) * 60000.0 / Self.stepWindowMs)
        } else {
            cadenceSpm = 0
        }
    }

    private func recordAccelerationSample(_ magnitude: Double) {
        let now = nowMillis()
        accelerationWindow.append((now, magnitude))
        accelerationWindow.removeAll { now - $0.millis > Self.accelerationWindowMs }
    }

    private func updateCardioMetrics() {
        updateMovingDuration()
        if exerciseType == "walking" {
            updateWalkingSpeed()
        }
        updateMotionState()
        if exerciseType == "walking" {
            compensateWalkingStepDistance()
        }
        compensateGpsShadowDistance()
        updateAverages()
        // 워킹은 거리가 늘어난 그 순간(accumulateWalkingCalories)에 이미 적산되므로 여기서 다시 계산하지 않는다.
        // 세션 전체 평균속도를 전체 거리에 소급 적용하던 예전 방식으로 되돌아가지 않도록 주의.
        if exerciseType != "walking" {
            refreshCardioCalories()
        }
    }

    private func updateMovingDuration() {
        guard status == Self.statusMeasuring else { return }
        let now = nowMillis()
        if !autoPaused && motionState != Self.motionVehicle {
            movingDurationMillis += max(now - lastCardioTickMillis, 0)
        }
        lastCardioTickMillis = now
        movingDurationSeconds = Int64(movingDurationMillis / 1000.0)
    }

    private var lastCardioTickMillis: Double = 0

    private func updateWalkingSpeed() {
        if lastGpsMillis > 0, nowMillis() - lastGpsMillis <= Self.walkingSpeedGpsFreshMs {
            return
        }
        currentSpeedMetersPerSecond = Double(cadenceSpm) * averageStrideMeters / 60.0
        smoothedSpeedMetersPerSecond = smoothedSpeedMetersPerSecond <= 0
            ? currentSpeedMetersPerSecond
            : Self.walkingSpeedEmaAlpha * currentSpeedMetersPerSecond
                + (1 - Self.walkingSpeedEmaAlpha) * smoothedSpeedMetersPerSecond
    }

    private func compensateWalkingStepDistance() {
        guard exerciseType == "walking", !autoPaused, motionState != Self.motionVehicle else { return }
        if accelerationRange() < Self.walkingAccelerationActiveRange && recentStepDelta() <= 0 { return }

        let uncompensatedSteps = max(steps - lastWalkingDistanceSteps, 0)
        guard uncompensatedSteps > 0 else { return }

        let estimatedDistance = Double(uncompensatedSteps) * averageStrideMeters
        guard estimatedDistance <= Self.walkingMaxStepCompensationMeters else { return }

        distanceMeters += estimatedDistance
        lastWalkingDistanceSteps = steps
        accumulateWalkingCalories(estimatedDistance)
    }

    private func compensateGpsShadowDistance() {
        guard exerciseType == "running", !autoPaused, motionState != Self.motionVehicle else { return }
        guard lastGpsMillis > 0 else { return }

        let gpsGapMillis = nowMillis() - lastGpsMillis
        guard gpsGapMillis >= Self.gpsShadowMinGapMs, gpsGapMillis <= Self.gpsShadowMaxGapMs else { return }

        let uncompensatedSteps = max(steps - lastShadowCompensationSteps, 0)
        guard uncompensatedSteps > 0 else { return }

        let estimatedDistance = Double(uncompensatedSteps) * averageStrideMeters
        guard estimatedDistance <= Self.gpsShadowMaxCompensationMeters else { return }

        distanceMeters += estimatedDistance
        gpsShadowDistanceMeters += estimatedDistance
        lastShadowCompensationSteps = steps
    }

    private func updateAverages() {
        averageSpeedMetersPerSecond = movingDurationSeconds <= 0
            ? 0
            : distanceMeters / Double(movingDurationSeconds)
        // 평균 속도와 같은 시간 기준(이동 시간)을 써야 두 값이 서로 앞뒤가 맞는다.
        // 예전에는 러닝만 전체 경과시간(신호대기 등 정지 구간 포함)을 써서 평균 속도로
        // 역산한 페이스와 표시되는 페이스가 서로 맞지 않았다.
        averagePaceSecondsPerKm = (distanceMeters <= 0 || movingDurationSeconds <= 0)
            ? 0
            : Double(movingDurationSeconds) / (distanceMeters / 1000.0)
    }

    private func updateMotionState() {
        let now = nowMillis()
        let speedKmh = smoothedSpeedMetersPerSecond * 3.6
        let accelerationActive = accelerationRange() >= accelerationActiveRange()
        let recentSteps = recentStepDelta()

        let candidate: String
        if exerciseType == "walking" {
            if speedKmh >= Self.walkingVehicleSpeedKmh && recentSteps == 0 && !accelerationActive {
                candidate = Self.motionVehicle
            } else if speedKmh >= Self.walkingRunningSpeedKmh && cadenceSpm >= Self.walkingRunningMinCadence && accelerationActive {
                candidate = Self.motionRunning
            } else if speedKmh >= Self.fastWalkingMinSpeedKmh && speedKmh <= Self.fastWalkingMaxSpeedKmh
                && cadenceSpm >= Self.fastWalkingMinCadence && cadenceSpm <= Self.fastWalkingMaxCadence {
                candidate = Self.motionFastWalking
            } else if speedKmh >= Self.walkingMinSpeedKmh && speedKmh <= Self.walkingNormalMaxSpeedKmh
                && cadenceSpm >= Self.walkingMinCadence && cadenceSpm <= Self.walkingNormalMaxCadence {
                candidate = Self.motionWalking
            } else if speedKmh < Self.walkingStationaryMaxSpeedKmh && recentSteps == 0 && !accelerationActive {
                candidate = Self.motionStationary
            } else {
                candidate = motionState
            }
        } else {
            if speedKmh >= Self.vehicleSpeedKmh && recentSteps == 0 && !accelerationActive {
                candidate = Self.motionVehicle
            } else if speedKmh >= Self.runningMinSpeedKmh && cadenceSpm >= Self.runningMinCadence && accelerationActive {
                candidate = Self.motionRunning
            } else if speedKmh >= Self.walkingMinSpeedKmh && speedKmh <= Self.walkingMaxSpeedKmh
                && cadenceSpm >= Self.walkingMinCadence && cadenceSpm <= Self.walkingMaxCadence {
                candidate = Self.motionWalking
            } else if speedKmh < Self.stationaryMaxSpeedKmh && recentSteps == 0 && !accelerationActive {
                candidate = Self.motionStationary
            } else {
                candidate = motionState
            }
        }

        if candidate != pendingMotionState {
            pendingMotionState = candidate
            pendingMotionStateSinceMillis = now
        } else if candidate != motionState && now - pendingMotionStateSinceMillis >= Self.motionChangeHoldMs {
            motionState = candidate
        }

        updateAutoPause(now: now)
    }

    private func updateAutoPause(now: Double) {
        if motionState == Self.motionStationary {
            if stationarySinceMillis == 0 { stationarySinceMillis = now }
            movingSinceMillis = 0
            if now - stationarySinceMillis >= autoPauseHoldMs() {
                autoPaused = true
            }
            return
        }

        if [Self.motionRunning, Self.motionWalking, Self.motionFastWalking].contains(motionState) {
            if movingSinceMillis == 0 { movingSinceMillis = now }
            stationarySinceMillis = 0
            if now - movingSinceMillis >= Self.autoResumeHoldMs {
                autoPaused = false
            }
        }
    }

    /// 러닝은 페이스에 거의 무관하게 거리당 에너지 소비가 일정하다는 근사를 그대로 쓴다.
    private func calculateRunningCalories(distanceMeters: Double) -> Double {
        guard weightKg > 0, distanceMeters > 0 else { return 0 }
        return weightKg * (distanceMeters / 1000.0)
    }

    /// 워킹은 거리가 늘어난 그 구간의 순간 속도로 계수를 정해 그 구간 거리에만 곱해 누적한다.
    /// (세션 전체 평균속도로 정한 계수를 전체 누적거리에 매번 다시 곱하면, 페이스가 바뀔 때마다
    /// 이미 걸어온 거리 전체의 칼로리가 새 계수로 소급 재계산되어 부정확해진다.)
    private func accumulateWalkingCalories(_ deltaDistanceMeters: Double) {
        guard weightKg > 0, deltaDistanceMeters > 0 else { return }

        let deltaKm = deltaDistanceMeters / 1000.0
        let speedKmh = smoothedSpeedMetersPerSecond * 3.6
        let coefficient: Double
        if speedKmh < Self.walkingCalorieNormalSpeedKmh {
            coefficient = Self.walkingSlowCalorieCoefficient
        } else if speedKmh < Self.walkingCalorieFastSpeedKmh {
            coefficient = Self.walkingNormalCalorieCoefficient
        } else {
            coefficient = Self.walkingFastCalorieCoefficient
        }
        walkingBaseCaloriesKcal += weightKg * deltaKm * coefficient
        refreshCardioCalories()
    }

    /// 기본 칼로리(러닝은 재계산, 워킹은 누적값)에 고도 보정치를 더해 최종 표시값을 만든다.
    private func refreshCardioCalories() {
        let base = exerciseType == "walking"
            ? walkingBaseCaloriesKcal
            : calculateRunningCalories(distanceMeters: distanceMeters)
        caloriesKcal = base + elevationCaloriesKcal
    }

    private func accelerationRange() -> Double {
        guard !accelerationWindow.isEmpty else { return 0 }
        let values = accelerationWindow.map(\.value)
        return abs((values.max() ?? 0) - (values.min() ?? 0))
    }

    private func recentStepDelta() -> Int {
        let first = stepWindow.first?.steps ?? steps
        return max(steps - first, 0)
    }

    // MARK: - 정리

    private func stopAllUpdates() {
        verticalAccelerationSource?.stop()
        verticalAccelerationSource = nil
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        pedometer.stopUpdates()
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        cardioTicker?.invalidate()
        cardioTicker = nil
    }

    // MARK: - 헬퍼

    private func isCardioExercise() -> Bool {
        exerciseType == "running" || exerciseType == "walking"
    }

    /// GPS로 보폭이 학습되기 전까지 쓸 출발값. 키를 입력했다면 키 기반으로 추정하고,
    /// 아니면 인구 평균에 해당하는 고정값을 쓴다. 키 기반 추정은 GPS 학습이 시작되면
    /// 곧바로 사용자 실측값으로 대체되므로, 정밀할 필요 없이 방향만 맞으면 된다.
    private func defaultStrideMeters() -> Double {
        if heightCm > 0 {
            let factor = exerciseType == "walking" ? Self.walkingStrideHeightFactor : Self.runningStrideHeightFactor
            let estimate = heightCm * factor / 100.0
            return min(max(estimate, minStrideMeters()), maxStrideMeters())
        }
        return exerciseType == "walking" ? Self.defaultWalkingStrideMeters : Self.defaultRunningStrideMeters
    }

    private func minStrideMeters() -> Double {
        exerciseType == "walking" ? Self.minWalkingStrideMeters : Self.minRunningStrideMeters
    }

    private func maxStrideMeters() -> Double {
        exerciseType == "walking" ? Self.maxWalkingStrideMeters : Self.maxRunningStrideMeters
    }

    private func accelerationActiveRange() -> Double {
        exerciseType == "walking" ? Self.walkingAccelerationActiveRange : Self.accelerationActiveRange
    }

    private func autoPauseHoldMs() -> Double {
        exerciseType == "walking" ? Self.walkingAutoPauseHoldMs : Self.autoPauseHoldMs
    }

    private func elapsedSeconds() -> Int64 {
        guard startedAtMillis > 0 else { return 0 }
        let end = status == Self.statusMeasuring ? nowMillis() : endedAtMillis
        return Int64(max(end - startedAtMillis, 0) / 1000.0)
    }

    private func nowMillis() -> Double {
        Date().timeIntervalSince1970 * 1000.0
    }

    private func locationAuthorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    private static func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private func emitState() {
        onStateChange?(stateMap())
    }

    private func stateMap() -> [String: Any] {
        [
            "exerciseType": exerciseType,
            "status": status,
            "count": count,
            "elapsedSeconds": elapsedSeconds(),
            "activeDurationSeconds": elapsedSeconds(),
            "movingDurationSeconds": movingDurationSeconds,
            "distanceMeters": distanceMeters,
            "caloriesKcal": caloriesKcal,
            "steps": steps,
            "currentSpeedMetersPerSecond": currentSpeedMetersPerSecond,
            "averageSpeedMetersPerSecond": averageSpeedMetersPerSecond,
            "averagePaceSecondsPerKm": averagePaceSecondsPerKm,
            "cadenceSpm": cadenceSpm,
            "motionState": motionState,
            "isAutoPaused": autoPaused,
            "gpsShadowDistanceMeters": gpsShadowDistanceMeters,
            "startedAtMillis": startedAtMillis,
            "endedAtMillis": endedAtMillis,
        ]
    }

    // MARK: - 상수 (Android WorkoutTrackingService.kt와 동일한 값)

    private static let gravity = 9.80665

    /// 기준치를 측정하지 않은 사용자를 위한 출발점. Dart `WorkoutThreshold.defaultsFor`와 같은 값.
    static let defaultAmplitudeThreshold = 0.8
    static let defaultMinHalfPeriodMs: Double = 250
    static let defaultMaxHalfPeriodMs: Double = 2500
    static let defaultCooldownMs: Double = 800

    private static let defaultExerciseType = "push-up"
    private static let statusIdle = "idle"
    private static let statusMeasuring = "measuring"
    private static let statusCompleted = "completed"

    private static let defaultWalkingStrideMeters = 0.7
    private static let minWalkingStrideMeters = 0.3
    private static let maxWalkingStrideMeters = 1.3
    private static let defaultRunningStrideMeters = 1.0
    private static let minRunningStrideMeters = 0.6
    private static let maxRunningStrideMeters = 2.2
    private static let strideEmaAlpha = 0.2

    /// "초기 걷기 보폭 ≈ 키 x 0.40~0.43" (docs/walking_guide.md) 의 중간값.
    private static let walkingStrideHeightFactor = 0.415
    /// 조깅 페이스 기준 근사치. 워킹보다 보폭이 뚜렷이 길다는 방향만 반영한다.
    private static let runningStrideHeightFactor = 0.57

    /// 거리 계산용 좌표 스무딩 계수. 기존 속도 EMA(0.2~0.35)와 비슷한 크기로 맞췄다.
    private static let positionEmaAlpha = 0.3

    // GPS 고도는 수평 위치보다 오차가 크다. 노이즈 수준의 미세 변화는 무시하고,
    // 한 번에 비정상적으로 큰 변화는 튐으로 보고 버린다.
    private static let minElevationGainDeltaMeters = 1.0
    private static let maxElevationGainJumpMeters = 15.0

    // 체중(kg) x 상승고도(m) x 계수. 상승에 드는 위치에너지(m*g*h)를 등반 시
    // 기계효율 약 20%로 나눠 대략적인 대사 비용으로 환산한 값이다. 정밀한 값이 아니라
    // "오르막이 평지보다 더 든다"는 방향을 반영하기 위한 근사치다.
    private static let elevationGainCaloriesPerKgMeter = 0.01
    private static let minStrideSampleSteps = 4
    private static let maxStrideSampleSteps = 120
    private static let minWalkingStrideSampleSteps = 4
    private static let maxWalkingStrideSampleSteps = 160
    private static let gpsShadowMinGapMs: Double = 5_000
    private static let gpsShadowMaxGapMs: Double = 15_000
    private static let gpsShadowMaxCompensationMeters = 40.0
    private static let walkingMaxStepCompensationMeters = 25.0
    private static let stepWindowMs: Double = 10_000
    private static let accelerationWindowMs: Double = 3_000
    private static let accelerationActiveRange = 1.2
    private static let walkingAccelerationActiveRange = 0.8
    private static let walkingSpeedEmaAlpha = 0.2
    // 30m -> 20m. 스마트폰 GPS는 하늘이 트인 곳에서 보통 3~8m, 도심에서도 20m 안팎이라
    // 30m까지 허용하면 이미 상당히 나쁜 픽스도 거리 계산에 들어간다.
    private static let maxLocationAccuracyMeters = 20.0
    private static let maxRunningSpeedMetersPerSecond = 8.0
    private static let walkingMaxLocationJumpMeters = 60.0
    private static let walkingSpeedGpsFreshMs: Double = 10_000
    private static let minLocationDeltaMs: Double = 1_000
    private static let walkingMinLocationDeltaMs: Double = 2_000
    private static let minLocationDistanceMeters = 2.0
    private static let walkingMinLocationDistanceMeters = 1.0
    private static let stationaryMaxSpeedKmh = 1.0
    private static let walkingStationaryMaxSpeedKmh = 0.8
    private static let walkingMinSpeedKmh = 1.0
    private static let walkingNormalMaxSpeedKmh = 5.5
    private static let walkingMaxSpeedKmh = 7.0
    private static let fastWalkingMinSpeedKmh = 4.5
    private static let fastWalkingMaxSpeedKmh = 7.0
    private static let runningMinSpeedKmh = 6.0
    private static let vehicleSpeedKmh = 20.0
    private static let walkingVehicleSpeedKmh = 15.0
    private static let walkingRunningSpeedKmh = 7.0
    private static let walkingMinCadence = 60
    private static let walkingNormalMaxCadence = 120
    private static let walkingMaxCadence = 140
    private static let fastWalkingMinCadence = 110
    private static let fastWalkingMaxCadence = 150
    private static let runningMinCadence = 140
    private static let walkingRunningMinCadence = 150
    private static let motionChangeHoldMs: Double = 3_000
    private static let autoPauseHoldMs: Double = 5_000
    private static let walkingAutoPauseHoldMs: Double = 7_000
    private static let autoResumeHoldMs: Double = 3_000
    private static let motionStationary = "stationary"
    private static let motionWalking = "walking"
    private static let motionFastWalking = "fastWalking"
    private static let motionRunning = "running"
    private static let motionVehicle = "vehicle"
    private static let walkingCalorieNormalSpeedKmh = 4.0
    private static let walkingCalorieFastSpeedKmh = 5.5
    private static let walkingSlowCalorieCoefficient = 0.4
    private static let walkingNormalCalorieCoefficient = 0.5
    private static let walkingFastCalorieCoefficient = 0.6
    private static let pushUpMet = 3.8
    private static let pullUpMet = 6.0
    private static let pushUpSecondsPerRep = 2.5
    private static let pullUpSecondsPerRep = 4.0
    private static let strengthActiveTimeBuffer = 1.3
}

// MARK: - CLLocationManagerDelegate

extension WorkoutTrackingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard status == Self.statusMeasuring, isCardioExercise(), let location = locations.last else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= Self.maxLocationAccuracyMeters else { return }

        let locationMillis = location.timestamp.timeIntervalSince1970 * 1000.0

        guard let previous = previousLocation else {
            previousLocation = location
            smoothedLatitude = location.coordinate.latitude
            smoothedLongitude = location.coordinate.longitude
            if location.verticalAccuracy >= 0 { previousAltitudeMeters = location.altitude }
            lastGpsSteps = steps
            lastGpsMillis = locationMillis
            lastShadowCompensationSteps = steps
            lastWalkingDistanceSteps = steps
            return
        }

        let deltaMillis = locationMillis - previous.timestamp.timeIntervalSince1970 * 1000.0
        let minDelta = exerciseType == "walking" ? Self.walkingMinLocationDeltaMs : Self.minLocationDeltaMs
        guard deltaMillis >= minDelta else { return }

        let deltaDistance = smoothedDistance(to: location)
        // GPS 칩이 도플러 편이로 직접 계산한 속도(CLLocation.speed)를 우선 쓴다.
        // 위치 두 점을 미분해서 구하는 속도보다 노이즈가 훨씬 적다 — 특히 업데이트 간격이
        // 1초 안팎으로 짧은 러닝에서는 위치 오차가 시간으로 나뉘며 크게 증폭되기 때문이다.
        // speed가 음수면 유효하지 않다는 뜻(CoreLocation 규약)이라 위치 차분으로 대체한다.
        let instantSpeedMetersPerSecond = location.speed >= 0
            ? location.speed
            : deltaDistance / (deltaMillis / 1000.0)

        handleAltitudeSample(location)

        if exerciseType == "walking" {
            handleWalkingLocation(location, deltaDistance: deltaDistance, speedMetersPerSecond: instantSpeedMetersPerSecond)
        } else {
            handleRunningLocation(location, deltaDistance: deltaDistance, speedMetersPerSecond: instantSpeedMetersPerSecond, locationMillis: locationMillis)
        }
    }

    /// 원시 좌표 대신 EMA로 스무딩한 좌표 사이의 거리를 계산한다.
    /// 정지 상태에서도 원시 좌표는 몇 미터씩 흔들리는데, 그 흔들림이 방향과 무관하게
    /// 전부 양수로 누적 거리에 더해지는 구조적 과대추정이 있다. 스무딩하면 이 편향이 줄어든다.
    private func smoothedDistance(to location: CLLocation) -> Double {
        let previousLat = smoothedLatitude
        let previousLng = smoothedLongitude

        let newLat: Double
        let newLng: Double
        if let previousLat, let previousLng {
            newLat = previousLat + Self.positionEmaAlpha * (location.coordinate.latitude - previousLat)
            newLng = previousLng + Self.positionEmaAlpha * (location.coordinate.longitude - previousLng)
        } else {
            newLat = location.coordinate.latitude
            newLng = location.coordinate.longitude
        }

        let distance: Double
        if let previousLat, let previousLng {
            let previousPoint = CLLocation(latitude: previousLat, longitude: previousLng)
            let newPoint = CLLocation(latitude: newLat, longitude: newLng)
            distance = previousPoint.distance(from: newPoint)
        } else {
            distance = 0
        }

        smoothedLatitude = newLat
        smoothedLongitude = newLng
        return distance
    }

    /// GPS 고도로 누적 상승고도를 추정해 칼로리에 오르막 보정치를 더한다.
    /// GPS 고도는 수평 위치보다 오차가 크므로, 노이즈 수준의 미세 변화(1m 미만)는 무시하고
    /// 한 번에 비정상적으로 큰 변화(15m 초과)도 튐으로 보고 버린다.
    private func handleAltitudeSample(_ location: CLLocation) {
        guard location.verticalAccuracy >= 0 else { return }

        let altitude = location.altitude
        defer { previousAltitudeMeters = altitude }
        guard let previousAltitude = previousAltitudeMeters else { return }

        let delta = altitude - previousAltitude
        guard delta >= Self.minElevationGainDeltaMeters, delta <= Self.maxElevationGainJumpMeters else { return }

        elevationGainMeters += delta
        elevationCaloriesKcal += weightKg * delta * Self.elevationGainCaloriesPerKgMeter
        refreshCardioCalories()
    }

    private func handleRunningLocation(_ location: CLLocation, deltaDistance: Double, speedMetersPerSecond: Double, locationMillis: Double) {
        guard deltaDistance >= Self.minLocationDistanceMeters, speedMetersPerSecond <= Self.maxRunningSpeedMetersPerSecond else {
            previousLocation = location
            return
        }

        previousLocation = location
        updateStrideFromGps(deltaDistance: deltaDistance, locationMillis: locationMillis)
        lastGpsMillis = locationMillis
        lastShadowCompensationSteps = steps
        updateSpeed(instantSpeedMetersPerSecond: speedMetersPerSecond, alpha: 0.35)
        updateCardioMetrics()
        if !autoPaused && motionState != Self.motionVehicle {
            distanceMeters += deltaDistance
        }
        updateAverages()
        refreshCardioCalories()
        emitState()
    }

    private func handleWalkingLocation(_ location: CLLocation, deltaDistance: Double, speedMetersPerSecond: Double) {
        let stepDelta = max(steps - lastGpsSteps, 0)
        let accelerationActive = accelerationRange() >= Self.walkingAccelerationActiveRange
        let speedKmh = speedMetersPerSecond * 3.6
        let vehicleCandidate = speedKmh >= Self.walkingVehicleSpeedKmh && stepDelta == 0
        let validWalkingMove = !vehicleCandidate
            && speedKmh <= Self.walkingRunningSpeedKmh
            && stepDelta > 0
            && accelerationActive
            && deltaDistance <= Self.walkingMaxLocationJumpMeters

        let locationMillis = location.timestamp.timeIntervalSince1970 * 1000.0
        previousLocation = location
        lastGpsMillis = locationMillis
        updateSpeed(instantSpeedMetersPerSecond: speedMetersPerSecond, alpha: Self.walkingSpeedEmaAlpha)

        if validWalkingMove {
            updateStrideFromGps(deltaDistance: deltaDistance, locationMillis: locationMillis)
            if !autoPaused && motionState != Self.motionVehicle {
                distanceMeters += deltaDistance
                lastWalkingDistanceSteps = steps
                accumulateWalkingCalories(deltaDistance)
            }
        } else {
            lastGpsSteps = steps
        }

        updateCardioMetrics()
        emitState()
    }

    private func updateSpeed(instantSpeedMetersPerSecond: Double, alpha: Double) {
        currentSpeedMetersPerSecond = instantSpeedMetersPerSecond
        smoothedSpeedMetersPerSecond = smoothedSpeedMetersPerSecond <= 0
            ? instantSpeedMetersPerSecond
            : alpha * instantSpeedMetersPerSecond + (1 - alpha) * smoothedSpeedMetersPerSecond
    }

    private func updateStrideFromGps(deltaDistance: Double, locationMillis: Double) {
        guard deltaDistance > 0 else { return }
        let stepDelta = max(steps - lastGpsSteps, 0)
        let minSteps = exerciseType == "walking" ? Self.minWalkingStrideSampleSteps : Self.minStrideSampleSteps
        let maxSteps = exerciseType == "walking" ? Self.maxWalkingStrideSampleSteps : Self.maxStrideSampleSteps
        if stepDelta >= minSteps && stepDelta <= maxSteps {
            let stride = deltaDistance / Double(stepDelta)
            if stride >= minStrideMeters() && stride <= maxStrideMeters() {
                averageStrideMeters = Self.strideEmaAlpha * stride + (1 - Self.strideEmaAlpha) * averageStrideMeters
            }
        }
        lastGpsSteps = steps
        lastGpsMillis = locationMillis
    }
}
