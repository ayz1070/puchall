import '../entities/workout_threshold.dart';

class WorkoutCounter {
  WorkoutCounter({
    required this.threshold,
    this.gyroscopeThreshold = 0,
    this.releaseRatio = WorkoutThreshold.defaultReleaseRatio,
    this.cooldown = const Duration(
      milliseconds: WorkoutThreshold.defaultCooldownMs,
    ),
  });

  factory WorkoutCounter.fromThreshold(WorkoutThreshold threshold) {
    return WorkoutCounter(
      threshold: threshold.accelerationThreshold,
      gyroscopeThreshold: threshold.gyroscopeThreshold,
      releaseRatio: threshold.releaseRatio,
      cooldown: Duration(milliseconds: threshold.cooldownMs),
    );
  }

  final double threshold;
  final double gyroscopeThreshold;
  final double releaseRatio;
  final Duration cooldown;
  bool _canCount = true;
  DateTime? _lastCountedAt;

  bool update(
    double accelerationMagnitude, {
    double gyroscopeMagnitude = 0,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final hasRecovered = accelerationMagnitude < threshold * releaseRatio;
    final passedAcceleration = accelerationMagnitude >= threshold;
    final passedGyroscope =
        gyroscopeThreshold <= 0 || gyroscopeMagnitude >= gyroscopeThreshold;
    final passedCooldown =
        _lastCountedAt == null || now.difference(_lastCountedAt!) >= cooldown;

    if (_canCount && passedCooldown && passedAcceleration && passedGyroscope) {
      _canCount = false;
      _lastCountedAt = now;
      return true;
    }

    if (!_canCount && hasRecovered) {
      _canCount = true;
    }

    return false;
  }

  void reset() {
    _canCount = true;
    _lastCountedAt = null;
  }
}
