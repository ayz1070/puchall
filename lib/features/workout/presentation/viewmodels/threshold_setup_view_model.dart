import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/sensor_snapshot.dart';
import '../../domain/entities/workout_threshold.dart';
import 'workout_measure_view_model.dart';

class ThresholdSetupState {
  const ThresholdSetupState({
    required this.exerciseType,
    this.snapshot = const SensorSnapshot(),
    this.isCapturing = false,
    this.maxAccelerationMagnitude = 0,
    this.maxGyroscopeMagnitude = 0,
    this.maxMagnetometerMagnitude = 0,
    this.sampleDurationMs = 0,
    this.savedThreshold,
  });

  final ExerciseType exerciseType;
  final SensorSnapshot snapshot;
  final bool isCapturing;
  final double maxAccelerationMagnitude;
  final double maxGyroscopeMagnitude;
  final double maxMagnetometerMagnitude;
  final int sampleDurationMs;
  final WorkoutThreshold? savedThreshold;

  WorkoutThreshold? get previewThreshold {
    if (maxAccelerationMagnitude <= 0 ||
        maxGyroscopeMagnitude <= 0 ||
        maxMagnetometerMagnitude <= 0) {
      return savedThreshold;
    }

    return WorkoutThreshold.normalized(
      exerciseType: exerciseType,
      accelerationMagnitude: maxAccelerationMagnitude,
      gyroscopeMagnitude: maxGyroscopeMagnitude,
      magnetometerMagnitude: maxMagnetometerMagnitude,
      sampleDurationMs: sampleDurationMs,
    );
  }

  ThresholdSetupState copyWith({
    SensorSnapshot? snapshot,
    bool? isCapturing,
    double? maxAccelerationMagnitude,
    double? maxGyroscopeMagnitude,
    double? maxMagnetometerMagnitude,
    int? sampleDurationMs,
    WorkoutThreshold? savedThreshold,
  }) {
    return ThresholdSetupState(
      exerciseType: exerciseType,
      snapshot: snapshot ?? this.snapshot,
      isCapturing: isCapturing ?? this.isCapturing,
      maxAccelerationMagnitude:
          maxAccelerationMagnitude ?? this.maxAccelerationMagnitude,
      maxGyroscopeMagnitude:
          maxGyroscopeMagnitude ?? this.maxGyroscopeMagnitude,
      maxMagnetometerMagnitude:
          maxMagnetometerMagnitude ?? this.maxMagnetometerMagnitude,
      sampleDurationMs: sampleDurationMs ?? this.sampleDurationMs,
      savedThreshold: savedThreshold ?? this.savedThreshold,
    );
  }
}

final thresholdSetupProvider = StateNotifierProvider.autoDispose
    .family<ThresholdSetupViewModel, ThresholdSetupState, ExerciseType>(
      (ref, exerciseType) => ThresholdSetupViewModel(ref, exerciseType),
    );

class ThresholdSetupViewModel extends StateNotifier<ThresholdSetupState> {
  ThresholdSetupViewModel(this._ref, ExerciseType exerciseType)
    : super(ThresholdSetupState(exerciseType: exerciseType)) {
    _ref.onDispose(_cancelSubscription);
    _loadSavedThreshold(exerciseType);
  }

  final Ref _ref;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  DateTime? _captureStartedAt;

  Future<void> _loadSavedThreshold(ExerciseType exerciseType) async {
    final getThreshold = _ref.read(getWorkoutThresholdUseCaseProvider);
    final threshold = await getThreshold(exerciseType);
    if (threshold == null) return;
    state = state.copyWith(savedThreshold: threshold);
  }

  void startCapture() {
    if (state.isCapturing) return;

    _captureStartedAt = DateTime.now();
    state = state.copyWith(
      isCapturing: true,
      maxAccelerationMagnitude: 0,
      maxGyroscopeMagnitude: 0,
      maxMagnetometerMagnitude: 0,
      sampleDurationMs: 0,
    );

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final vector = SensorVector(x: event.x, y: event.y, z: event.z);
      final maxValue = vector.magnitude > state.maxAccelerationMagnitude
          ? vector.magnitude
          : state.maxAccelerationMagnitude;

      state = state.copyWith(
        snapshot: SensorSnapshot(
          accelerometer: vector,
          gyroscope: state.snapshot.gyroscope,
          magnetometer: state.snapshot.magnetometer,
        ),
        maxAccelerationMagnitude: maxValue,
      );
    });

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      final vector = SensorVector(x: event.x, y: event.y, z: event.z);
      final maxValue = vector.magnitude > state.maxGyroscopeMagnitude
          ? vector.magnitude
          : state.maxGyroscopeMagnitude;

      state = state.copyWith(
        snapshot: SensorSnapshot(
          accelerometer: state.snapshot.accelerometer,
          gyroscope: vector,
          magnetometer: state.snapshot.magnetometer,
        ),
        maxGyroscopeMagnitude: maxValue,
      );
    });

    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      final vector = SensorVector(x: event.x, y: event.y, z: event.z);
      final maxValue = vector.magnitude > state.maxMagnetometerMagnitude
          ? vector.magnitude
          : state.maxMagnetometerMagnitude;

      state = state.copyWith(
        snapshot: SensorSnapshot(
          accelerometer: state.snapshot.accelerometer,
          gyroscope: state.snapshot.gyroscope,
          magnetometer: vector,
        ),
        maxMagnetometerMagnitude: maxValue,
      );
    });
  }

  Future<WorkoutThreshold?> stopAndSave() async {
    if (!state.isCapturing) return null;
    _cancelSubscription();

    final accelerationMagnitude = state.maxAccelerationMagnitude;
    final gyroscopeMagnitude = state.maxGyroscopeMagnitude;
    final magnetometerMagnitude = state.maxMagnetometerMagnitude;
    final sampleDurationMs = _captureStartedAt == null
        ? WorkoutThreshold.defaultSampleDurationMs
        : DateTime.now().difference(_captureStartedAt!).inMilliseconds;
    _captureStartedAt = null;

    if (accelerationMagnitude <= 0 ||
        gyroscopeMagnitude <= 0 ||
        magnetometerMagnitude <= 0) {
      state = state.copyWith(isCapturing: false);
      return null;
    }

    final threshold = WorkoutThreshold.normalized(
      exerciseType: state.exerciseType,
      accelerationMagnitude: accelerationMagnitude,
      gyroscopeMagnitude: gyroscopeMagnitude,
      magnetometerMagnitude: magnetometerMagnitude,
      sampleDurationMs: sampleDurationMs,
    );
    final saveThreshold = _ref.read(saveWorkoutThresholdUseCaseProvider);
    await saveThreshold(threshold);

    state = state.copyWith(
      isCapturing: false,
      sampleDurationMs: sampleDurationMs,
      savedThreshold: threshold,
    );
    _ref.invalidate(workoutMeasureProvider(state.exerciseType));
    return threshold;
  }

  void _cancelSubscription() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
  }
}
