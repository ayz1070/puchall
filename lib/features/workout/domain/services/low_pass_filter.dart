import 'dart:math' as math;

/// 시간 상수 기반 1차 저역통과(EMA) 필터.
///
/// 샘플 간격으로부터 계수를 매번 계산하므로 샘플링 레이트가 흔들리거나
/// (센서 배칭 등으로) 샘플이 몰려 들어와도 차단 주파수가 유지된다.
class LowPassFilter {
  LowPassFilter({required this.cutoffHz});

  final double cutoffHz;

  double? _value;
  int? _timestampMs;

  double? get value => _value;

  double filter(double raw, int timestampMs) {
    final previousValue = _value;
    final previousTimestampMs = _timestampMs;

    if (previousValue == null || previousTimestampMs == null) {
      _value = raw;
      _timestampMs = timestampMs;
      return raw;
    }

    final deltaSeconds = (timestampMs - previousTimestampMs) / 1000;
    if (deltaSeconds <= 0) {
      // 중복되거나 순서가 뒤집힌 타임스탬프는 무시한다.
      return previousValue;
    }

    final tau = 1 / (2 * math.pi * cutoffHz);
    final alpha = deltaSeconds / (tau + deltaSeconds);
    final filtered = previousValue + alpha * (raw - previousValue);

    _value = filtered;
    _timestampMs = timestampMs;
    return filtered;
  }

  void reset() {
    _value = null;
    _timestampMs = null;
  }
}
