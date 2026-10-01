import 'package:flutter_test/flutter_test.dart';
import 'package:puchall/features/workout/domain/entities/exercise_type.dart';
import 'package:puchall/features/workout/domain/services/workout_threshold_calibrator.dart';
import 'features/workout/domain/services/signal_fixtures.dart';

void main() {
  test('direction ambiguity check', () {
    const calibrator = WorkoutThresholdCalibrator();
    // 실제 방향(scale=1)의 정상 풀업 신호.
    final samples = repSignal(
      repCount: 8,
      periodSeconds: 2.2,
      displacementAmplitudeMeters: 0.1,
      noiseAmplitude: 0.08,
    );

    final result = calibrator.calibrate(
      exerciseType: ExerciseType.pullUp,
      samples: samples,
      sampleDurationMs: 18000,
    );
    print('scale=${result?.threshold.verticalAccelerationScale} detected=${result?.detectedRepCount}');
  });
}
