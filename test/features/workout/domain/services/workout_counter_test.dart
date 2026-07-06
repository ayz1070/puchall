import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/services/workout_counter.dart';

void main() {
  group('WorkoutCounter', () {
    test('counts once when magnitude crosses threshold', () {
      final counter = WorkoutCounter(threshold: 10, cooldown: Duration.zero);

      expect(counter.update(9.9), isFalse);
      expect(counter.update(10), isTrue);
    });

    test('does not count repeatedly while magnitude stays above threshold', () {
      final counter = WorkoutCounter(threshold: 10, cooldown: Duration.zero);

      expect(counter.update(11), isTrue);
      expect(counter.update(12), isFalse);
      expect(counter.update(10.5), isFalse);
    });

    test('counts again after magnitude falls below release value', () {
      final counter = WorkoutCounter(
        threshold: 10,
        releaseRatio: 0.6,
        cooldown: Duration.zero,
      );

      expect(counter.update(11), isTrue);
      expect(counter.update(6), isFalse);
      expect(counter.update(5.9), isFalse);
      expect(counter.update(10.1), isTrue);
    });

    test('reset allows counting again', () {
      final counter = WorkoutCounter(threshold: 10, cooldown: Duration.zero);

      expect(counter.update(11), isTrue);
      expect(counter.update(12), isFalse);

      counter.reset();

      expect(counter.update(12), isTrue);
    });

    test('requires gyroscope threshold when configured', () {
      final counter = WorkoutCounter(
        threshold: 10,
        gyroscopeThreshold: 2,
        cooldown: Duration.zero,
      );

      expect(counter.update(11, gyroscopeMagnitude: 1.9), isFalse);
      expect(counter.update(11, gyroscopeMagnitude: 2), isTrue);
    });

    test('blocks repeated count during cooldown', () {
      final counter = WorkoutCounter(
        threshold: 10,
        releaseRatio: 0.6,
        cooldown: const Duration(milliseconds: 500),
      );
      final startedAt = DateTime(2026, 7, 6, 10);

      expect(counter.update(11, timestamp: startedAt), isTrue);
      expect(
        counter.update(
          5,
          timestamp: startedAt.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
      );
      expect(
        counter.update(
          11,
          timestamp: startedAt.add(const Duration(milliseconds: 300)),
        ),
        isFalse,
      );
      expect(
        counter.update(
          11,
          timestamp: startedAt.add(const Duration(milliseconds: 600)),
        ),
        isTrue,
      );
    });
  });
}
