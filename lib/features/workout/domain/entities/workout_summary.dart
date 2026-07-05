import 'exercise_type.dart';

class DailyWorkoutSummary {
  const DailyWorkoutSummary({
    required this.dateKey,
    required this.pushUpCount,
    required this.pullUpCount,
  });

  final String dateKey;
  final int pushUpCount;
  final int pullUpCount;
}

class ExerciseWorkoutSummary {
  const ExerciseWorkoutSummary({
    required this.exerciseType,
    required this.totalCount,
    required this.sessionCount,
    required this.bestSessionCount,
  });

  final ExerciseType exerciseType;
  final int totalCount;
  final int sessionCount;
  final int bestSessionCount;
}
