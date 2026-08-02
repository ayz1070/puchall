import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/data/data_sources/workout_local_data_source.dart';
import 'package:puchall/features/workout/data/data_sources/workout_session_database.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_session.dart';
import 'package:puchall/features/workout/domain/entities/workout_threshold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WorkoutLocalDataSource', () {
    late WorkoutLocalDataSource dataSource;
    late Database database;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      database = await openWorkoutSessionDatabase(path: inMemoryDatabasePath);
      dataSource = WorkoutLocalDataSource(preferences, database);
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and loads threshold per exercise type', () async {
      await dataSource.saveThreshold(
        const WorkoutThreshold(
          exerciseType: ExerciseType.pushUp,
          amplitudeThreshold: 1.25,
          minHalfPeriodMs: 420,
          maxHalfPeriodMs: 2400,
          cooldownMs: 900,
          sampleDurationMs: 30000,
          calibratedRepCount: 12,
        ),
      );

      final threshold = await dataSource.getThreshold(ExerciseType.pushUp);

      expect(threshold?.exerciseType, ExerciseType.pushUp);
      expect(threshold?.amplitudeThreshold, 1.25);
      expect(threshold?.minHalfPeriodMs, 420);
      expect(threshold?.maxHalfPeriodMs, 2400);
      expect(threshold?.cooldownMs, 900);
      expect(threshold?.calibratedRepCount, 12);
      expect(await dataSource.getThreshold(ExerciseType.pullUp), isNull);
    });

    test('구버전(v1) 기준치가 저장돼 있으면 복원하지 않는다', () async {
      // 실사용자 기기에 남아 있는 v1 데이터를 흉내 낸다.
      SharedPreferences.setMockInitialValues({
        'workout_threshold_push-up':
            '{"exerciseType":"push-up","accelerationMagnitude":18.0,'
                '"gyroscopeMagnitude":1.2,"releaseRatio":0.55,"cooldownMs":600}',
      });
      final preferences = await SharedPreferences.getInstance();
      final legacyDataSource = WorkoutLocalDataSource(preferences, database);

      expect(await legacyDataSource.getThreshold(ExerciseType.pushUp), isNull);
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
