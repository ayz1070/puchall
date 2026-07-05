import '../entities/exercise_type.dart';
import '../entities/workout_threshold.dart';
import '../repositories/workout_repository.dart';

class GetWorkoutThreshold {
  const GetWorkoutThreshold(this._repository);

  final WorkoutRepository _repository;

  Future<WorkoutThreshold?> call(ExerciseType exerciseType) {
    return _repository.getThreshold(exerciseType);
  }
}
