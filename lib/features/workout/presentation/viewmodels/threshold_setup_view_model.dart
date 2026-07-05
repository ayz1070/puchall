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
    this.savedThreshold,
  });

  final ExerciseType exerciseType;
  final SensorSnapshot snapshot;
  final bool isCapturing;
  final double maxAccelerationMagnitude;
  final double? savedThreshold;

  ThresholdSetupState copyWith({
    SensorSnapshot? snapshot,
    bool? isCapturing,
    double? maxAccelerationMagnitude,
    double? savedThreshold,
  }) {
    return ThresholdSetupState(
      exerciseType: exerciseType,
      snapshot: snapshot ?? this.snapshot,
      isCapturing: isCapturing ?? this.isCapturing,
      maxAccelerationMagnitude:
          maxAccelerationMagnitude ?? this.maxAccelerationMagnitude,
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

  Future<void> _loadSavedThreshold(ExerciseType exerciseType) async {
    final getThreshold = _ref.read(getWorkoutThresholdUseCaseProvider);
    final threshold = await getThreshold(exerciseType);
    state = state.copyWith(savedThreshold: threshold?.accelerationMagnitude);
  }

  void startCapture() {
    if (state.isCapturing) return;

    state = state.copyWith(isCapturing: true, maxAccelerationMagnitude: 0);

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
      state = state.copyWith(
        snapshot: SensorSnapshot(
          accelerometer: state.snapshot.accelerometer,
          gyroscope: SensorVector(x: event.x, y: event.y, z: event.z),
          magnetometer: state.snapshot.magnetometer,
        ),
      );
    });

    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      state = state.copyWith(
        snapshot: SensorSnapshot(
          accelerometer: state.snapshot.accelerometer,
          gyroscope: state.snapshot.gyroscope,
          magnetometer: SensorVector(x: event.x, y: event.y, z: event.z),
        ),
      );
    });
  }

  Future<double?> stopAndSave() async {
    if (!state.isCapturing) return null;
    _cancelSubscription();

    final thresholdValue = state.maxAccelerationMagnitude;
    if (thresholdValue <= 0) {
      state = state.copyWith(isCapturing: false);
      return null;
    }

    final saveThreshold = _ref.read(saveWorkoutThresholdUseCaseProvider);
    await saveThreshold(
      WorkoutThreshold(
        exerciseType: state.exerciseType,
        accelerationMagnitude: thresholdValue,
      ),
    );

    state = state.copyWith(isCapturing: false, savedThreshold: thresholdValue);
    _ref.invalidate(workoutMeasureProvider(state.exerciseType));
    return thresholdValue;
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
