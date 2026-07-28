import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_session.dart';
import 'package:puchall/features/workout/domain/services/workout_history_summarizer.dart';

void main() {
  group('WorkoutHistorySummarizer', () {
    const summarizer = WorkoutHistorySummarizer();

    test('summarizes today by exercise type', () {
      final sessions = [
        _session(
          id: 'today-push',
          exerciseType: ExerciseType.pushUp,
          count: 10,
          startedAt: DateTime(2026, 7, 5, 9),
        ),
        _session(
          id: 'today-pull',
          exerciseType: ExerciseType.pullUp,
          count: 3,
          startedAt: DateTime(2026, 7, 5, 10),
        ),
        _session(
          id: 'today-running',
          exerciseType: ExerciseType.running,
          count: 0,
          distanceMeters: 3200,
          startedAt: DateTime(2026, 7, 5, 11),
        ),
        _session(
          id: 'today-walking',
          exerciseType: ExerciseType.walking,
          count: 0,
          distanceMeters: 1400,
          startedAt: DateTime(2026, 7, 5, 11, 30),
        ),
        _session(
          id: 'yesterday-push',
          exerciseType: ExerciseType.pushUp,
          count: 99,
          startedAt: DateTime(2026, 7, 4, 9),
        ),
      ];

      final summary = summarizer.summarizeToday(
        sessions: sessions,
        now: DateTime(2026, 7, 5, 12),
      );

      expect(summary.dateKey, '2026-07-05');
      expect(summary.pushUpCount, 10);
      expect(summary.pullUpCount, 3);
      expect(summary.runningDistanceMeters, 3200);
      expect(summary.walkingDistanceMeters, 1400);
    });

    test('summarizes sessions by date in newest-first order', () {
      final sessions = [
        _session(
          id: 'old',
          exerciseType: ExerciseType.pushUp,
          count: 10,
          startedAt: DateTime(2026, 7, 4, 9),
        ),
        _session(
          id: 'new-push',
          exerciseType: ExerciseType.pushUp,
          count: 5,
          startedAt: DateTime(2026, 7, 5, 9),
        ),
        _session(
          id: 'new-pull',
          exerciseType: ExerciseType.pullUp,
          count: 2,
          startedAt: DateTime(2026, 7, 5, 10),
        ),
        _session(
          id: 'new-running',
          exerciseType: ExerciseType.running,
          count: 0,
          distanceMeters: 2500,
          startedAt: DateTime(2026, 7, 5, 11),
        ),
      ];

      final summaries = summarizer.summarizeByDate(sessions);

      expect(summaries.map((summary) => summary.dateKey), [
        '2026-07-05',
        '2026-07-04',
      ]);
      expect(summaries.first.pushUpCount, 5);
      expect(summaries.first.pullUpCount, 2);
      expect(summaries.first.runningDistanceMeters, 2500);
      expect(summaries.first.walkingDistanceMeters, 0);
    });

    test('summarizes totals, session count, and best session by exercise', () {
      final sessions = [
        _session(
          id: 'push-1',
          exerciseType: ExerciseType.pushUp,
          count: 10,
          startedAt: DateTime(2026, 7, 5, 9),
        ),
        _session(
          id: 'push-2',
          exerciseType: ExerciseType.pushUp,
          count: 12,
          startedAt: DateTime(2026, 7, 5, 10),
        ),
        _session(
          id: 'pull-1',
          exerciseType: ExerciseType.pullUp,
          count: 4,
          startedAt: DateTime(2026, 7, 5, 11),
        ),
        _session(
          id: 'running-1',
          exerciseType: ExerciseType.running,
          count: 0,
          distanceMeters: 3000,
          caloriesKcal: 180,
          startedAt: DateTime(2026, 7, 5, 12),
        ),
        _session(
          id: 'running-2',
          exerciseType: ExerciseType.running,
          count: 0,
          distanceMeters: 5000,
          caloriesKcal: 300,
          startedAt: DateTime(2026, 7, 5, 13),
        ),
      ];

      final summaries = summarizer.summarizeByExercise(sessions);
      final pushUp = summaries.firstWhere(
        (summary) => summary.exerciseType == ExerciseType.pushUp,
      );
      final pullUp = summaries.firstWhere(
        (summary) => summary.exerciseType == ExerciseType.pullUp,
      );
      final running = summaries.firstWhere(
        (summary) => summary.exerciseType == ExerciseType.running,
      );

      expect(pushUp.totalCount, 22);
      expect(pushUp.sessionCount, 2);
      expect(pushUp.bestSessionCount, 12);
      expect(pullUp.totalCount, 4);
      expect(pullUp.sessionCount, 1);
      expect(pullUp.bestSessionCount, 4);
      expect(running.totalDistanceMeters, 8000);
      expect(running.bestSessionDistanceMeters, 5000);
      expect(running.totalCaloriesKcal, 480);
    });
  });
}

WorkoutSession _session({
  required String id,
  required ExerciseType exerciseType,
  required int count,
  required DateTime startedAt,
  double distanceMeters = 0,
  double caloriesKcal = 0,
}) {
  return WorkoutSession(
    id: id,
    exerciseType: exerciseType,
    count: count,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 1)),
    distanceMeters: distanceMeters,
    caloriesKcal: caloriesKcal,
  );
}
