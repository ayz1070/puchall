import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_threshold.dart';

class WorkoutLocalDataSource {
  WorkoutLocalDataSource(this._preferences, this._database);

  final SharedPreferences _preferences;
  final Database _database;

  static const _thresholdPrefix = 'workout_threshold_';
  static const _legacySessionsKey = 'workout_sessions';
  static const _sessionsTable = 'workout_sessions';

  bool _legacySessionsMigrated = false;

  Future<WorkoutThreshold?> getThreshold(ExerciseType exerciseType) async {
    final rawValue = _preferences.getString(_thresholdKey(exerciseType));
    if (rawValue == null) return null;

    try {
      final json = jsonDecode(rawValue) as Map<String, dynamic>;
      // 구버전(v1) 기준치는 신호 공간이 달라 복원하지 않는다. null을 돌려주면
      // 사용자는 기본값으로 측정하다가 기준치를 다시 측정하게 된다.
      return WorkoutThreshold.tryFromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveThreshold(WorkoutThreshold threshold) async {
    await _preferences.setString(
      _thresholdKey(threshold.exerciseType),
      jsonEncode(threshold.toJson()),
    );
  }

  Future<List<WorkoutSession>> getSessions() async {
    await _migrateLegacySessionsIfNeeded();

    final rows = await _database.query(
      _sessionsTable,
      orderBy: 'startedAt DESC',
    );
    return rows.map(WorkoutSession.fromJson).toList();
  }

  Future<void> saveSession(WorkoutSession session) async {
    await _migrateLegacySessionsIfNeeded();

    await _database.insert(
      _sessionsTable,
      session.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearSessions() async {
    await _migrateLegacySessionsIfNeeded();
    await _database.delete(_sessionsTable);
  }

  Future<void> clearThresholds() async {
    for (final exerciseType in ExerciseType.values.where(
      (type) => type.isStrength,
    )) {
      await _preferences.remove(_thresholdKey(exerciseType));
    }
  }

  static String _thresholdKey(ExerciseType exerciseType) {
    return '$_thresholdPrefix${exerciseType.slug}';
  }

  /// 이전에는 세션 전체를 하나의 JSON 블롭으로 SharedPreferences에 저장했다.
  /// 최초 접근 시 그 블롭을 SQLite로 한 번만 옮기고 원본 키는 지운다.
  Future<void> _migrateLegacySessionsIfNeeded() async {
    if (_legacySessionsMigrated) return;
    _legacySessionsMigrated = true;

    final rawValue = _preferences.getString(_legacySessionsKey);
    if (rawValue == null) return;

    try {
      final jsonList = jsonDecode(rawValue) as List<dynamic>;
      final sessions = jsonList.whereType<Map<String, dynamic>>().map(
        WorkoutSession.fromJson,
      );

      final batch = _database.batch();
      for (final session in sessions) {
        batch.insert(
          _sessionsTable,
          session.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } on FormatException {
      // 손상된 레거시 데이터는 복구하지 않고 버린다.
    } on TypeError {
      // 손상된 레거시 데이터는 복구하지 않고 버린다.
    }

    await _preferences.remove(_legacySessionsKey);
  }
}
