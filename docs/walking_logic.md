# Walking Logic
## 입력 / 권한
`GPS` / `Step Counter` / `Accelerometer` / `weightKg`
`permission = location && ACTIVITY_RECOGNITION`
`if !permission: PERMISSION_REQUIRED`
## GPS
`valid = accuracy <= 30m`
`deltaTime >= 2s`
`deltaDistance >= 1m`
`gpsSpeed = deltaDistance / deltaTime`
`gpsSpeedKmh = gpsSpeed * 3.6`
`vehicleCandidate = gpsSpeedKmh >= 15 && stepDelta == 0`
`validWalkingMove = !vehicleCandidate && gpsSpeedKmh <= 7 && stepDelta > 0 && accelActive`
`validWalkingMove = validWalkingMove && deltaDistance <= 60m`
## 거리
`gpsDistance` or `stepDistance`
`canAdd = !autoPaused && motionState != vehicle`
`if validWalkingMove && canAdd: distance += gpsDistance`
`if validWalkingMove: lastWalkingDistanceSteps = steps`
`if !validWalkingMove: stepDistance 보완`
`GPS 거리 + 보폭 거리 = 중복 누적 금지`
## 보폭
`defaultStride = 0.7m`
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
`gpsCurrentSpeed = gpsDeltaDistance / gpsDeltaTime`
`gpsDisplaySpeed = 0.2 * gpsCurrentSpeed + 0.8 * prevSpeed`
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
## 칼로리
`distanceKm = distance / 1000`
`coef = 0.4` when `avgSpeed < 4km/h`
`coef = 0.5` when `4km/h <= avgSpeed < 5.5km/h`
`coef = 0.6` when `avgSpeed >= 5.5km/h`
`caloriesKcal = weightKg * distanceKm * coef`
