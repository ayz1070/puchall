import '../entities/workout_session.dart';
import '../repositories/workout_repository.dart';

class GetWorkoutSessions {
  const GetWorkoutSessions(this._repository);

  final WorkoutRepository _repository;

  Future<List<WorkoutSession>> call() {
    return _repository.getSessions();
  }
}
