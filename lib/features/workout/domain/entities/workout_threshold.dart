import 'exercise_type.dart';

class WorkoutThreshold {
  const WorkoutThreshold({
    required this.exerciseType,
    required this.accelerationMagnitude,
  });

  factory WorkoutThreshold.normalized({
    required ExerciseType exerciseType,
    required double accelerationMagnitude,
  }) {
    return WorkoutThreshold(
      exerciseType: exerciseType,
      accelerationMagnitude: accelerationMagnitude <= 0
          ? defaultAccelerationMagnitude
          : accelerationMagnitude,
    );
  }

  static const defaultAccelerationMagnitude = 18.0;

  final ExerciseType exerciseType;
  final double accelerationMagnitude;

  Map<String, dynamic> toJson() {
    return {
      'exerciseType': exerciseType.slug,
      'accelerationMagnitude': accelerationMagnitude,
    };
  }

  static WorkoutThreshold fromJson(Map<String, dynamic> json) {
    return WorkoutThreshold(
      exerciseType: ExerciseType.fromSlug(json['exerciseType'] as String?),
      accelerationMagnitude:
          (json['accelerationMagnitude'] as num?)?.toDouble() ??
          defaultAccelerationMagnitude,
    );
  }
}
