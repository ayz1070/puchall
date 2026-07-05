import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/workout_dependencies.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_summary.dart';
import '../../domain/services/workout_history_summarizer.dart';

final workoutHistoryProvider = FutureProvider.autoDispose<List<WorkoutSession>>(
  (ref) async {
    final getSessions = ref.watch(getWorkoutSessionsUseCaseProvider);
    return getSessions();
  },
);

final clearWorkoutHistoryProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final clearSessions = ref.watch(clearWorkoutSessionsUseCaseProvider);
  await clearSessions();
  ref.invalidate(workoutHistoryProvider);
  ref.invalidate(todayWorkoutSummaryProvider);
  ref.invalidate(dailyWorkoutSummariesProvider);
  ref.invalidate(exerciseWorkoutSummariesProvider);
});

final todayWorkoutSummaryProvider =
    FutureProvider.autoDispose<DailyWorkoutSummary>((ref) async {
      final sessions = await ref.watch(workoutHistoryProvider.future);
      return const WorkoutHistorySummarizer().summarizeToday(
        sessions: sessions,
        now: DateTime.now(),
      );
    });

final dailyWorkoutSummariesProvider =
    FutureProvider.autoDispose<List<DailyWorkoutSummary>>((ref) async {
      final sessions = await ref.watch(workoutHistoryProvider.future);
      return const WorkoutHistorySummarizer().summarizeByDate(sessions);
    });

final exerciseWorkoutSummariesProvider =
    FutureProvider.autoDispose<List<ExerciseWorkoutSummary>>((ref) async {
      final sessions = await ref.watch(workoutHistoryProvider.future);
      return const WorkoutHistorySummarizer().summarizeByExercise(sessions);
    });
