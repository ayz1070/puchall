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
