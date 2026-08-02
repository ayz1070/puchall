import '../entities/exercise_type.dart';
import '../entities/workout_threshold.dart';
import 'low_pass_filter.dart';
import 'rep_detector.dart';

/// 캘리브레이션 중 수집한 샘플 하나.
///
/// [verticalAcceleration]은 측정 시와 동일한 파이프라인(중력 제거 + 수직 투영)을
/// 거친 값이어야 한다. 그래야 여기서 뽑은 기준치가 실제 측정에 그대로 적용된다.
class WorkoutThresholdSample {
  const WorkoutThresholdSample({
    required this.timestampMs,
    required this.verticalAcceleration,
  });

  final int timestampMs;
  final double verticalAcceleration;
}

class WorkoutCalibrationResult {
  const WorkoutCalibrationResult({
    required this.threshold,
    required this.detectedRepCount,
    required this.medianAmplitude,
  });

  final WorkoutThreshold threshold;

  /// 산출된 기준치로 캡처 구간을 다시 재생했을 때 인식된 반복 횟수.
  final int detectedRepCount;
  final double medianAmplitude;
}

class WorkoutThresholdCalibrator {
  const WorkoutThresholdCalibrator();

  static const calibrationDurationMs = 30000;
  static const minimumDurationMs = 5000;

  /// 기준치를 신뢰하려면 최소한 이 횟수만큼은 반복이 관찰되어야 한다.
  static const minimumRepCount = 3;

  /// 사용자의 평균 반복 진폭 대비 기준치 비율.
  ///
  /// 절반으로 잡아 세트 후반에 힘이 빠져 진폭이 줄어도 계속 인식되게 한다.
  static const amplitudeRatio = 0.5;

  /// 반복을 찾아내기 위한 1차 탐색 임계값 비율 (신호 상위 진폭 대비).
  static const discoveryRatio = 0.35;

  WorkoutCalibrationResult? calibrate({
    required ExerciseType exerciseType,
    required List<WorkoutThresholdSample> samples,
    required int sampleDurationMs,
  }) {
    if (sampleDurationMs < minimumDurationMs || samples.length < 20) {
      return null;
    }

    final sorted = [...samples]
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    final discovered = _discoverReps(exerciseType, sorted);
    if (discovered.length < minimumRepCount) return null;

    final medianAmplitude = _median(
      discovered.map((rep) => rep.amplitude).toList(),
    );
    final medianHalfPeriodMs = _median(
      discovered.map((rep) => rep.halfPeriodMs.toDouble()).toList(),
    );
    final medianIntervalMs = _medianRepIntervalMs(discovered);

    final threshold = WorkoutThreshold.normalized(
      exerciseType: exerciseType,
      amplitudeThreshold: medianAmplitude * amplitudeRatio,
      minHalfPeriodMs: (medianHalfPeriodMs * 0.45).round(),
      maxHalfPeriodMs: (medianHalfPeriodMs * 2.5).round(),
      cooldownMs: (medianIntervalMs * 0.5).round(),
      sampleDurationMs: sampleDurationMs,
    );

    // 폐루프 검증: 산출된 기준치로 같은 구간을 다시 세어 본다.
    final detector = RepDetector(threshold.detectorConfig);
    for (final sample in sorted) {
      detector.update(sample.verticalAcceleration, sample.timestampMs);
    }

    return WorkoutCalibrationResult(
      threshold: WorkoutThreshold.normalized(
        exerciseType: threshold.exerciseType,
        amplitudeThreshold: threshold.amplitudeThreshold,
        minHalfPeriodMs: threshold.minHalfPeriodMs,
        maxHalfPeriodMs: threshold.maxHalfPeriodMs,
        cooldownMs: threshold.cooldownMs,
        lowPassCutoffHz: threshold.lowPassCutoffHz,
        sampleDurationMs: sampleDurationMs,
        calibratedRepCount: detector.count,
      ),
      detectedRepCount: detector.count,
      medianAmplitude: medianAmplitude,
    );
  }

  /// 기준치를 모르는 상태에서 반복을 찾기 위한 1차 통과.
  ///
  /// 신호 자체의 진폭 분포로 임시 임계값을 잡고, 반복 주기 제약은 최대한 느슨하게 둔다.
  List<DetectedRep> _discoverReps(
    ExerciseType exerciseType,
    List<WorkoutThresholdSample> samples,
  ) {
    final cutoffHz = RepDetectorConfig.defaultLowPassCutoffHz;
    final filter = LowPassFilter(cutoffHz: cutoffHz);
    final magnitudes = <double>[];
    for (final sample in samples) {
      final filtered = filter.filter(
        sample.verticalAcceleration,
        sample.timestampMs,
      );
      magnitudes.add(filtered.abs());
    }

    final highAmplitude = _percentile(magnitudes, 0.95);
    final discoveryThreshold =
        (highAmplitude * discoveryRatio) < WorkoutThreshold.minAmplitudeThreshold
        ? WorkoutThreshold.minAmplitudeThreshold
        : highAmplitude * discoveryRatio;

    final detector = RepDetector(
      RepDetectorConfig(
        amplitudeThreshold: discoveryThreshold,
        minHalfPeriodMs: WorkoutThreshold.minHalfPeriodLimitMs,
        maxHalfPeriodMs: WorkoutThreshold.maxHalfPeriodLimitMs,
        cooldownMs: 0,
        lowPassCutoffHz: cutoffHz,
      ),
    );

    final reps = <DetectedRep>[];
    for (final sample in samples) {
      final rep = detector.update(
        sample.verticalAcceleration,
        sample.timestampMs,
      );
      if (rep != null) reps.add(rep);
    }
    return reps;
  }

  double _medianRepIntervalMs(List<DetectedRep> reps) {
    if (reps.length < 2) {
      return reps.isEmpty ? 0 : reps.first.halfPeriodMs * 2;
    }

    final intervals = <double>[];
    for (var i = 1; i < reps.length; i++) {
      intervals.add(
        (reps[i].peakTimestampMs - reps[i - 1].peakTimestampMs).toDouble(),
      );
    }
    return _median(intervals);
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _percentile(List<double> values, double fraction) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * fraction).round();
    return sorted[index];
  }
}
