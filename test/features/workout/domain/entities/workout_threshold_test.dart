import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/entities/workout_threshold.dart';

void main() {
  group('WorkoutThreshold', () {
    test('운동 종류별로 다른 기본값을 준다', () {
      final pushUp = WorkoutThreshold.defaultsFor(ExerciseType.pushUp);
      final pullUp = WorkoutThreshold.defaultsFor(ExerciseType.pullUp);

      // 풀업은 반복이 느리므로 쿨다운과 주기 상한이 더 길어야 한다.
      expect(pullUp.cooldownMs, greaterThan(pushUp.cooldownMs));
      expect(pullUp.maxHalfPeriodMs, greaterThan(pushUp.maxHalfPeriodMs));
    });

    test('진폭 기준치를 잡음 수준 아래로 내리지 않는다', () {
      final threshold = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pushUp,
        amplitudeThreshold: 0.001,
        minHalfPeriodMs: 300,
        maxHalfPeriodMs: 2000,
        cooldownMs: 700,
      );

      expect(
        threshold.amplitudeThreshold,
        WorkoutThreshold.minAmplitudeThreshold,
      );
    });

    test('주기 범위가 뒤집혀 있으면 기본값으로 보정한다', () {
      final threshold = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pushUp,
        amplitudeThreshold: 1,
        minHalfPeriodMs: 2000,
        maxHalfPeriodMs: 500,
        cooldownMs: 700,
      );

      expect(threshold.maxHalfPeriodMs, greaterThan(threshold.minHalfPeriodMs));
    });

    test('저장했다가 그대로 복원한다', () {
      final threshold = WorkoutThreshold.normalized(
        exerciseType: ExerciseType.pullUp,
        amplitudeThreshold: 1.4,
        minHalfPeriodMs: 500,
        maxHalfPeriodMs: 3000,
        cooldownMs: 1100,
        verticalAccelerationScale: -1,
        sampleDurationMs: 30000,
        calibratedRepCount: 9,
      );

      final restored = WorkoutThreshold.tryFromJson(threshold.toJson());

      expect(restored, isNotNull);
      expect(restored!.exerciseType, ExerciseType.pullUp);
      expect(restored.amplitudeThreshold, closeTo(1.4, 0.001));
      expect(restored.minHalfPeriodMs, 500);
      expect(restored.maxHalfPeriodMs, 3000);
      expect(restored.cooldownMs, 1100);
      expect(restored.verticalAccelerationScale, -1);
      expect(restored.calibratedRepCount, 9);
    });

    test('구버전 기준치는 복원하지 않아 재측정을 유도한다', () {
      // v1은 중력이 포함된 가속도 magnitude 기준이라 그대로 쓰면 오작동한다.
      const legacyJson = {
        'exerciseType': 'push-up',
        'accelerationMagnitude': 18.0,
        'gyroscopeMagnitude': 1.2,
        'magnetometerMagnitude': 45.0,
        'releaseRatio': 0.55,
        'cooldownMs': 600,
      };

      expect(WorkoutThreshold.tryFromJson(legacyJson), isNull);

      // v2는 방향 보정값이 없어 풀업처럼 반대 위상으로 들어온 신호를 놓칠 수 있다.
      expect(
        WorkoutThreshold.tryFromJson(const {
          'schemaVersion': 2,
          'exerciseType': 'pull-up',
          'amplitudeThreshold': 0.5,
        }),
        isNull,
      );
    });

    test('스키마 버전이 없으면 복원하지 않는다', () {
      expect(
        WorkoutThreshold.tryFromJson(const {'amplitudeThreshold': 1.0}),
        isNull,
      );
    });
  });
}
