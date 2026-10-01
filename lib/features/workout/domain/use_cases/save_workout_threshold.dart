import '../entities/workout_threshold.dart';
import '../repositories/workout_repository.dart';

class SaveWorkoutThreshold {
  const SaveWorkoutThreshold(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(WorkoutThreshold threshold) {
    return _repository.saveThreshold(
      WorkoutThreshold.normalized(
        exerciseType: threshold.exerciseType,
        amplitudeThreshold: threshold.amplitudeThreshold,
        minHalfPeriodMs: threshold.minHalfPeriodMs,
        maxHalfPeriodMs: threshold.maxHalfPeriodMs,
        cooldownMs: threshold.cooldownMs,
        lowPassCutoffHz: threshold.lowPassCutoffHz,
        verticalAccelerationScale: threshold.verticalAccelerationScale,
        sampleDurationMs: threshold.sampleDurationMs,
        calibratedRepCount: threshold.calibratedRepCount,
      ),
    );
  }
}
