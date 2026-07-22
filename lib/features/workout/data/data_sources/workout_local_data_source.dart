import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_threshold.dart';

class WorkoutLocalDataSource {
  const WorkoutLocalDataSource(this._preferences);

  final SharedPreferences _preferences;

  static const _thresholdPrefix = 'workout_threshold_';
  static const _sessionsKey = 'workout_sessions';

  Future<WorkoutThreshold?> getThreshold(ExerciseType exerciseType) async {
    final rawValue = _preferences.getString(_thresholdKey(exerciseType));
    if (rawValue == null) return null;

    final json = jsonDecode(rawValue) as Map<String, dynamic>;
    return WorkoutThreshold.fromJson(json);
  }

  Future<void> saveThreshold(WorkoutThreshold threshold) async {
    await _preferences.setString(
      _thresholdKey(threshold.exerciseType),
      jsonEncode(threshold.toJson()),
    );
  }

  Future<List<WorkoutSession>> getSessions() async {
    final rawValue = _preferences.getString(_sessionsKey);
    if (rawValue == null) return [];

    final jsonList = jsonDecode(rawValue) as List<dynamic>;
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(WorkoutSession.fromJson)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> saveSession(WorkoutSession session) async {
    final sessions = await getSessions();
    final updatedSessions = [session, ...sessions];
    await _preferences.setString(
      _sessionsKey,
      jsonEncode(updatedSessions.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearSessions() async {
    await _preferences.remove(_sessionsKey);
  }

  Future<void> clearThresholds() async {
    for (final exerciseType in ExerciseType.values) {
      await _preferences.remove(_thresholdKey(exerciseType));
    }
  }

  static String _thresholdKey(ExerciseType exerciseType) {
    return '$_thresholdPrefix${exerciseType.slug}';
  }
}
