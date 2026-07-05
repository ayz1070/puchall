import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/services/workout_counter.dart';

void main() {
  group('WorkoutCounter', () {
    test('counts once when magnitude crosses threshold', () {
      final counter = WorkoutCounter(threshold: 10);

      expect(counter.update(9.9), isFalse);
      expect(counter.update(10), isTrue);
    });

    test('does not count repeatedly while magnitude stays above threshold', () {
      final counter = WorkoutCounter(threshold: 10);

      expect(counter.update(11), isTrue);
      expect(counter.update(12), isFalse);
      expect(counter.update(10.5), isFalse);
    });

    test('counts again after magnitude falls below release value', () {
      final counter = WorkoutCounter(threshold: 10, releaseRatio: 0.6);

      expect(counter.update(11), isTrue);
      expect(counter.update(6), isFalse);
      expect(counter.update(5.9), isFalse);
      expect(counter.update(10.1), isTrue);
    });

    test('reset allows counting again', () {
      final counter = WorkoutCounter(threshold: 10);

      expect(counter.update(11), isTrue);
      expect(counter.update(12), isFalse);

      counter.reset();

      expect(counter.update(12), isTrue);
    });
  });
}
