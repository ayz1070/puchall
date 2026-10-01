import 'dart:math' as math;

import 'package:puchall/features/workout/domain/services/workout_threshold_calibrator.dart';

/// 반복 검출기 회귀 테스트용 합성 신호 생성기.
///
/// 실기기 로그를 대체하는 것이 아니라, 동작 물리에서 유도한 형태로 알고리즘의
/// 경계 조건을 고정하기 위한 것이다. 각 신호는 "중력이 제거된 수직 가속도"이며
/// 정지 상태에서 0에 수렴한다.
///
/// 진폭은 정현파 변위에서 유도한다. 변위 진폭 d(m), 주기 T(s)일 때
/// 가속도 진폭 a = d * (2π/T)² 이다. 예를 들어 골반이 위아래로 ±0.1m를
/// 2초 주기로 움직이면 a ≈ 0.99 m/s².
///
/// 신호는 `-cos` 위상, 즉 골(내려가는 국면)에서 시작한다. 반복 1회가
/// "내려갔다 올라오는" 골 → 마루 한 쌍에 정확히 대응하므로,
/// [repCount]회를 넣으면 완전한 주기도 정확히 [repCount]개가 된다.
List<WorkoutThresholdSample> repSignal({
  required int repCount,
  required double periodSeconds,
  required double displacementAmplitudeMeters,
  int sampleIntervalMs = 20,
  double noiseAmplitude = 0.05,
  int startTimestampMs = 0,
  int randomSeed = 7,
}) {
  final accelerationAmplitude =
      displacementAmplitudeMeters *
      math.pow(2 * math.pi / periodSeconds, 2).toDouble();
  final totalMs = (repCount * periodSeconds * 1000).round();
  return _sample(
    totalMs: totalMs,
    sampleIntervalMs: sampleIntervalMs,
    startTimestampMs: startTimestampMs,
    noiseAmplitude: noiseAmplitude,
    randomSeed: randomSeed,
    valueAt: (seconds) =>
        -accelerationAmplitude *
        math.cos(2 * math.pi * seconds / periodSeconds),
  );
}

/// 반복 없이 잡음만 있는 구간 (폰을 가만히 둔 상태).
List<WorkoutThresholdSample> idleSignal({
  required int durationMs,
  int sampleIntervalMs = 20,
  double noiseAmplitude = 0.08,
  int startTimestampMs = 0,
  int randomSeed = 11,
}) {
  return _sample(
    totalMs: durationMs,
    sampleIntervalMs: sampleIntervalMs,
    startTimestampMs: startTimestampMs,
    noiseAmplitude: noiseAmplitude,
    randomSeed: randomSeed,
    valueAt: (_) => 0,
  );
}

/// 폰을 손으로 흔드는 신호. 진폭은 크지만 주기가 매우 짧다.
List<WorkoutThresholdSample> shakeSignal({
  required int durationMs,
  double frequencyHz = 5,
  double accelerationAmplitude = 8,
  int sampleIntervalMs = 20,
  int startTimestampMs = 0,
  int randomSeed = 13,
}) {
  return _sample(
    totalMs: durationMs,
    sampleIntervalMs: sampleIntervalMs,
    startTimestampMs: startTimestampMs,
    noiseAmplitude: 0.3,
    randomSeed: randomSeed,
    valueAt: (seconds) =>
        accelerationAmplitude * math.sin(2 * math.pi * frequencyHz * seconds),
  );
}

/// 걷기 신호. 분당 약 110보 = 보행 주기 약 1.09초.
List<WorkoutThresholdSample> walkingSignal({
  required int durationMs,
  double stepsPerMinute = 110,
  double accelerationAmplitude = 2.2,
  int sampleIntervalMs = 20,
  int startTimestampMs = 0,
  int randomSeed = 17,
}) {
  final stepHz = stepsPerMinute / 60;
  return _sample(
    totalMs: durationMs,
    sampleIntervalMs: sampleIntervalMs,
    startTimestampMs: startTimestampMs,
    noiseAmplitude: 0.4,
    randomSeed: randomSeed,
    valueAt: (seconds) =>
        accelerationAmplitude * math.sin(2 * math.pi * stepHz * seconds),
  );
}

/// 세트 후반에 힘이 빠져 진폭이 줄어드는 반복 신호.
///
/// [repCount]개 반복에 걸쳐 변위 진폭이 [displacementAmplitudeMeters]에서
/// [decayedDisplacementAmplitudeMeters]까지 선형으로 줄어든다. 풀업처럼
/// 후반부에 눈에 띄게 힘이 빠지는 운동에서 기준치가 여전히 반복을 인식하는지
/// 검증하는 데 쓴다.
List<WorkoutThresholdSample> decayingRepSignal({
  required int repCount,
  required double periodSeconds,
  required double displacementAmplitudeMeters,
  required double decayedDisplacementAmplitudeMeters,
  int sampleIntervalMs = 20,
  double noiseAmplitude = 0.05,
  int startTimestampMs = 0,
  int randomSeed = 7,
}) {
  final totalMs = (repCount * periodSeconds * 1000).round();
  return _sample(
    totalMs: totalMs,
    sampleIntervalMs: sampleIntervalMs,
    startTimestampMs: startTimestampMs,
    noiseAmplitude: noiseAmplitude,
    randomSeed: randomSeed,
    valueAt: (seconds) {
      final progress = (seconds / (totalMs / 1000)).clamp(0.0, 1.0);
      final displacementAmplitudeMeters_ =
          displacementAmplitudeMeters +
          (decayedDisplacementAmplitudeMeters - displacementAmplitudeMeters) *
              progress;
      final accelerationAmplitude =
          displacementAmplitudeMeters_ *
          math.pow(2 * math.pi / periodSeconds, 2).toDouble();
      return -accelerationAmplitude *
          math.cos(2 * math.pi * seconds / periodSeconds);
    },
  );
}

