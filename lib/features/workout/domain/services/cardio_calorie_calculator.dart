import '../entities/exercise_type.dart';

class CardioCalorieCalculator {
  const CardioCalorieCalculator();

  double calculate({
    required ExerciseType exerciseType,
    required double weightKg,
    required Duration duration,
    required double distanceMeters,
  }) {
    final minutes = duration.inSeconds / 60;
    if (minutes <= 0 || weightKg <= 0) return 0;

    final met = _metFor(
      exerciseType: exerciseType,
      duration: duration,
      distanceMeters: distanceMeters,
    );
    return met * 3.5 * weightKg / 200 * minutes;
  }

  double _metFor({
    required ExerciseType exerciseType,
    required Duration duration,
    required double distanceMeters,
  }) {
    if (exerciseType == ExerciseType.walking) return 3.5;
    if (exerciseType != ExerciseType.running) return 0;

    final hours = duration.inSeconds / 3600;
    if (hours <= 0) return 7;

    final speedKmh = distanceMeters / 1000 / hours;
    if (speedKmh < 8) return 7;
    if (speedKmh < 10) return 9.8;
    if (speedKmh < 12) return 11;
    return 11.5;
  }
}
