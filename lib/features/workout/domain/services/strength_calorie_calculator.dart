import '../entities/exercise_type.dart';

class StrengthCalorieCalculator {
  const StrengthCalorieCalculator();

  double calculate({
    required ExerciseType exerciseType,
    required double weightKg,
    required int count,
    required Duration duration,
  }) {
    if (weightKg <= 0 || count <= 0 || duration.inSeconds <= 0) return 0;

    final met = _metFor(exerciseType);
    final secondsPerRep = _secondsPerRepFor(exerciseType);
    if (met <= 0 || secondsPerRep <= 0) return 0;

    final estimatedActiveSeconds = count * secondsPerRep * 1.3;
    final activeSeconds = duration.inSeconds < estimatedActiveSeconds
        ? duration.inSeconds.toDouble()
        : estimatedActiveSeconds;
    final activeMinutes = activeSeconds / 60;

    return met * 3.5 * weightKg / 200 * activeMinutes;
  }

  double _metFor(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.pushUp => 3.8,
      ExerciseType.pullUp => 6.0,
      ExerciseType.running || ExerciseType.walking => 0,
    };
  }

  double _secondsPerRepFor(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.pushUp => 2.5,
      ExerciseType.pullUp => 4.0,
      ExerciseType.running || ExerciseType.walking => 0,
    };
  }
}
