import '../entities/exercise_type.dart';
import '../entities/workout_session.dart';
import '../entities/workout_summary.dart';

class WorkoutHistorySummarizer {
  const WorkoutHistorySummarizer();

  DailyWorkoutSummary summarizeToday({
    required List<WorkoutSession> sessions,
    required DateTime now,
  }) {
    final todayKey = _dateKey(now);
    var pushUpCount = 0;
    var pullUpCount = 0;

    for (final session in sessions) {
      if (session.dateKey != todayKey) continue;
      switch (session.exerciseType) {
        case ExerciseType.pushUp:
          pushUpCount += session.count;
          break;
        case ExerciseType.pullUp:
          pullUpCount += session.count;
          break;
      }
    }

    return DailyWorkoutSummary(
      dateKey: todayKey,
      pushUpCount: pushUpCount,
      pullUpCount: pullUpCount,
    );
  }

  List<DailyWorkoutSummary> summarizeByDate(List<WorkoutSession> sessions) {
    final summariesByDate = <String, ({int pushUpCount, int pullUpCount})>{};

    for (final session in sessions) {
      final current =
          summariesByDate[session.dateKey] ?? (pushUpCount: 0, pullUpCount: 0);
      summariesByDate[session.dateKey] = switch (session.exerciseType) {
        ExerciseType.pushUp => (
          pushUpCount: current.pushUpCount + session.count,
          pullUpCount: current.pullUpCount,
        ),
        ExerciseType.pullUp => (
          pushUpCount: current.pushUpCount,
          pullUpCount: current.pullUpCount + session.count,
        ),
      };
    }

    return summariesByDate.entries
        .map(
          (entry) => DailyWorkoutSummary(
            dateKey: entry.key,
            pushUpCount: entry.value.pushUpCount,
            pullUpCount: entry.value.pullUpCount,
          ),
        )
        .toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
  }

  List<ExerciseWorkoutSummary> summarizeByExercise(
    List<WorkoutSession> sessions,
  ) {
    return ExerciseType.values.map((exerciseType) {
      final exerciseSessions = sessions
          .where((session) => session.exerciseType == exerciseType)
          .toList();
      final totalCount = exerciseSessions.fold<int>(
        0,
        (sum, session) => sum + session.count,
      );
      final bestSessionCount = exerciseSessions.fold<int>(
        0,
        (best, session) => session.count > best ? session.count : best,
      );

      return ExerciseWorkoutSummary(
        exerciseType: exerciseType,
        totalCount: totalCount,
        sessionCount: exerciseSessions.length,
        bestSessionCount: bestSessionCount,
      );
    }).toList();
  }

  String _dateKey(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
