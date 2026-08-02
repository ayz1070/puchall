# Walking Logic
## 입력 / 권한
`GPS` / `Step Counter` / `Accelerometer` / `weightKg` / `heightCm`(선택)
`permission = location && ACTIVITY_RECOGNITION`
`if !permission: PERMISSION_REQUIRED`
## GPS
`valid = accuracy <= 20m`
`deltaTime >= 2s`
`smoothedLat = prevSmoothedLat + 0.3 * (rawLat - prevSmoothedLat)` (경도도 동일)
`gpsDeltaDistance = distance(prevSmoothedPosition, smoothedPosition)`
`gpsDeltaDistance >= 1m`
`instantSpeed = location.speed` (기기 제공 도플러 속도, 유효하지 않으면 `gpsDeltaDistance / deltaTime`로 대체)
`gpsSpeedKmh = instantSpeed * 3.6`
`vehicleCandidate = gpsSpeedKmh >= 15 && stepDelta == 0`
`validWalkingMove = !vehicleCandidate && gpsSpeedKmh <= 7 && stepDelta > 0 && accelActive`
`validWalkingMove = validWalkingMove && gpsDeltaDistance <= 60m`
## 거리
`gpsDistance` or `stepDistance`
`canAdd = !autoPaused && motionState != vehicle`
`if validWalkingMove && canAdd: distance += gpsDistance`
`if validWalkingMove: lastWalkingDistanceSteps = steps`
`if !validWalkingMove: stepDistance 보완`
`GPS 거리 + 보폭 거리 = 중복 누적 금지`
## 보폭
`defaultStride = heightCm * 0.415 / 100` (키 입력 시, `min/maxWalkingStride`로 clamp)
`defaultStride = 0.7m` (키 미입력 시)
`stride = gpsDeltaDistance / stepDelta`
`validStride = 4 <= stepDelta <= 160`
`validStride = validStride && 0.3m <= stride <= 1.3m`
`avgStride = 0.2 * stride + 0.8 * prevAvgStride`
## 보폭 거리 보완
`uncompensatedSteps = steps - lastWalkingDistanceSteps`
`estimatedDistance = uncompensatedSteps * avgStride`
`canCompensate = !autoPaused && motionState != vehicle`
`canCompensate = canCompensate && (accelRange >= 0.8 || recentSteps > 0)`
`if canCompensate && estimatedDistance <= 25m: distance += estimatedDistance`
`lastWalkingDistanceSteps = steps`
## 걸음 / 케이던스
`steps = rawStepCounter - baselineStepCounter`
`cadence = stepDeltaIn10s * 6`
## 가속도
`magnitude = sqrt(x^2 + y^2 + z^2)`
`accelRange = max(window3s) - min(window3s)`
`accelActive = accelRange >= 0.8`
## 속도
`gpsDisplaySpeed = 0.2 * instantSpeed + 0.8 * prevSpeed`
`stepSpeed = cadence * avgStride / 60`
`if lastGpsAge <= 10s: speed = gpsDisplaySpeed`
`else: speed = 0.2 * stepSpeed + 0.8 * prevSpeed`
`movingTime += now - prevTick` when `canAdd`
`avgSpeed = distance / movingTime`
`avgPace = movingTime / (distance / 1000)`
## 상태
`vehicle = speed >= 15km/h && recentSteps == 0 && !accelActive`
`running = speed >= 7km/h && cadence >= 150 && accelActive`
`fastWalking = 4.5km/h <= speed <= 7km/h && 110 <= cadence <= 150`
`walking = 1km/h <= speed <= 5.5km/h && 60 <= cadence <= 120`
`stationary = speed < 0.8km/h && recentSteps == 0 && !accelActive`
`motionState = candidateState` after `3s`
## 자동 일시정지
`autoPaused = true` when `stationary >= 7s`
`autoPaused = false` when `(walking || fastWalking || running) >= 3s`
## 고도 보정
`altitudeDelta = location.altitude - prevAltitude`
`validGain = 1m <= altitudeDelta <= 15m` (노이즈·튐 배제)
`if validGain: elevationCalories += weightKg * altitudeDelta * 0.01`
## 칼로리
매 구간(거리가 늘어난 시점)마다 **그 순간의 속도**로 계수를 정해 그 구간 거리에만 적용해 누적한다.
세션 전체 평균속도를 전체 누적거리에 소급 적용하지 않는다 — 페이스가 바뀌는 대부분의
실제 워킹에서 부정확한 결과를 내기 때문이다.
`deltaKm = deltaDistance / 1000`
`coef = 0.4` when `smoothedSpeed < 4km/h`
`coef = 0.5` when `4km/h <= smoothedSpeed < 5.5km/h`
`coef = 0.6` when `smoothedSpeed >= 5.5km/h`
`baseCalories += weightKg * deltaKm * coef`
`caloriesKcal = baseCalories + elevationCalories`
