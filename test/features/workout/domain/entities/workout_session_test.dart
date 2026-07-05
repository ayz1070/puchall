import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_session.dart';

void main() {
  group('WorkoutSession', () {
    test('returns date key from startedAt', () {
      final session = _session(
        startedAt: DateTime(2026, 7, 5, 10, 30),
        endedAt: DateTime(2026, 7, 5, 10, 31),
      );

      expect(session.dateKey, '2026-07-05');
    });

    test('returns duration between start and end', () {
      final session = _session(
        startedAt: DateTime(2026, 7, 5, 10, 30),
        endedAt: DateTime(2026, 7, 5, 10, 31, 15),
      );

      expect(session.duration, const Duration(minutes: 1, seconds: 15));
    });
  });
}

WorkoutSession _session({
  required DateTime startedAt,
  required DateTime endedAt,
}) {
  return WorkoutSession(
    id: 'session',
    exerciseType: ExerciseType.pushUp,
    count: 10,
    startedAt: startedAt,
    endedAt: endedAt,
  );
}
