import '../entities/workout_session.dart';
import '../repositories/workout_repository.dart';

class SaveWorkoutSession {
  const SaveWorkoutSession(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(WorkoutSession session) {
    return _repository.saveSession(session);
  }
}
