# Running Logic
## 입력
`GPS` / `Step Counter` / `Accelerometer` / `weightKg` / `heightCm`(선택)
## GPS
`valid = accuracy <= 20m`
`deltaTime >= 1s`
`smoothedLat = prevSmoothedLat + 0.3 * (rawLat - prevSmoothedLat)` (경도도 동일)
`deltaDistance = distance(prevSmoothedPosition, smoothedPosition)`
`deltaDistance >= 2m`
`instantSpeed = location.speed` (기기 제공 도플러 속도, 유효하지 않으면 `deltaDistance / deltaTime`로 대체)
`instantSpeed <= 8.0m/s`
## 거리
`canAdd = !autoPaused && motionState != vehicle`
`if canAdd: distance += deltaDistance`
## 속도
`smoothedSpeed = 0.35 * instantSpeed + 0.65 * prevSmoothedSpeed`
`movingTime += now - prevTick` when `canAdd`
`avgSpeed = distance / movingTime`
`avgPace = movingTime / (distance / 1000)` (avgSpeed와 같은 시간 기준을 쓴다)
## 걸음
`steps = rawStepCounter - baselineStepCounter`
`cadence = stepDeltaIn10s * 6`
## 가속도
`magnitude = sqrt(x^2 + y^2 + z^2)`
`accelRange = max(window3s) - min(window3s)`
`accelActive = accelRange >= 1.2`
## 상태
`vehicle = speed >= 20km/h && recentSteps == 0 && !accelActive`
`running = speed >= 6km/h && cadence >= 140 && accelActive`
`walking = 1km/h <= speed <= 7km/h && 60 <= cadence <= 140`
`stationary = speed < 1km/h && recentSteps == 0 && !accelActive`
`motionState = candidateState` after `3s`
## 자동 일시정지
`autoPaused = true` when `stationary >= 5s`
`autoPaused = false` when `(running || walking) >= 3s`
## 보폭
`defaultStride = heightCm * 0.57 / 100` (키 입력 시, `min/maxRunningStride`로 clamp)
`defaultStride = 1.0m` (키 미입력 시)
`stride = gpsDeltaDistance / stepDelta`
`validStride = 4 <= stepDelta <= 120 && 0.6m <= stride <= 2.2m`
`avgStride = 0.2 * stride + 0.8 * prevAvgStride`
## GPS 음영
`shadowGap = now - lastGpsTime`
`canShadow = 5s <= shadowGap <= 15s && canAdd`
`estimatedDistance = uncompensatedSteps * avgStride`
`if canShadow && estimatedDistance <= 40m: distance += estimatedDistance`
## 고도 보정
`altitudeDelta = location.altitude - prevAltitude`
`validGain = 1m <= altitudeDelta <= 15m` (노이즈·튐 배제)
`if validGain: elevationCalories += weightKg * altitudeDelta * 0.01`
## 칼로리
`baseCalories = weightKg * (distance / 1000)`
`caloriesKcal = baseCalories + elevationCalories`
