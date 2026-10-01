import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/repositories/workout_repository.dart';
import '../data_sources/workout_local_data_source.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl(this._dataSource);

  final WorkoutLocalDataSource _dataSource;

  @override
  Future<WorkoutThreshold?> getThreshold(ExerciseType exerciseType) {
    return _dataSource.getThreshold(exerciseType);
  }

  @override
  Future<List<WorkoutSession>> getSessions() {
    return _dataSource.getSessions();
  }

  @override
  Future<void> saveSession(WorkoutSession session) {
    return _dataSource.saveSession(session);
  }

  @override
  Future<void> clearSessions() {
    return _dataSource.clearSessions();
  }

  @override
  Future<void> clearThresholds() {
    return _dataSource.clearThresholds();
  }

  @override
  Future<void> saveThreshold(WorkoutThreshold threshold) {
    return _dataSource.saveThreshold(threshold);
  }
}
