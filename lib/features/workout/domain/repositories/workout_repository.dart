import '../entities/exercise_type.dart';
import '../entities/workout_session.dart';
import '../entities/workout_threshold.dart';

abstract class WorkoutRepository {
  Future<WorkoutThreshold?> getThreshold(ExerciseType exerciseType);

  Future<void> saveThreshold(WorkoutThreshold threshold);

  Future<List<WorkoutSession>> getSessions();

  Future<void> saveSession(WorkoutSession session);

  Future<void> clearSessions();
}
