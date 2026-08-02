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
