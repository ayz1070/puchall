import 'dart:math' as math;

class SensorVector {
  const SensorVector({required this.x, required this.y, required this.z});

  const SensorVector.zero() : this(x: 0, y: 0, z: 0);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class SensorSnapshot {
  const SensorSnapshot({
    this.accelerometer = const SensorVector.zero(),
    this.gyroscope = const SensorVector.zero(),
    this.magnetometer = const SensorVector.zero(),
  });

  final SensorVector accelerometer;
  final SensorVector gyroscope;
  final SensorVector magnetometer;
}
