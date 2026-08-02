# Push-Up Logic

## 신호
`DeviceMotion` (중력 제거된 선형 가속도 + 중력 벡터) / `weightKg` / `thresholdConfig`

원시 가속도 magnitude(`sqrt(x²+y²+z²)`)는 회전 불변이라 폰 방향에 무관한 대신
위/아래를 구분하지 못하고 정지 상태에서도 중력 9.81이 깔린다.
그래서 중력을 제거한 선형 가속도를 중력 벡터에 투영해 **부호 있는 수직 가속도**를 만든다.

`gravityUnit = gravity / |gravity|`
`verticalAcceleration = dot(linearAcceleration, gravityUnit)` (위쪽이 양수, m/s²)
`정지 상태 = 0`

- Android: `TYPE_LINEAR_ACCELERATION` + `TYPE_GRAVITY` (없으면 가속도계에서 중력을 EMA로 추정)
- iOS: `CMDeviceMotion.userAcceleration` + `CMDeviceMotion.gravity` (같은 패킷이라 시간 정렬 보장)

샘플링은 측정·캘리브레이션 모두 50Hz(20ms)로 고정한다.
타임스탬프는 수신 시각이 아니라 센서 타임스탬프를 쓴다. 화면이 꺼져 이벤트가 몰려
전달되어도 반복 간격 판정이 무너지지 않는다.

## 저역통과
`cutoffHz = 2.5`
`tau = 1 / (2π · cutoffHz)`
`alpha = dt / (tau + dt)`
`filtered += alpha * (raw - filtered)`

샘플 간격에서 계수를 매번 구하므로 샘플이 몰려도 차단 주파수가 유지된다.

## 기준값
`amplitudeThreshold` : 위/아래로 각각 넘어야 하는 크기 (m/s²)
`minHalfPeriodMs` / `maxHalfPeriodMs` : 골 → 마루에 걸리는 시간의 허용 범위
`cooldownMs` : 직전 카운트로부터 최소 간격

## 기본값 (기준치 미측정 시)
`amplitudeThreshold = 0.8`
`minHalfPeriodMs = 250`
`maxHalfPeriodMs = 2500`
`cooldownMs = 800`

## 카운팅
아래로 내려갔다가 위로 올라오는 한 쌍(골 → 마루)을 반복 1회로 본다.
±기준치를 모두 통과해야 하므로 0 근처의 잡음으로는 카운트되지 않는다.

```
waitingForValley:
  if filtered <= -amplitudeThreshold:
    valleyAt = now; phase = waitingForPeak

waitingForPeak:
  elapsed = now - valleyAt
  if elapsed > maxHalfPeriodMs:        phase = waitingForValley   # 제때 안 올라옴
  if filtered <  amplitudeThreshold:   continue
  phase = waitingForValley
  if elapsed < minHalfPeriodMs:        skip    # 흔들기
  if now - lastCountedAt < cooldownMs: skip
  count += 1; lastCountedAt = now
```

## 기준치 측정 (30초)
측정과 **같은** 네이티브 파이프라인에서 수집한 샘플을 쓴다.

1. 신호 진폭 분포(상위 95%의 35%)로 임시 임계값을 잡아 반복을 찾아낸다
2. `medianAmplitude` = 찾아낸 반복들의 진폭 중앙값
3. `amplitudeThreshold = medianAmplitude * 0.5`
   (절반으로 잡아 세트 후반에 힘이 빠져도 계속 인식되게 한다)
4. `minHalfPeriodMs = medianHalfPeriod * 0.45`
   `maxHalfPeriodMs = medianHalfPeriod * 2.5`
   `cooldownMs = medianRepInterval * 0.5`
5. **폐루프 검증**: 산출한 기준치로 방금 캡처한 구간을 다시 세어 사용자에게 인식 횟수를 보여 준다

반복이 3회 미만으로 감지되면 기준치를 저장하지 않고 재측정을 안내한다.
`amplitudeThreshold`는 센서 잡음 수준(0.15 m/s²) 아래로 내려가지 않는다.

## 칼로리
`MET = 3.8`
`secondsPerRep = 2.5`
`activeBuffer = 1.3`
`durationSeconds = endedAt - startedAt`
`estimatedActiveSeconds = count * secondsPerRep * activeBuffer`
`activeSeconds = min(durationSeconds, estimatedActiveSeconds)`
`caloriesKcal = MET * 3.5 * weightKg / 200 * (activeSeconds / 60)`

## 저장 / 표시
`WorkoutSession.count = count`
`WorkoutSession.caloriesKcal = caloriesKcal`
`notification = "{count}개 · {caloriesKcal} kcal"`

## 구현 위치
알고리즘이 세 곳에 있다. 백그라운드 측정을 위해 카운팅은 네이티브에서 돌아야 한다.

- `lib/features/workout/domain/services/rep_detector.dart` — 골든 테스트로 검증되는 **명세**
- `android/app/src/main/kotlin/com/puchall/puchall/RepDetector.kt` — Android 실제 측정
- `ios/Runner/RepDetector.swift` — iOS 실제 측정

한쪽을 고치면 반드시 세 곳을 모두 맞춰야 한다.
