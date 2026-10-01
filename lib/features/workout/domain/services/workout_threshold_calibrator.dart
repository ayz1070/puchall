import 'dart:math' as math;

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
    required this.signalQuality,
  });

  final WorkoutThreshold threshold;

  /// 산출된 기준치로 캡처 구간을 다시 재생했을 때 인식된 반복 횟수.
  final int detectedRepCount;
  final double medianAmplitude;

  /// 0~1 사이의 신호 품질 점수. 진폭/간격 안정성과 폐루프 카운트 일치도를 함께 본다.
  final double signalQuality;
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

    final candidate = _bestCandidate(sorted);
    if (candidate == null) return null;

    final medianAmplitude = candidate.medianAmplitude;
    final medianHalfPeriodMs = candidate.medianHalfPeriodMs;
    final medianIntervalMs = candidate.medianIntervalMs;
    final timingPolicy = _timingPolicyFor(exerciseType);

    final threshold = WorkoutThreshold.normalized(
      exerciseType: exerciseType,
      amplitudeThreshold: medianAmplitude * amplitudeRatio,
      minHalfPeriodMs: timingPolicy.minHalfPeriodMs(medianHalfPeriodMs),
      maxHalfPeriodMs: timingPolicy.maxHalfPeriodMs(medianHalfPeriodMs),
      cooldownMs: timingPolicy.cooldownMs(medianIntervalMs),
      verticalAccelerationScale: candidate.verticalAccelerationScale,
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
        verticalAccelerationScale: threshold.verticalAccelerationScale,
        sampleDurationMs: sampleDurationMs,
        calibratedRepCount: detector.count,
      ),
      detectedRepCount: detector.count,
      medianAmplitude: medianAmplitude,
      signalQuality: candidate.signalQuality(detector.count),
    );
  }

  /// 기준치를 모르는 상태에서 반복을 찾기 위한 1차 통과.
  ///
  /// 신호 자체의 진폭 분포로 임시 임계값을 잡고, 반복 주기 제약은 최대한 느슨하게 둔다.
  List<DetectedRep> _discoverReps(
    List<WorkoutThresholdSample> samples,
    double verticalAccelerationScale,
  ) {
    final cutoffHz = RepDetectorConfig.defaultLowPassCutoffHz;
    final filter = LowPassFilter(cutoffHz: cutoffHz);
    final magnitudes = <double>[];
    for (final sample in samples) {
      final filtered = filter.filter(
        sample.verticalAcceleration * verticalAccelerationScale,
        sample.timestampMs,
      );
      magnitudes.add(filtered.abs());
    }

    final highAmplitude = _percentile(magnitudes, 0.95);
    final discoveryThreshold =
        (highAmplitude * discoveryRatio) <
            WorkoutThreshold.minAmplitudeThreshold
        ? WorkoutThreshold.minAmplitudeThreshold
        : highAmplitude * discoveryRatio;

    final detector = RepDetector(
      RepDetectorConfig(
        amplitudeThreshold: discoveryThreshold,
        minHalfPeriodMs: WorkoutThreshold.minHalfPeriodLimitMs,
        maxHalfPeriodMs: WorkoutThreshold.maxHalfPeriodLimitMs,
        cooldownMs: 0,
        lowPassCutoffHz: cutoffHz,
        verticalAccelerationScale: verticalAccelerationScale,
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

  _CalibrationCandidate? _bestCandidate(List<WorkoutThresholdSample> samples) {
    final candidates = [
      _candidateFor(samples, 1),
      _candidateFor(samples, -1),
    ].whereType<_CalibrationCandidate>().toList();

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final countComparison = b.reps.length.compareTo(a.reps.length);
      if (countComparison != 0) return countComparison;
      final firstPeakComparison = a.firstPeakTimestampMs.compareTo(
        b.firstPeakTimestampMs,
      );
      if (firstPeakComparison != 0) return firstPeakComparison;
      return b.medianAmplitude.compareTo(a.medianAmplitude);
    });
    return candidates.first;
  }

  _CalibrationCandidate? _candidateFor(
    List<WorkoutThresholdSample> samples,
    double verticalAccelerationScale,
  ) {
    final reps = _discoverReps(samples, verticalAccelerationScale);
    if (reps.length < minimumRepCount) return null;

    return _CalibrationCandidate(
      verticalAccelerationScale: verticalAccelerationScale,
      reps: reps,
      medianAmplitude: _median(reps.map((rep) => rep.amplitude).toList()),
      medianHalfPeriodMs: _median(
        reps.map((rep) => rep.halfPeriodMs.toDouble()).toList(),
      ),
      medianIntervalMs: _medianRepIntervalMs(reps),
      amplitudeStdDev: _standardDeviation(
        reps.map((rep) => rep.amplitude).toList(),
      ),
      intervalStdDev: _standardDeviation(_repIntervalsMs(reps)),
    );
  }

  double _medianRepIntervalMs(List<DetectedRep> reps) {
    final intervals = _repIntervalsMs(reps);
    if (intervals.isEmpty) {
      return reps.isEmpty ? 0 : reps.first.halfPeriodMs * 2;
    }
    return _median(intervals);
  }

  List<double> _repIntervalsMs(List<DetectedRep> reps) {
    if (reps.length < 2) return const [];

    final intervals = <double>[];
    for (var i = 1; i < reps.length; i++) {
      intervals.add(
        (reps[i].peakTimestampMs - reps[i - 1].peakTimestampMs).toDouble(),
      );
    }
    return intervals;
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

  double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values
            .map((value) {
              final diff = value - mean;
              return diff * diff;
            })
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  _TimingPolicy _timingPolicyFor(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.pushUp => const _TimingPolicy(
        minHalfPeriodRatio: 0.5,
        minHalfPeriodFloorMs: 300,
        maxHalfPeriodRatio: 2.75,
        maxHalfPeriodCeilingMs: 4000,
        cooldownRatio: 0.6,
        cooldownFloorMs: 800,
      ),
      _ => const _TimingPolicy(
        minHalfPeriodRatio: 0.45,
        minHalfPeriodFloorMs: WorkoutThreshold.minHalfPeriodLimitMs,
        maxHalfPeriodRatio: 2.5,
        maxHalfPeriodCeilingMs: WorkoutThreshold.maxHalfPeriodLimitMs,
        cooldownRatio: 0.5,
        cooldownFloorMs: 0,
      ),
    };
  }
}

