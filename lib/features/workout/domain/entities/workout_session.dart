import 'exercise_type.dart';

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.exerciseType,
    required this.count,
    required this.startedAt,
    required this.endedAt,
    this.distanceMeters = 0,
    this.caloriesKcal = 0,
  });

  final String id;
  final ExerciseType exerciseType;
  final int count;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final double caloriesKcal;

  Duration get duration => endedAt.difference(startedAt);
  int get durationSeconds => duration.inSeconds;

  String get dateKey {
    final year = startedAt.year.toString().padLeft(4, '0');
    final month = startedAt.month.toString().padLeft(2, '0');
    final day = startedAt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseType': exerciseType.slug,
      'count': count,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'distanceMeters': distanceMeters,
      'caloriesKcal': caloriesKcal,
    };
  }

  static WorkoutSession fromJson(Map<String, dynamic> json) {
    final startedAt =
        DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now();

    return WorkoutSession(
      id: json['id'] as String? ?? startedAt.microsecondsSinceEpoch.toString(),
      exerciseType: ExerciseType.fromSlug(json['exerciseType'] as String?),
      count: (json['count'] as num?)?.toInt() ?? 0,
      startedAt: startedAt,
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ?? startedAt,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      caloriesKcal: (json['caloriesKcal'] as num?)?.toDouble() ?? 0,
    );
  }
}
