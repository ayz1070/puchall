import '../entities/workout_threshold.dart';
import '../repositories/workout_repository.dart';

class SaveWorkoutThreshold {
  const SaveWorkoutThreshold(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(WorkoutThreshold threshold) {
    return _repository.saveThreshold(
      WorkoutThreshold.normalized(
        exerciseType: threshold.exerciseType,
        accelerationMagnitude: threshold.accelerationMagnitude,
      ),
    );
  }
}
