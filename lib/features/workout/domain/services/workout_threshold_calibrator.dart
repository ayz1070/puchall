import '../entities/exercise_type.dart';
import '../entities/workout_threshold.dart';

class WorkoutThresholdSample {
  const WorkoutThresholdSample({
    required this.elapsedMs,
    required this.accelerationMagnitude,
    required this.gyroscopeMagnitude,
    required this.magnetometerMagnitude,
  });

  final int elapsedMs;
  final double accelerationMagnitude;
  final double gyroscopeMagnitude;
  final double magnetometerMagnitude;
}

class WorkoutThresholdCalibrator {
  const WorkoutThresholdCalibrator();

  static const calibrationDurationMs = 30000;
  static const minimumDurationMs = 5000;
  static const baselineWindowMs = 1000;
  static const peakCount = 5;
  static const thresholdRatioFromBaseline = 0.85;
  static const minimumMovementDelta = 0.05;

  WorkoutThreshold? calibrate({
    required ExerciseType exerciseType,
    required List<WorkoutThresholdSample> samples,
    required int sampleDurationMs,
  }) {
    if (sampleDurationMs < minimumDurationMs || samples.length < 6) {
      return null;
    }

    final sortedSamples = [...samples]
      ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
    final baseline = _findBaseline(sortedSamples);
    final accelerationPeak = _representativePeak(
      sortedSamples.map((sample) => sample.accelerationMagnitude).toList(),
    );
    final gyroscopePeak = _representativePeak(
      sortedSamples.map((sample) => sample.gyroscopeMagnitude).toList(),
    );
    final magnetometerPeak = _representativePeak(
      sortedSamples.map((sample) => sample.magnetometerMagnitude).toList(),
    );

    if (accelerationPeak - baseline.accelerationMagnitude <
            minimumMovementDelta ||
        gyroscopePeak - baseline.gyroscopeMagnitude < minimumMovementDelta ||
        magnetometerPeak - baseline.magnetometerMagnitude <
            minimumMovementDelta) {
      return null;
    }

    return WorkoutThreshold.normalized(
      exerciseType: exerciseType,
      accelerationMagnitude: _thresholdValue(
        baseline.accelerationMagnitude,
        accelerationPeak,
      ),
      gyroscopeMagnitude: _thresholdValue(
        baseline.gyroscopeMagnitude,
        gyroscopePeak,
      ),
      magnetometerMagnitude: _thresholdValue(
        baseline.magnetometerMagnitude,
        magnetometerPeak,
      ),
      sampleDurationMs: sampleDurationMs,
      accelerationTriggerRatio: 1,
      gyroscopeTriggerRatio: 1,
      magnetometerTriggerRatio: 1,
    );
  }

  WorkoutThresholdSample _findBaseline(List<WorkoutThresholdSample> samples) {
    var bestWindow = samples;
    var bestScore = double.infinity;

    for (final startSample in samples) {
      final windowEndMs = startSample.elapsedMs + baselineWindowMs;
      final window = samples
          .where(
            (sample) =>
                sample.elapsedMs >= startSample.elapsedMs &&
                sample.elapsedMs <= windowEndMs,
          )
          .toList();
      if (window.length < 3) continue;

      final score = _volatility(window);
      if (score < bestScore) {
        bestScore = score;
        bestWindow = window;
      }
    }

    return WorkoutThresholdSample(
      elapsedMs: bestWindow.first.elapsedMs,
      accelerationMagnitude: _average(
        bestWindow.map((sample) => sample.accelerationMagnitude),
      ),
      gyroscopeMagnitude: _average(
        bestWindow.map((sample) => sample.gyroscopeMagnitude),
      ),
      magnetometerMagnitude: _average(
        bestWindow.map((sample) => sample.magnetometerMagnitude),
      ),
    );
  }

  double _volatility(List<WorkoutThresholdSample> samples) {
    var total = 0.0;

    for (var i = 1; i < samples.length; i++) {
      final previous = samples[i - 1];
      final current = samples[i];
      total +=
          (current.accelerationMagnitude - previous.accelerationMagnitude)
              .abs() +
          (current.gyroscopeMagnitude - previous.gyroscopeMagnitude).abs() +
          (current.magnetometerMagnitude - previous.magnetometerMagnitude)
              .abs();
    }

    return total / (samples.length - 1);
  }

  double _representativePeak(List<double> values) {
    final sortedDescending = [...values]..sort((a, b) => b.compareTo(a));
    final peakValues = sortedDescending.take(peakCount).toList()..sort();
    return peakValues[peakValues.length ~/ 2];
  }

  double _thresholdValue(double baseline, double peak) {
    return baseline + (peak - baseline) * thresholdRatioFromBaseline;
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.reduce((sum, value) => sum + value) / list.length;
  }
}
