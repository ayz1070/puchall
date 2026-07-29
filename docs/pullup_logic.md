# Pull-Up Logic
## 입력
`Accelerometer` / `Gyroscope` / `weightKg`
`thresholdConfig`
## 센서
`accMag = sqrt(x^2 + y^2 + z^2)`
`gyroMag = sqrt(x^2 + y^2 + z^2)`
## 기준값
`accThreshold = accelerationMagnitude * accelerationTriggerRatio`
`gyroThreshold = gyroscopeMagnitude * gyroscopeTriggerRatio`
`releaseThreshold = accThreshold * releaseRatio`
`cooldownMs = thresholdConfig.cooldownMs`
## 기본값
`accThreshold = 18.0`
`gyroThreshold = 1.2`
`releaseRatio = 0.55`
`cooldownMs = 600`
## 카운팅
`passedAcceleration = accMag >= accThreshold`
`passedGyroscope = gyroThreshold <= 0 || gyroMag >= gyroThreshold`
`passedCooldown = now - lastCountedAt >= cooldownMs`
`canCount == true`
`if all passed: count += 1`
`after count: canCount = false`
`lastCountedAt = now`
## 재카운트
`hasRecovered = accMag < releaseThreshold`
`if !canCount && hasRecovered: canCount = true`
## 칼로리
`MET = 6.0`
`secondsPerRep = 4.0`
`activeBuffer = 1.3`
`durationSeconds = endedAt - startedAt`
`estimatedActiveSeconds = count * secondsPerRep * activeBuffer`
`activeSeconds = min(durationSeconds, estimatedActiveSeconds)`
`activeMinutes = activeSeconds / 60`
`caloriesKcal = MET * 3.5 * weightKg / 200 * activeMinutes`
## 저장 / 표시
`WorkoutSession.count = count`
`WorkoutSession.caloriesKcal = caloriesKcal`
`notification = "{count}개 · {caloriesKcal} kcal"`
`calendar = "{count}개 · {caloriesKcal} kcal"`