/// 반복 1회 "골 → 마루 → 0 근처로 복귀"만 생성한다 (다음 골로 다시 내려가지 않음).
///
/// [repSignal]은 완전한 주기(골 → 마루 → 골)를 만들기 때문에 반복 뒤에 정지
/// 구간을 이어 붙이면 마루 이후 인위적으로 다시 골까지 내려가는 구간이 생겨
/// 실제 동작과 달라진다. 이 함수는 마루 이후 0으로 복귀하는 절반만 만들어
/// [deadHangRepSignal]에서 정지 구간과 자연스럽게 이어지게 한다.
List<WorkoutThresholdSample> _singleRepPulse({
  required double periodSeconds,
  required double displacementAmplitudeMeters,
  int sampleIntervalMs = 20,
  double noiseAmplitude = 0.05,
  int randomSeed = 7,
}) {
  final accelerationAmplitude =
      displacementAmplitudeMeters *
      math.pow(2 * math.pi / periodSeconds, 2).toDouble();
  final halfPeriodMs = (periodSeconds * 1000 / 2).round();
  // 마루 이후 0으로 복귀하는 구간은 절반 주기의 절반(반복 주기의 1/4)만 준다.
  final releaseMs = (halfPeriodMs / 2).round();
  final totalMs = halfPeriodMs + releaseMs;
  return _sample(
    totalMs: totalMs,
    sampleIntervalMs: sampleIntervalMs,
    startTimestampMs: 0,
    noiseAmplitude: noiseAmplitude,
    randomSeed: randomSeed,
    valueAt: (seconds) {
      final elapsedMs = (seconds * 1000).round();
      if (elapsedMs <= halfPeriodMs) {
        return -accelerationAmplitude *
            math.cos(math.pi * elapsedMs / halfPeriodMs);
      }
      final releaseElapsedMs = elapsedMs - halfPeriodMs;
      return accelerationAmplitude *
          math.cos(math.pi / 2 * releaseElapsedMs / releaseMs);
    },
  );
}

/// 반복 사이에 데드행(정지) 구간을 끼워 넣은 불규칙한 템포의 반복 신호.
///
/// 풀업은 매달린 채로 잠깐 쉬었다가 다시 당기는 경우가 많아, 반복은 일정한
/// 주기가 아니라 "당김(짧고 빠름) + 정지(길고 불규칙)"로 구성된다.
/// [repPeriodsSeconds]에 각 반복의 주기를, [restMsAfterRep]에 각 반복 뒤에
/// 끼워 넣을 정지 구간 길이를 준다.
List<WorkoutThresholdSample> deadHangRepSignal({
  required List<double> repPeriodsSeconds,
  required List<int> restMsAfterRep,
  required double displacementAmplitudeMeters,
  int sampleIntervalMs = 20,
  double noiseAmplitude = 0.05,
  int randomSeed = 7,
}) {
  assert(repPeriodsSeconds.length == restMsAfterRep.length);
  final parts = <List<WorkoutThresholdSample>>[];
  for (var i = 0; i < repPeriodsSeconds.length; i++) {
    parts.add(
      _singleRepPulse(
        periodSeconds: repPeriodsSeconds[i],
        displacementAmplitudeMeters: displacementAmplitudeMeters,
        sampleIntervalMs: sampleIntervalMs,
        noiseAmplitude: noiseAmplitude,
        randomSeed: randomSeed + i,
      ),
    );
    if (restMsAfterRep[i] > 0) {
      parts.add(
        idleSignal(
          durationMs: restMsAfterRep[i],
          sampleIntervalMs: sampleIntervalMs,
          noiseAmplitude: noiseAmplitude,
          randomSeed: randomSeed + 100 + i,
        ),
      );
    }
  }
  return concat(parts);
}

List<WorkoutThresholdSample> concat(List<List<WorkoutThresholdSample>> parts) {
  final combined = <WorkoutThresholdSample>[];
  var offsetMs = 0;
  for (final part in parts) {
    if (part.isEmpty) continue;
    final base = part.first.timestampMs;
    for (final sample in part) {
      combined.add(
        WorkoutThresholdSample(
          timestampMs: offsetMs + (sample.timestampMs - base),
          verticalAcceleration: sample.verticalAcceleration,
        ),
      );
    }
    offsetMs = combined.last.timestampMs + 20;
  }
  return combined;
}

List<WorkoutThresholdSample> _sample({
  required int totalMs,
  required int sampleIntervalMs,
  required int startTimestampMs,
  required double noiseAmplitude,
  required int randomSeed,
  required double Function(double seconds) valueAt,
}) {
  final random = math.Random(randomSeed);
  final samples = <WorkoutThresholdSample>[];
  for (var elapsedMs = 0; elapsedMs <= totalMs; elapsedMs += sampleIntervalMs) {
    final noise = (random.nextDouble() * 2 - 1) * noiseAmplitude;
    samples.add(
      WorkoutThresholdSample(
        timestampMs: startTimestampMs + elapsedMs,
        verticalAcceleration: valueAt(elapsedMs / 1000) + noise,
      ),
    );
  }
  return samples;
}
