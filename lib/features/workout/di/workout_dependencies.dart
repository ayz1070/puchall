import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_sources/workout_local_data_source.dart';
import '../data/data_sources/workout_tracking_service_data_source.dart';
import '../data/repositories/workout_repository_impl.dart';
import '../domain/repositories/workout_repository.dart';
import '../domain/use_cases/clear_workout_sessions.dart';
import '../domain/use_cases/clear_workout_thresholds.dart';
import '../domain/use_cases/get_workout_sessions.dart';
import '../domain/use_cases/get_workout_threshold.dart';
import '../domain/use_cases/save_workout_session.dart';
import '../domain/use_cases/save_workout_threshold.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden.');
});

final workoutLocalDataSourceProvider = Provider<WorkoutLocalDataSource>((ref) {
  return WorkoutLocalDataSource(ref.watch(sharedPreferencesProvider));
});

final workoutTrackingServiceDataSourceProvider =
    Provider<WorkoutTrackingServiceDataSource>((ref) {
      return WorkoutTrackingServiceDataSource();
    });

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepositoryImpl(ref.watch(workoutLocalDataSourceProvider));
});

final getWorkoutThresholdUseCaseProvider = Provider<GetWorkoutThreshold>((ref) {
  return GetWorkoutThreshold(ref.watch(workoutRepositoryProvider));
});

final saveWorkoutThresholdUseCaseProvider = Provider<SaveWorkoutThreshold>((
  ref,
) {
  return SaveWorkoutThreshold(ref.watch(workoutRepositoryProvider));
});

final getWorkoutSessionsUseCaseProvider = Provider<GetWorkoutSessions>((ref) {
  return GetWorkoutSessions(ref.watch(workoutRepositoryProvider));
});

final saveWorkoutSessionUseCaseProvider = Provider<SaveWorkoutSession>((ref) {
  return SaveWorkoutSession(ref.watch(workoutRepositoryProvider));
});

final clearWorkoutSessionsUseCaseProvider = Provider<ClearWorkoutSessions>((
  ref,
) {
  return ClearWorkoutSessions(ref.watch(workoutRepositoryProvider));
});

final clearWorkoutThresholdsUseCaseProvider = Provider<ClearWorkoutThresholds>((
  ref,
) {
  return ClearWorkoutThresholds(ref.watch(workoutRepositoryProvider));
});
