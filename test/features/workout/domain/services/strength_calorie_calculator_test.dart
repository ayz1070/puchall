import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/services/strength_calorie_calculator.dart';

void main() {
  const calculator = StrengthCalorieCalculator();

  test(
    'calculates push-up calories from weight, reps, and active duration',
    () {
      final calories = calculator.calculate(
        exerciseType: ExerciseType.pushUp,
        weightKg: 70,
        count: 20,
        duration: const Duration(minutes: 5),
      );

      expect(calories, closeTo(5.04, 0.01));
    },
  );

  test('caps active duration by measured session duration', () {
    final calories = calculator.calculate(
      exerciseType: ExerciseType.pullUp,
      weightKg: 70,
      count: 20,
      duration: const Duration(seconds: 30),
    );

    expect(calories, closeTo(3.68, 0.01));
  });

  test('returns zero for cardio exercise types', () {
    final calories = calculator.calculate(
      exerciseType: ExerciseType.running,
      weightKg: 70,
      count: 20,
      duration: const Duration(minutes: 5),
    );

    expect(calories, 0);
  });
}
