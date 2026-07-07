import 'exercise_type.dart';

class WorkoutThreshold {
  const WorkoutThreshold({
    required this.exerciseType,
    required this.accelerationMagnitude,
    this.gyroscopeMagnitude = defaultGyroscopeMagnitude,
    this.magnetometerMagnitude = defaultMagnetometerMagnitude,
    this.sampleDurationMs = defaultSampleDurationMs,
    this.accelerationTriggerRatio = defaultAccelerationTriggerRatio,
    this.gyroscopeTriggerRatio = defaultGyroscopeTriggerRatio,
    this.magnetometerTriggerRatio = defaultMagnetometerTriggerRatio,
    this.releaseRatio = defaultReleaseRatio,
    this.cooldownMs = defaultCooldownMs,
  });

  factory WorkoutThreshold.normalized({
    required ExerciseType exerciseType,
    required double accelerationMagnitude,
    double gyroscopeMagnitude = defaultGyroscopeMagnitude,
    double magnetometerMagnitude = defaultMagnetometerMagnitude,
    int sampleDurationMs = defaultSampleDurationMs,
    double accelerationTriggerRatio = defaultAccelerationTriggerRatio,
    double gyroscopeTriggerRatio = defaultGyroscopeTriggerRatio,
    double magnetometerTriggerRatio = defaultMagnetometerTriggerRatio,
    double releaseRatio = defaultReleaseRatio,
    int cooldownMs = defaultCooldownMs,
  }) {
    return WorkoutThreshold(
      exerciseType: exerciseType,
      accelerationMagnitude: accelerationMagnitude <= 0
          ? defaultAccelerationMagnitude
          : accelerationMagnitude,
      gyroscopeMagnitude: gyroscopeMagnitude <= 0
          ? defaultGyroscopeMagnitude
          : gyroscopeMagnitude,
      magnetometerMagnitude: magnetometerMagnitude <= 0
          ? defaultMagnetometerMagnitude
          : magnetometerMagnitude,
      sampleDurationMs: sampleDurationMs <= 0
          ? defaultSampleDurationMs
          : sampleDurationMs,
      accelerationTriggerRatio: _validRatio(
        accelerationTriggerRatio,
        defaultAccelerationTriggerRatio,
      ),
      gyroscopeTriggerRatio: _validRatio(
        gyroscopeTriggerRatio,
        defaultGyroscopeTriggerRatio,
      ),
      magnetometerTriggerRatio: _validRatio(
        magnetometerTriggerRatio,
        defaultMagnetometerTriggerRatio,
      ),
      releaseRatio: _validRatio(releaseRatio, defaultReleaseRatio),
      cooldownMs: cooldownMs < 0 ? defaultCooldownMs : cooldownMs,
    );
  }

  static const defaultAccelerationMagnitude = 18.0;
  static const defaultGyroscopeMagnitude = 1.2;
  static const defaultMagnetometerMagnitude = 45.0;
  static const defaultSampleDurationMs = 1200;
  static const defaultAccelerationTriggerRatio = 0.9;
  static const defaultGyroscopeTriggerRatio = 0.9;
  static const defaultMagnetometerTriggerRatio = 0.9;
  static const defaultReleaseRatio = 0.55;
  static const defaultCooldownMs = 600;

  final ExerciseType exerciseType;
  final double accelerationMagnitude;
  final double gyroscopeMagnitude;
  final double magnetometerMagnitude;
  final int sampleDurationMs;
  final double accelerationTriggerRatio;
  final double gyroscopeTriggerRatio;
  final double magnetometerTriggerRatio;
  final double releaseRatio;
  final int cooldownMs;

  double get accelerationThreshold =>
      accelerationMagnitude * accelerationTriggerRatio;

  double get gyroscopeThreshold => gyroscopeMagnitude * gyroscopeTriggerRatio;

  double get magnetometerThreshold =>
      magnetometerMagnitude * magnetometerTriggerRatio;

  Map<String, dynamic> toJson() {
    return {
      'exerciseType': exerciseType.slug,
      'accelerationMagnitude': accelerationMagnitude,
      'gyroscopeMagnitude': gyroscopeMagnitude,
      'magnetometerMagnitude': magnetometerMagnitude,
      'sampleDurationMs': sampleDurationMs,
      'accelerationTriggerRatio': accelerationTriggerRatio,
      'gyroscopeTriggerRatio': gyroscopeTriggerRatio,
      'magnetometerTriggerRatio': magnetometerTriggerRatio,
      'releaseRatio': releaseRatio,
      'cooldownMs': cooldownMs,
    };
  }

  static WorkoutThreshold fromJson(Map<String, dynamic> json) {
    return WorkoutThreshold.normalized(
      exerciseType: ExerciseType.fromSlug(json['exerciseType'] as String?),
      accelerationMagnitude:
          (json['accelerationMagnitude'] as num?)?.toDouble() ??
          defaultAccelerationMagnitude,
      gyroscopeMagnitude:
          (json['gyroscopeMagnitude'] as num?)?.toDouble() ??
          defaultGyroscopeMagnitude,
      magnetometerMagnitude:
          (json['magnetometerMagnitude'] as num?)?.toDouble() ??
          defaultMagnetometerMagnitude,
      sampleDurationMs:
          (json['sampleDurationMs'] as num?)?.toInt() ??
          defaultSampleDurationMs,
      accelerationTriggerRatio:
          (json['accelerationTriggerRatio'] as num?)?.toDouble() ??
          defaultAccelerationTriggerRatio,
      gyroscopeTriggerRatio:
          (json['gyroscopeTriggerRatio'] as num?)?.toDouble() ??
          defaultGyroscopeTriggerRatio,
      magnetometerTriggerRatio:
          (json['magnetometerTriggerRatio'] as num?)?.toDouble() ??
          defaultMagnetometerTriggerRatio,
      releaseRatio:
          (json['releaseRatio'] as num?)?.toDouble() ?? defaultReleaseRatio,
      cooldownMs: (json['cooldownMs'] as num?)?.toInt() ?? defaultCooldownMs,
    );
  }

  static double _validRatio(double value, double fallback) {
    if (value <= 0 || value > 1) return fallback;
    return value;
  }
}
