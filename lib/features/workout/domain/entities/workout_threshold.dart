import 'exercise_type.dart';
import '../services/rep_detector.dart';

/// 반복 카운팅 기준치.
///
/// v3부터 사용자별 수직 가속도 방향 보정값을 함께 저장한다.
/// v1은 중력이 포함된 원시 가속도 magnitude를 기준으로 삼았고, v2는 방향 보정값이
/// 없어 풀업처럼 반대 위상으로 들어온 신호를 놓칠 수 있다. 구버전 기준치는
/// [tryFromJson]이 null을 돌려주고, 사용자는 기준치를 다시 측정하게 된다.
class WorkoutThreshold {
  const WorkoutThreshold({
    required this.exerciseType,
    required this.amplitudeThreshold,
    required this.minHalfPeriodMs,
    required this.maxHalfPeriodMs,
    required this.cooldownMs,
    this.lowPassCutoffHz = RepDetectorConfig.defaultLowPassCutoffHz,
    this.verticalAccelerationScale = 1,
    this.sampleDurationMs = 0,
    this.calibratedRepCount = 0,
  });

  /// 기준치를 측정하지 않은 사용자를 위한 출발점.
  ///
  /// 실기기 데이터로 검증된 값이 아니라 동작 물리에서 추정한 값이므로,
  /// 온보딩에서 기준치를 측정하면 사용자별 값으로 대체된다.
  factory WorkoutThreshold.defaultsFor(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.pullUp => const WorkoutThreshold(
        exerciseType: ExerciseType.pullUp,
        amplitudeThreshold: 1.0,
        minHalfPeriodMs: 400,
        maxHalfPeriodMs: 3500,
        cooldownMs: 1200,
        verticalAccelerationScale: 1,
      ),
      _ => WorkoutThreshold(
        exerciseType: exerciseType,
        amplitudeThreshold: 0.8,
        minHalfPeriodMs: 250,
        maxHalfPeriodMs: 2500,
        cooldownMs: 800,
        verticalAccelerationScale: 1,
      ),
    };
  }

  factory WorkoutThreshold.normalized({
    required ExerciseType exerciseType,
    required double amplitudeThreshold,
    required int minHalfPeriodMs,
    required int maxHalfPeriodMs,
    required int cooldownMs,
    double lowPassCutoffHz = RepDetectorConfig.defaultLowPassCutoffHz,
    double verticalAccelerationScale = 1,
    int sampleDurationMs = 0,
    int calibratedRepCount = 0,
  }) {
    final fallback = WorkoutThreshold.defaultsFor(exerciseType);
    final safeMinHalfPeriodMs = minHalfPeriodMs < minHalfPeriodLimitMs
        ? fallback.minHalfPeriodMs
        : minHalfPeriodMs;
    final safeMaxHalfPeriodMs = maxHalfPeriodMs <= safeMinHalfPeriodMs
        ? fallback.maxHalfPeriodMs
        : (maxHalfPeriodMs > maxHalfPeriodLimitMs
              ? maxHalfPeriodLimitMs
              : maxHalfPeriodMs);

    return WorkoutThreshold(
      exerciseType: exerciseType,
      amplitudeThreshold: amplitudeThreshold < minAmplitudeThreshold
          ? minAmplitudeThreshold
          : amplitudeThreshold,
      minHalfPeriodMs: safeMinHalfPeriodMs,
      // min이 max를 넘지 않도록 최종 보정한다.
      maxHalfPeriodMs: safeMaxHalfPeriodMs <= safeMinHalfPeriodMs
          ? safeMinHalfPeriodMs + minHalfPeriodLimitMs
          : safeMaxHalfPeriodMs,
      cooldownMs: cooldownMs < 0 ? fallback.cooldownMs : cooldownMs,
      lowPassCutoffHz: lowPassCutoffHz <= 0
          ? RepDetectorConfig.defaultLowPassCutoffHz
          : lowPassCutoffHz,
      verticalAccelerationScale: verticalAccelerationScale < 0 ? -1 : 1,
      sampleDurationMs: sampleDurationMs < 0 ? 0 : sampleDurationMs,
      calibratedRepCount: calibratedRepCount < 0 ? 0 : calibratedRepCount,
    );
  }

  static const schemaVersion = 3;

  /// 센서 잡음 수준까지 기준치가 내려가지 않도록 하는 하한.
  static const minAmplitudeThreshold = 0.15;
  static const minHalfPeriodLimitMs = 120;
  static const maxHalfPeriodLimitMs = 6000;

  final ExerciseType exerciseType;

  /// 위/아래로 각각 넘어야 하는 수직 가속도 크기 (m/s²).
  final double amplitudeThreshold;
  final int minHalfPeriodMs;
  final int maxHalfPeriodMs;
  final int cooldownMs;
  final double lowPassCutoffHz;
  final double verticalAccelerationScale;

  /// 기준치를 측정할 때 사용한 캡처 길이 (표시용).
  final int sampleDurationMs;

  /// 이 기준치로 캡처 구간을 다시 재생했을 때 인식된 반복 횟수 (표시용).
  final int calibratedRepCount;

  RepDetectorConfig get detectorConfig {
    return RepDetectorConfig(
      amplitudeThreshold: amplitudeThreshold,
      minHalfPeriodMs: minHalfPeriodMs,
      maxHalfPeriodMs: maxHalfPeriodMs,
      cooldownMs: cooldownMs,
      lowPassCutoffHz: lowPassCutoffHz,
      verticalAccelerationScale: verticalAccelerationScale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'exerciseType': exerciseType.slug,
      'amplitudeThreshold': amplitudeThreshold,
      'minHalfPeriodMs': minHalfPeriodMs,
      'maxHalfPeriodMs': maxHalfPeriodMs,
      'cooldownMs': cooldownMs,
      'lowPassCutoffHz': lowPassCutoffHz,
      'verticalAccelerationScale': verticalAccelerationScale,
      'sampleDurationMs': sampleDurationMs,
      'calibratedRepCount': calibratedRepCount,
    };
  }

  /// v3 기준치만 복원한다. 구버전이거나 형식이 깨졌으면 null을 돌려준다.
  static WorkoutThreshold? tryFromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt();
    if (version != schemaVersion) return null;

    final amplitudeThreshold = (json['amplitudeThreshold'] as num?)?.toDouble();
    if (amplitudeThreshold == null) return null;

    final exerciseType = ExerciseType.fromSlug(json['exerciseType'] as String?);
    final fallback = WorkoutThreshold.defaultsFor(exerciseType);

    return WorkoutThreshold.normalized(
      exerciseType: exerciseType,
      amplitudeThreshold: amplitudeThreshold,
      minHalfPeriodMs:
          (json['minHalfPeriodMs'] as num?)?.toInt() ??
          fallback.minHalfPeriodMs,
      maxHalfPeriodMs:
          (json['maxHalfPeriodMs'] as num?)?.toInt() ??
          fallback.maxHalfPeriodMs,
      cooldownMs: (json['cooldownMs'] as num?)?.toInt() ?? fallback.cooldownMs,
      lowPassCutoffHz:
          (json['lowPassCutoffHz'] as num?)?.toDouble() ??
          RepDetectorConfig.defaultLowPassCutoffHz,
      verticalAccelerationScale:
          (json['verticalAccelerationScale'] as num?)?.toDouble() ?? 1,
      sampleDurationMs: (json['sampleDurationMs'] as num?)?.toInt() ?? 0,
      calibratedRepCount: (json['calibratedRepCount'] as num?)?.toInt() ?? 0,
    );
  }
}
