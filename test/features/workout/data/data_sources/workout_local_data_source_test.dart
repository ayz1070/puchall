import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/data/data_sources/workout_local_data_source.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_session.dart';
import 'package:puchall/features/workout/domain/entities/workout_threshold.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WorkoutLocalDataSource', () {
    late WorkoutLocalDataSource dataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      dataSource = WorkoutLocalDataSource(preferences);
    });

    test('saves and loads threshold per exercise type', () async {
      await dataSource.saveThreshold(
        const WorkoutThreshold(
          exerciseType: ExerciseType.pushUp,
          accelerationMagnitude: 22.5,
          gyroscopeMagnitude: 2.5,
          sampleDurationMs: 1400,
        ),
      );

      final threshold = await dataSource.getThreshold(ExerciseType.pushUp);

      expect(threshold?.exerciseType, ExerciseType.pushUp);
      expect(threshold?.accelerationMagnitude, 22.5);
      expect(threshold?.gyroscopeMagnitude, 2.5);
      expect(threshold?.sampleDurationMs, 1400);
      expect(await dataSource.getThreshold(ExerciseType.pullUp), isNull);
    });

    test('saves sessions in newest-first order', () async {
      final firstStartedAt = DateTime(2026, 7, 5, 10);
      final secondStartedAt = DateTime(2026, 7, 5, 11);

      await dataSource.saveSession(
        WorkoutSession(
          id: 'first',
          exerciseType: ExerciseType.pushUp,
          count: 10,
          startedAt: firstStartedAt,
          endedAt: firstStartedAt.add(const Duration(minutes: 1)),
        ),
      );
      await dataSource.saveSession(
        WorkoutSession(
          id: 'second',
          exerciseType: ExerciseType.pullUp,
          count: 5,
          startedAt: secondStartedAt,
          endedAt: secondStartedAt.add(const Duration(minutes: 1)),
        ),
      );

      final sessions = await dataSource.getSessions();

      expect(sessions.map((session) => session.id), ['second', 'first']);
    });

    test('clears saved sessions', () async {
      final startedAt = DateTime(2026, 7, 5, 10);
      await dataSource.saveSession(
        WorkoutSession(
          id: 'session',
          exerciseType: ExerciseType.pushUp,
          count: 10,
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 1)),
        ),
      );

      await dataSource.clearSessions();

      expect(await dataSource.getSessions(), isEmpty);
    });
  });
}
