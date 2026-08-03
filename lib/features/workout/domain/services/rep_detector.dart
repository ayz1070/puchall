import 'low_pass_filter.dart';

/// 검출된 반복 1회.
class DetectedRep {
  const DetectedRep({
    required this.valleyTimestampMs,
    required this.peakTimestampMs,
    required this.valleyValue,
    required this.peakValue,
  });

  final int valleyTimestampMs;
  final int peakTimestampMs;
  final double valleyValue;
  final double peakValue;

  /// 골에서 마루까지 진폭의 절반. 기준치 산출에 쓰인다.
  double get amplitude => (peakValue - valleyValue) / 2;

  /// 골 → 마루에 걸린 시간. 반복 1회의 절반 주기에 해당한다.
  int get halfPeriodMs => peakTimestampMs - valleyTimestampMs;
}

/// 반복 검출 파라미터.
class RepDetectorConfig {
  const RepDetectorConfig({
    required this.amplitudeThreshold,
    required this.minHalfPeriodMs,
    required this.maxHalfPeriodMs,
    required this.cooldownMs,
    this.lowPassCutoffHz = defaultLowPassCutoffHz,
    this.verticalAccelerationScale = 1,
    this.releaseThresholdRatio = 0.45,
  });

  /// 반복 동작은 대략 0.2~1.5Hz이므로 그 위쪽 잡음만 걷어낸다.
  static const defaultLowPassCutoffHz = 2.5;

  /// 위/아래로 각각 넘어야 하는 수직 가속도 크기 (m/s²).
  final double amplitudeThreshold;

  /// 골 → 마루가 이보다 빠르면 반복이 아니라 흔들림으로 본다.
  final int minHalfPeriodMs;

  /// 골 → 마루가 이보다 느리면 반복 주기를 벗어난 것으로 보고 버린다.
  final int maxHalfPeriodMs;

  /// 직전 카운트로부터 최소 간격.
  final int cooldownMs;

  final double lowPassCutoffHz;

  /// 사용자별 측정에서 학습한 수직 가속도 방향 보정값.
  ///
  /// 기본값 1은 원본 신호, -1은 반전 신호다. 휴대폰 착용 방향이나 운동별 시작
  /// 위상 차이 때문에 실제 반복이 반대로 들어오는 경우 같은 상태 머신을 재사용한다.
  final double verticalAccelerationScale;

  /// 카운트 후 다음 반복을 받기 전에 0 근처로 복귀했다고 볼 임계값 비율.
  ///
  /// 진입 임계값보다 낮은 해제 임계값을 둬서 피크 근처 잔진동이 새 반복의 시작으로
  /// 바로 이어지는 것을 막는다.
  final double releaseThresholdRatio;
}

enum _Phase { waitingForValley, waitingForPeak, waitingForRecovery }

/// 중력이 제거된 수직 가속도 시계열에서 반복을 센다.
///
/// 입력은 "위쪽이 양수"인 수직 선형 가속도(m/s²)이며 정지 상태에서 0에 수렴한다.
/// 원시 가속도 magnitude와 달리 중력 오프셋(9.81)이 없고 방향 정보가 남아 있어,
/// 아래로 내려갔다가 위로 올라오는 한 쌍(골 → 마루)을 반복 1회로 판정할 수 있다.
///
/// 임계값을 한 번 넘을 때 세는 방식과 달리 ±[RepDetectorConfig.amplitudeThreshold]를
/// 모두 통과해야 하므로 0 근처의 잡음으로는 카운트가 발생하지 않는다.
class RepDetector {
  RepDetector(this.config)
    : _filter = LowPassFilter(cutoffHz: config.lowPassCutoffHz);

  final RepDetectorConfig config;
  final LowPassFilter _filter;

  _Phase _phase = _Phase.waitingForValley;
  int? _valleyTimestampMs;
  double _valleyValue = 0;
  int? _lastCountedAtMs;
  int _count = 0;

  int get count => _count;

  double get filteredValue => _filter.value ?? 0;

  double get _releaseThreshold =>
      config.amplitudeThreshold * config.releaseThresholdRatio.clamp(0.1, 0.9);

  /// 샘플 하나를 넣고, 이 샘플에서 반복이 완성되면 그 반복을 돌려준다.
  DetectedRep? update(double verticalAcceleration, int timestampMs) {
    final value = _filter.filter(
      verticalAcceleration * config.verticalAccelerationScale,
      timestampMs,
    );

    switch (_phase) {
      case _Phase.waitingForValley:
        if (value <= -config.amplitudeThreshold) {
          _phase = _Phase.waitingForPeak;
          _valleyTimestampMs = timestampMs;
          _valleyValue = value;
        }
        return null;

      case _Phase.waitingForPeak:
        if (value < _valleyValue) {
          _valleyValue = value;
        }

        final valleyTimestampMs = _valleyTimestampMs!;
        final elapsedMs = timestampMs - valleyTimestampMs;

        if (elapsedMs > config.maxHalfPeriodMs) {
          // 골까지 내려간 뒤 제때 올라오지 않았다. 반복으로 보지 않는다.
          _phase = _Phase.waitingForRecovery;
          return null;
        }

        if (value < config.amplitudeThreshold) return null;

        _phase = _Phase.waitingForRecovery;

        if (elapsedMs < config.minHalfPeriodMs) return null;

        final lastCountedAtMs = _lastCountedAtMs;
        if (lastCountedAtMs != null &&
            timestampMs - lastCountedAtMs < config.cooldownMs) {
          return null;
        }

        _lastCountedAtMs = timestampMs;
        _count += 1;

        return DetectedRep(
          valleyTimestampMs: valleyTimestampMs,
          peakTimestampMs: timestampMs,
          valleyValue: _valleyValue,
          peakValue: value,
        );

      case _Phase.waitingForRecovery:
        if (value.abs() <= _releaseThreshold) {
          _phase = _Phase.waitingForValley;
          _valleyTimestampMs = null;
          _valleyValue = 0;
        }
        return null;
    }
  }

  void reset() {
    _filter.reset();
    _phase = _Phase.waitingForValley;
    _valleyTimestampMs = null;
    _valleyValue = 0;
    _lastCountedAtMs = null;
    _count = 0;
  }
}
