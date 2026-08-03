import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/services/workout_threshold_calibrator.dart';

import 'signal_fixtures.dart';

void main() {
  const calibrator = WorkoutThresholdCalibrator();

  group('WorkoutThresholdCalibrator', () {
    test('실제 반복에서 기준치를 뽑고 같은 구간을 다시 세어 검증한다', () {
      final samples = repSignal(
        repCount: 15,
        periodSeconds: 2,
        displacementAmplitudeMeters: 0.1,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pushUp,
        samples: samples,
        sampleDurationMs: 30000,
      );

      expect(result, isNotNull);
      // 기준치는 사용자의 평균 진폭 절반 근처여야 한다.
      expect(
        result!.threshold.amplitudeThreshold,
        closeTo(result.medianAmplitude * 0.5, 0.01),
      );
      // 폐루프 검증 결과가 실제 반복 횟수와 맞아야 한다.
      expect(result.detectedRepCount, closeTo(15, 1));
      expect(result.threshold.calibratedRepCount, result.detectedRepCount);
      expect(result.threshold.minHalfPeriodMs, greaterThanOrEqualTo(300));
      expect(result.threshold.cooldownMs, greaterThanOrEqualTo(800));
      expect(result.signalQuality, greaterThan(0.7));
    });

    test('느린 반복 사용자에게는 낮은 기준치를 만들어 준다', () {
      final samples = repSignal(
        repCount: 8,
        periodSeconds: 3.5,
        displacementAmplitudeMeters: 0.1,
        noiseAmplitude: 0.02,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pushUp,
        samples: samples,
        sampleDurationMs: 28000,
      );

      expect(result, isNotNull);
      // 기본값(0.8)보다 훨씬 낮은 기준치가 나와야 이 사용자의 반복이 인식된다.
      expect(result!.threshold.amplitudeThreshold, lessThan(0.5));
      expect(result.detectedRepCount, closeTo(8, 1));
    });

    test('풀업처럼 반대로 들어온 신호는 방향 보정값을 저장한다', () {
      final samples =
          repSignal(
                repCount: 7,
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

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pullUp,
        samples: samples,
        sampleDurationMs: 21000,
      );

      expect(result, isNotNull);
      expect(result!.threshold.verticalAccelerationScale, -1);
      expect(result.detectedRepCount, closeTo(7, 1));
    });

    test('풀업 세트 후반 힘이 빠져 진폭이 60% 줄어도 모든 반복을 인식한다', () {
      final samples = decayingRepSignal(
        repCount: 8,
        periodSeconds: 3,
        displacementAmplitudeMeters: 0.14,
        decayedDisplacementAmplitudeMeters: 0.056,
        noiseAmplitude: 0.02,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pullUp,
        samples: samples,
        sampleDurationMs: 24000,
      );

      expect(result, isNotNull);
      // 마지막 약한 반복까지 포함해 8회가 모두 인식돼야 한다.
      expect(result!.detectedRepCount, 8);
    });

    test('풀업 세트 후반 힘이 크게 빠져 진폭이 75% 줄어도 대부분의 반복을 인식한다', () {
      final samples = decayingRepSignal(
        repCount: 8,
        periodSeconds: 3,
        displacementAmplitudeMeters: 0.16,
        decayedDisplacementAmplitudeMeters: 0.04,
        noiseAmplitude: 0.02,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pullUp,
        samples: samples,
        sampleDurationMs: 24000,
      );

      expect(result, isNotNull);
      // 초반 대비 힘이 크게 빠지더라도 마지막 1~2회 정도만 놓치는 수준이어야 한다.
      expect(result!.detectedRepCount, greaterThanOrEqualTo(7));
    });

    test('반복 사이 데드행(정지) 구간이 불규칙해도 모든 반복을 인식한다', () {
      final samples = deadHangRepSignal(
        repPeriodsSeconds: [1.8, 2.2, 1.6, 2.5, 1.9, 2.0, 1.7],
        restMsAfterRep: [400, 1500, 300, 2200, 500, 1800, 300],
        displacementAmplitudeMeters: 0.12,
        noiseAmplitude: 0.02,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pullUp,
        samples: samples,
        sampleDurationMs: 25000,
      );

      expect(result, isNotNull);
      expect(result!.detectedRepCount, 7);
    });

    test('캡처가 너무 짧으면 기준치를 만들지 않는다', () {
      final samples = repSignal(
        repCount: 2,
        periodSeconds: 2,
        displacementAmplitudeMeters: 0.1,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pullUp,
        samples: samples,
        sampleDurationMs: WorkoutThresholdCalibrator.minimumDurationMs - 1,
      );

      expect(result, isNull);
    });

    test('반복이 감지되지 않으면 기준치를 만들지 않는다', () {
      final samples = idleSignal(durationMs: 30000);

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pushUp,
        samples: samples,
        sampleDurationMs: 30000,
      );

      expect(result, isNull);
    });

    test('기준치는 최소 진폭 하한 아래로 내려가지 않는다', () {
      // 거의 움직이지 않는 미세한 반복 → 잡음 수준까지 기준치가 내려가면 안 된다.
      final samples = repSignal(
        repCount: 10,
        periodSeconds: 3,
        displacementAmplitudeMeters: 0.005,
        noiseAmplitude: 0.01,
      );

      final result = calibrator.calibrate(
        exerciseType: ExerciseType.pushUp,
        samples: samples,
        sampleDurationMs: 30000,
      );

      if (result != null) {
        expect(result.threshold.amplitudeThreshold, greaterThanOrEqualTo(0.15));
      }
    });
  });
}