class _CalibrationCandidate {
  const _CalibrationCandidate({
    required this.verticalAccelerationScale,
    required this.reps,
    required this.medianAmplitude,
    required this.medianHalfPeriodMs,
    required this.medianIntervalMs,
    required this.amplitudeStdDev,
    required this.intervalStdDev,
  });

  final double verticalAccelerationScale;
  final List<DetectedRep> reps;
  final double medianAmplitude;
  final double medianHalfPeriodMs;
  final double medianIntervalMs;
  final double amplitudeStdDev;
  final double intervalStdDev;

  int get firstPeakTimestampMs => reps.first.peakTimestampMs;

  double signalQuality(int detectedRepCount) {
    final amplitudeStability = _stability(medianAmplitude, amplitudeStdDev);
    final intervalStability = _stability(medianIntervalMs, intervalStdDev);
    final expectedCount = reps.length;
    final closedLoopRatio = expectedCount <= 0
        ? 0.0
        : (detectedRepCount <= expectedCount
                  ? detectedRepCount / expectedCount
                  : expectedCount / detectedRepCount)
              .clamp(0.0, 1.0);

    return (amplitudeStability * 0.4 +
            intervalStability * 0.4 +
            closedLoopRatio * 0.2)
        .clamp(0.0, 1.0);
  }

  double _stability(double median, double stdDev) {
    if (median <= 0) return 0;
    return (1 - (stdDev / median)).clamp(0.0, 1.0);
  }
}

class _TimingPolicy {
  const _TimingPolicy({
    required this.minHalfPeriodRatio,
    required this.minHalfPeriodFloorMs,
    required this.maxHalfPeriodRatio,
    required this.maxHalfPeriodCeilingMs,
    required this.cooldownRatio,
    required this.cooldownFloorMs,
  });

  final double minHalfPeriodRatio;
  final int minHalfPeriodFloorMs;
  final double maxHalfPeriodRatio;
  final int maxHalfPeriodCeilingMs;
  final double cooldownRatio;
  final int cooldownFloorMs;

  int minHalfPeriodMs(double medianHalfPeriodMs) {
    final candidate = (medianHalfPeriodMs * minHalfPeriodRatio).round();
    return candidate < minHalfPeriodFloorMs ? minHalfPeriodFloorMs : candidate;
  }

  int maxHalfPeriodMs(double medianHalfPeriodMs) {
    final candidate = (medianHalfPeriodMs * maxHalfPeriodRatio).round();
    return candidate > maxHalfPeriodCeilingMs
        ? maxHalfPeriodCeilingMs
        : candidate;
  }

  int cooldownMs(double medianIntervalMs) {
    final candidate = (medianIntervalMs * cooldownRatio).round();
    return candidate < cooldownFloorMs ? cooldownFloorMs : candidate;
  }
}
