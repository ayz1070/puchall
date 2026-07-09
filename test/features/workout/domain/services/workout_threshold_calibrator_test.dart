import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/services/workout_threshold_calibrator.dart';

void main() {
  group('WorkoutThresholdCalibrator', () {
    test('uses stable baseline and representative peaks for thresholds', () {
      final samples = [
        const WorkoutThresholdSample(
          elapsedMs: 0,
          accelerationMagnitude: 10,
          gyroscopeMagnitude: 1,
          magnetometerMagnitude: 40,
        ),
        const WorkoutThresholdSample(
          elapsedMs: 500,
          accelerationMagnitude: 10.1,
          gyroscopeMagnitude: 1.05,
          magnetometerMagnitude: 40.2,
        ),
        const WorkoutThresholdSample(
          elapsedMs: 1000,
          accelerationMagnitude: 9.9,
          gyroscopeMagnitude: 0.95,
          magnetometerMagnitude: 39.8,
        ),
        for (var i = 0; i < 5; i++)
          WorkoutThresholdSample(
            elapsedMs: 6000 + i * 700,
            accelerationMagnitude: 28.0 + i,
            gyroscopeMagnitude: 2.8 + i * 0.1,
            magnetometerMagnitude: 58.0 + i,
          ),
      ];

      final threshold = const WorkoutThresholdCalibrator().calibrate(
        exerciseType: ExerciseType.pushUp,
        samples: samples,
        sampleDurationMs: WorkoutThresholdCalibrator.calibrationDurationMs,
      );

      expect(threshold, isNotNull);
      expect(threshold!.accelerationMagnitude, closeTo(27, 0.01));
      expect(threshold.gyroscopeMagnitude, closeTo(2.7, 0.01));
      expect(threshold.magnetometerMagnitude, closeTo(57, 0.01));
      expect(threshold.accelerationTriggerRatio, 1);
      expect(threshold.gyroscopeTriggerRatio, 1);
      expect(threshold.magnetometerTriggerRatio, 1);
    });

    test('returns null when capture duration is too short', () {
      final samples = List.generate(
        6,
        (index) => WorkoutThresholdSample(
          elapsedMs: index * 100,
          accelerationMagnitude: 10.0 + index,
          gyroscopeMagnitude: 1.0 + index,
          magnetometerMagnitude: 40.0 + index,
        ),
      );

      final threshold = const WorkoutThresholdCalibrator().calibrate(
        exerciseType: ExerciseType.pullUp,
        samples: samples,
        sampleDurationMs: WorkoutThresholdCalibrator.minimumDurationMs - 1,
      );

      expect(threshold, isNull);
    });
  });
}
