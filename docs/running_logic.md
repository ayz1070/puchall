# Running Logic
## 입력
`GPS` / `Step Counter` / `Accelerometer` / `weightKg`
## GPS
`valid = accuracy <= 30m`
`deltaTime >= 1s`
`deltaDistance >= 2m`
`instantSpeed = deltaDistance / deltaTime`
`instantSpeed <= 8.0m/s`
## 거리
`canAdd = !autoPaused && motionState != vehicle`
`if canAdd: distance += deltaDistance`
## 속도
`currentSpeed = deltaDistance / deltaTime`
`smoothedSpeed = 0.35 * currentSpeed + 0.65 * prevSmoothedSpeed`
`movingTime += now - prevTick` when `canAdd`
`avgSpeed = distance / movingTime`
`avgPace = elapsedTime / (distance / 1000)`
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
## GPS 음영
`stride = gpsDeltaDistance / stepDelta`
`validStride = 4 <= stepDelta <= 120 && 0.6m <= stride <= 2.2m`
`avgStride = 0.2 * stride + 0.8 * prevAvgStride`
`shadowGap = now - lastGpsTime`
`canShadow = 5s <= shadowGap <= 15s && canAdd`
`estimatedDistance = uncompensatedSteps * avgStride`
`if canShadow && estimatedDistance <= 40m: distance += estimatedDistance`
## 칼로리
`caloriesKcal = weightKg * (distance / 1000)`
