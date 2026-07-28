import 'exercise_type.dart';

class DailyWorkoutSummary {
  const DailyWorkoutSummary({
    required this.dateKey,
    required this.pushUpCount,
    required this.pullUpCount,
    required this.runningDistanceMeters,
    required this.walkingDistanceMeters,
  });

  final String dateKey;
  final int pushUpCount;
  final int pullUpCount;
  final double runningDistanceMeters;
  final double walkingDistanceMeters;
}

class ExerciseWorkoutSummary {
  const ExerciseWorkoutSummary({
    required this.exerciseType,
    required this.totalCount,
    required this.sessionCount,
    required this.bestSessionCount,
    required this.totalDistanceMeters,
    required this.bestSessionDistanceMeters,
    required this.totalCaloriesKcal,
  });

  final ExerciseType exerciseType;
  final int totalCount;
  final int sessionCount;
  final int bestSessionCount;
  final double totalDistanceMeters;
  final double bestSessionDistanceMeters;
  final double totalCaloriesKcal;
}
