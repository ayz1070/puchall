import '../repositories/workout_repository.dart';

class ClearWorkoutThresholds {
  const ClearWorkoutThresholds(this._repository);

  final WorkoutRepository _repository;

  Future<void> call() {
    return _repository.clearThresholds();
  }
}
