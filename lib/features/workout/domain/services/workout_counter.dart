class WorkoutCounter {
  WorkoutCounter({required this.threshold, this.releaseRatio = 0.6});

  final double threshold;
  final double releaseRatio;
  bool _canCount = true;

  bool update(double accelerationMagnitude) {
    if (_canCount && accelerationMagnitude >= threshold) {
      _canCount = false;
      return true;
    }

    if (!_canCount && accelerationMagnitude < threshold * releaseRatio) {
      _canCount = true;
    }

    return false;
  }

  void reset() {
    _canCount = true;
  }
}
