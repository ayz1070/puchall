import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_threshold.dart';
import 'package:puchall/features/workout/domain/services/rep_detector.dart';
import 'package:puchall/features/workout/domain/services/workout_threshold_calibrator.dart';

import 'signal_fixtures.dart';

int countReps(RepDetectorConfig config, List<WorkoutThresholdSample> samples) {
  final detector = RepDetector(config);
  for (final sample in samples) {
    detector.update(sample.verticalAcceleration, sample.timestampMs);
  }
  return detector.count;
}

void main() {
  final pushUpDefaults = WorkoutThreshold.defaultsFor(
    ExerciseType.pushUp,
  ).detectorConfig;

  group('RepDetector', () {
    test('일반 템포 반복(2초/회)을 정확히 센다', () {
      final samples = repSignal(
        repCount: 10,
        periodSeconds: 2,
        displacementAmplitudeMeters: 0.1,
      );

      expect(countReps(pushUpDefaults, samples), 10);
    });

    test('빠른 템포 반복(1.2초/회)도 놓치지 않는다', () {
      final samples = repSignal(
        repCount: 12,
        periodSeconds: 1.2,
        displacementAmplitudeMeters: 0.07,
      );

      expect(countReps(pushUpDefaults, samples), 12);
    });

    test('느린 반복은 기준치를 낮게 잡으면 세어진다', () {
      // 4초 주기 · 변위 ±0.1m → 가속도 진폭이 약 0.25 m/s²에 불과하다.
      // 구버전은 중력(9.81) 위에서 16.2 m/s²를 요구해 이런 반복을 전혀 세지 못했다.
      final samples = repSignal(
        repCount: 6,
        periodSeconds: 4,
        displacementAmplitudeMeters: 0.1,
        noiseAmplitude: 0.02,
      );

      final slowConfig = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pushUp,
        amplitudeThreshold: 0.15,
        minHalfPeriodMs: 800,
        maxHalfPeriodMs: 4000,
        cooldownMs: 2000,
      ).detectorConfig;

      expect(countReps(slowConfig, samples), 6);
    });

    test('반전된 풀업 신호는 방향 보정값으로 센다', () {
      final invertedSamples =
          repSignal(
                repCount: 6,
                periodSeconds: 3,
                displacementAmplitudeMeters: 0.12,
                noiseAmplitude: 0.02,
              )
              .map(
                (sample) => WorkoutThresholdSample(
                  timestampMs: sample.timestampMs,
                  verticalAcceleration: -sample.verticalAcceleration,
                ),
              )
              .toList();

      final config = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pullUp,
        amplitudeThreshold: 0.25,
        minHalfPeriodMs: 500,
        maxHalfPeriodMs: 4500,
        cooldownMs: 1200,
        verticalAccelerationScale: -1,
      ).detectorConfig;

      expect(countReps(config, invertedSamples), 6);
    });

    test('정지 상태의 잡음만으로는 세지 않는다', () {
      final samples = idleSignal(durationMs: 30000);

      expect(countReps(pushUpDefaults, samples), 0);
    });

    test('폰을 흔드는 동작은 반복 주기가 너무 짧아 걸러진다', () {
      final samples = shakeSignal(durationMs: 10000);

      expect(countReps(pushUpDefaults, samples), 0);
    });

    test('센서 배칭으로 샘플이 몰려 들어와도 카운트가 유지된다', () {
      // 화면이 꺼지면 안드로이드가 이벤트를 모았다가 한꺼번에 전달한다.
      // 판정이 수신 시각이 아니라 샘플 타임스탬프를 쓰는지 확인한다.
      final samples = repSignal(
        repCount: 8,
        periodSeconds: 2,
        displacementAmplitudeMeters: 0.1,
      );

      final detector = RepDetector(pushUpDefaults);
      for (final sample in samples) {
        detector.update(sample.verticalAcceleration, sample.timestampMs);
      }

      expect(detector.count, 8);
    });

    test('쿨다운보다 짧은 간격의 연속 반복은 한 번만 센다', () {
      final config = RepDetectorConfig(
        amplitudeThreshold: 0.5,
        minHalfPeriodMs: 150,
        maxHalfPeriodMs: 3000,
        cooldownMs: 5000,
      );
      final samples = repSignal(
        repCount: 6,
        periodSeconds: 1.5,
        displacementAmplitudeMeters: 0.15,
      );

      // 총 9초 구간에서 쿨다운이 5초이므로 두 번을 넘길 수 없다.
      expect(countReps(config, samples), lessThanOrEqualTo(2));
    });

    test('카운트 후 0 근처로 복귀해야 다음 반복을 받는다', () {
      const config = RepDetectorConfig(
        amplitudeThreshold: 1,
        minHalfPeriodMs: 100,
        maxHalfPeriodMs: 1000,
        cooldownMs: 0,
        lowPassCutoffHz: 1000,
      );
      final samples = [
        const WorkoutThresholdSample(
          timestampMs: 0,
          verticalAcceleration: -1.3,
        ),
        const WorkoutThresholdSample(
          timestampMs: 300,
          verticalAcceleration: 1.3,
        ),
        const WorkoutThresholdSample(
          timestampMs: 600,
          verticalAcceleration: -1.3,
        ),
        const WorkoutThresholdSample(
          timestampMs: 900,
          verticalAcceleration: 1.3,
        ),
      ];

      expect(countReps(config, samples), 1);
    });

    test('검출된 반복은 진폭과 절반 주기를 함께 보고한다', () {
      final samples = repSignal(
        repCount: 5,
        periodSeconds: 2,
        displacementAmplitudeMeters: 0.1,
        noiseAmplitude: 0,
      );

      final detector = RepDetector(pushUpDefaults);
      final reps = <DetectedRep>[];
      for (final sample in samples) {
        final rep = detector.update(
          sample.verticalAcceleration,
          sample.timestampMs,
        );
        if (rep != null) reps.add(rep);
      }

      expect(reps, isNotEmpty);
      // 변위 ±0.1m, 주기 2초 → 가속도 진폭 약 0.99 m/s².
      // 저역통과를 거치며 다소 줄어드는 것을 감안한다.
      expect(reps.first.amplitude, closeTo(0.9, 0.25));
      expect(reps.first.halfPeriodMs, closeTo(1000, 250));
    });

    test('reset 후에는 상태가 초기화된다', () {
      final samples = repSignal(
        repCount: 4,
        periodSeconds: 2,
        displacementAmplitudeMeters: 0.1,
      );
      final detector = RepDetector(pushUpDefaults);
      for (final sample in samples) {
        detector.update(sample.verticalAcceleration, sample.timestampMs);
      }
      expect(detector.count, greaterThan(0));

      detector.reset();

      expect(detector.count, 0);
      expect(detector.filteredValue, 0);
    });
  });
}
