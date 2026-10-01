import '../repositories/workout_repository.dart';

class ClearWorkoutSessions {
  const ClearWorkoutSessions(this._repository);

  final WorkoutRepository _repository;

  Future<void> call() {
    return _repository.clearSessions();
  }
}
