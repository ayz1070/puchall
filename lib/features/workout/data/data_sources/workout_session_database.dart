import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 운동 세션을 저장하는 SQLite 테이블을 연다.
///
/// 기존에는 세션 전체를 하나의 JSON 블롭으로 SharedPreferences에 저장해서,
/// 세션을 하나 추가할 때마다 이미 저장된 전체 목록을 다시 읽고 다시 써야 했다.
/// 사용 기간이 길어질수록 그 비용이 계속 커지는 구조라, 세션 단위로 행을
/// 추가/삭제할 수 있는 SQLite로 옮겼다.
Future<Database> openWorkoutSessionDatabase({String? path}) async {
  final resolvedPath =
      path ?? join(await getDatabasesPath(), 'workout_sessions.db');
  return openDatabase(
    resolvedPath,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE workout_sessions (
          id TEXT PRIMARY KEY,
          exerciseType TEXT NOT NULL,
          count INTEGER NOT NULL,
          startedAt TEXT NOT NULL,
          endedAt TEXT NOT NULL,
          distanceMeters REAL NOT NULL,
          caloriesKcal REAL NOT NULL,
          steps INTEGER NOT NULL,
          activeDurationSeconds INTEGER,
          movingDurationSeconds INTEGER,
          averageSpeedMetersPerSecond REAL NOT NULL,
          averagePaceSecondsPerKm REAL NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_workout_sessions_started_at ON workout_sessions (startedAt)',
      );
    },
  );
}
