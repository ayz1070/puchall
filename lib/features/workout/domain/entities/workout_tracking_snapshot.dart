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
    this.startedAt,
    this.endedAt,
  });

  final ExerciseType exerciseType;
  final WorkoutTrackingStatus status;
  final int count;
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
      startedAt: startedAtMillis == null || startedAtMillis <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedAtMillis),
      endedAt: endedAtMillis == null || endedAtMillis <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endedAtMillis),
    );
  }
}
