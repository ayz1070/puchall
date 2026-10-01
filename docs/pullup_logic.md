# Pull-Up Logic

신호 처리와 카운팅 규칙은 [푸시업](pushup_logic.md)과 동일하다.
여기서는 풀업에서 달라지는 부분만 적는다.

## 신호
`DeviceMotion` (중력 제거된 선형 가속도 + 중력 벡터) / `weightKg` / `thresholdConfig`

`verticalAcceleration = dot(linearAcceleration, gravity / |gravity|)` (위쪽이 양수, m/s²)

## 기본값 (기준치 미측정 시)
풀업은 1회에 4초 안팎으로 푸시업보다 느리다. 같은 쿨다운을 쓰면 한 번의 반복이
두 번으로 세어질 수 있어 주기 관련 값을 모두 길게 잡는다.

`amplitudeThreshold = 1.0`
`minHalfPeriodMs = 400`
`maxHalfPeriodMs = 3500`
`cooldownMs = 1200`

## 카운팅
매달린 상태에서 몸이 내려갔다가(-기준치) 올라오는(+기준치) 한 쌍을 1회로 본다.
단, 풀업은 휴대폰 위치와 시작 자세에 따라 신호가 반대로 들어올 수 있으므로
기준치 측정에서 `verticalAccelerationScale`을 함께 학습한다. 실제 측정은
`adjusted = verticalAcceleration * verticalAccelerationScale`을 카운터에 넣는다.
카운트 후에는 공통 히스테리시스 규칙에 따라 신호가 0 근처로 복귀해야 다음 반복을
받는다.
`minHalfPeriodMs`가 400ms이므로 반동으로 흔들리는 동작은 카운트되지 않는다.

## 기준치 측정 (30초)
푸시업과 같은 절차를 쓴다. 측정과 동일한 네이티브 파이프라인에서 모은 샘플로
원본 방향과 반전 방향을 모두 평가한다. 더 많은 반복을 안정적으로 찾은 방향을
`verticalAccelerationScale`로 저장하고, 선택된 방향에서 사용자의 평균 반복 진폭·주기를
구한다. 산출한 기준치로 캡처 구간을 다시 세어 인식 횟수를 보여 준다.

이 값이 저장되면 같은 사용자가 같은 위치에 휴대폰을 둔 상태에서는 풀업 신호가
`양수 → 음수`로 들어와도 기존 골 → 마루 상태 머신이 정상적으로 카운트한다.

## 칼로리
`MET = 6.0`
`secondsPerRep = 4.0`
`activeBuffer = 1.3`
`estimatedActiveSeconds = count * secondsPerRep * activeBuffer`
`activeSeconds = min(durationSeconds, estimatedActiveSeconds)`
`caloriesKcal = MET * 3.5 * weightKg / 200 * (activeSeconds / 60)`

## 저장 / 표시
`WorkoutSession.count = count`
`WorkoutSession.caloriesKcal = caloriesKcal`
`notification = "{count}개 · {caloriesKcal} kcal"`
