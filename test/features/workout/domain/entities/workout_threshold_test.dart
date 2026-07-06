import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_threshold.dart';

void main() {
  group('WorkoutThreshold', () {
    test('normalizes non-positive acceleration magnitude to default', () {
      final threshold = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pushUp,
        accelerationMagnitude: 0,
      );

      expect(
        threshold.accelerationMagnitude,
        WorkoutThreshold.defaultAccelerationMagnitude,
      );
    });

    test('keeps positive acceleration magnitude', () {
      final threshold = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pullUp,
        accelerationMagnitude: 24.5,
      );

      expect(threshold.accelerationMagnitude, 24.5);
    });

    test('normalizes gyroscope magnitude and derives trigger thresholds', () {
      final threshold = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pushUp,
        accelerationMagnitude: 20,
        gyroscopeMagnitude: 2,
      );

      expect(threshold.gyroscopeMagnitude, 2);
      expect(threshold.accelerationThreshold, 15);
      expect(threshold.gyroscopeThreshold, 1.2);
    });

    test('loads legacy json with defaults for new fields', () {
      final threshold = WorkoutThreshold.fromJson({
        'exerciseType': ExerciseType.pushUp.slug,
        'accelerationMagnitude': 21,
      });

      expect(threshold.accelerationMagnitude, 21);
      expect(
        threshold.gyroscopeMagnitude,
        WorkoutThreshold.defaultGyroscopeMagnitude,
      );
      expect(threshold.cooldownMs, WorkoutThreshold.defaultCooldownMs);
    });
  });
}
