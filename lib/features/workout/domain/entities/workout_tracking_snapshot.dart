import 'exercise_type.dart';

enum WorkoutTrackingStatus {
  idle,
  measuring,
  paused,
  completed,
  failed;

  static WorkoutTrackingStatus fromName(String? name) {
    return WorkoutTrackingStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => WorkoutTrackingStatus.idle,
    );
  }
}

class WorkoutTrackingSnapshot {
  const WorkoutTrackingSnapshot({
    required this.exerciseType,
    required this.status,
    required this.count,
    this.elapsedSeconds = 0,
    this.activeDurationSeconds = 0,
    this.movingDurationSeconds = 0,
    this.distanceMeters = 0,
    this.caloriesKcal = 0,
    this.steps = 0,
    this.currentSpeedMetersPerSecond = 0,
    this.averageSpeedMetersPerSecond = 0,
    this.averagePaceSecondsPerKm = 0,
    this.cadenceSpm = 0,
    this.motionState = 'stationary',
    this.isAutoPaused = false,
    this.gpsShadowDistanceMeters = 0,
    this.startedAt,
    this.endedAt,
  });

  final ExerciseType exerciseType;
  final WorkoutTrackingStatus status;
  final int count;
  final int elapsedSeconds;
  final int activeDurationSeconds;
  final int movingDurationSeconds;
  final double distanceMeters;
  final double caloriesKcal;
  final int steps;
  final double currentSpeedMetersPerSecond;
  final double averageSpeedMetersPerSecond;
  final double averagePaceSecondsPerKm;
  final int cadenceSpm;
  final String motionState;
  final bool isAutoPaused;
  final double gpsShadowDistanceMeters;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isMeasuring => status == WorkoutTrackingStatus.measuring;

  static WorkoutTrackingSnapshot fromMap(Map<dynamic, dynamic> map) {
    final startedAtMillis = (map['startedAtMillis'] as num?)?.toInt();
    final endedAtMillis = (map['endedAtMillis'] as num?)?.toInt();

    return WorkoutTrackingSnapshot(
      exerciseType: ExerciseType.fromSlug(map['exerciseType'] as String?),
      status: WorkoutTrackingStatus.fromName(map['status'] as String?),
      count: (map['count'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (map['elapsedSeconds'] as num?)?.toInt() ?? 0,
      activeDurationSeconds:
          (map['activeDurationSeconds'] as num?)?.toInt() ??
          (map['elapsedSeconds'] as num?)?.toInt() ??
          0,
      movingDurationSeconds:
          (map['movingDurationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      caloriesKcal: (map['caloriesKcal'] as num?)?.toDouble() ?? 0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      currentSpeedMetersPerSecond:
          (map['currentSpeedMetersPerSecond'] as num?)?.toDouble() ?? 0,
      averageSpeedMetersPerSecond:
          (map['averageSpeedMetersPerSecond'] as num?)?.toDouble() ?? 0,
      averagePaceSecondsPerKm:
          (map['averagePaceSecondsPerKm'] as num?)?.toDouble() ?? 0,
      cadenceSpm: (map['cadenceSpm'] as num?)?.toInt() ?? 0,
      motionState: map['motionState'] as String? ?? 'stationary',
      isAutoPaused: map['isAutoPaused'] as bool? ?? false,
      gpsShadowDistanceMeters:
          (map['gpsShadowDistanceMeters'] as num?)?.toDouble() ?? 0,
      startedAt: startedAtMillis == null || startedAtMillis <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedAtMillis),
      endedAt: endedAtMillis == null || endedAtMillis <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endedAtMillis),
    );
  }
}
