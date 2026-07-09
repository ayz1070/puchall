import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/sensor_snapshot.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/services/workout_threshold_calibrator.dart';
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
    this.remainingSeconds =
        WorkoutThresholdCalibrator.calibrationDurationMs ~/
        Duration.millisecondsPerSecond,
    this.savedThreshold,
  });

  final ExerciseType exerciseType;
  final SensorSnapshot snapshot;
  final bool isCapturing;
  final double maxAccelerationMagnitude;
  final double maxGyroscopeMagnitude;
  final double maxMagnetometerMagnitude;
  final int sampleDurationMs;
  final int remainingSeconds;
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
    int? remainingSeconds,
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
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
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
    _ref.onDispose(_cancelCapture);
    _loadSavedThreshold(exerciseType);
  }

  final Ref _ref;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  Timer? _countdownTimer;
  DateTime? _captureStartedAt;
  bool _isSaving = false;
  final List<WorkoutThresholdSample> _samples = [];
  final WorkoutThresholdCalibrator _calibrator =
      const WorkoutThresholdCalibrator();

  Future<void> _loadSavedThreshold(ExerciseType exerciseType) async {
    final getThreshold = _ref.read(getWorkoutThresholdUseCaseProvider);
    final threshold = await getThreshold(exerciseType);
    if (threshold == null) return;
    state = state.copyWith(savedThreshold: threshold);
  }

  void startCapture() {
    if (state.isCapturing) return;

    _captureStartedAt = DateTime.now();
    _samples.clear();
    state = state.copyWith(
      isCapturing: true,
      maxAccelerationMagnitude: 0,
      maxGyroscopeMagnitude: 0,
      maxMagnetometerMagnitude: 0,
      sampleDurationMs: 0,
      remainingSeconds:
          WorkoutThresholdCalibrator.calibrationDurationMs ~/
          Duration.millisecondsPerSecond,
    );
    _startCountdown();

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
      _recordSample();
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
      _recordSample();
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
      _recordSample();
    });
  }

  Future<WorkoutThreshold?> stopAndSave() async {
    if (!state.isCapturing || _isSaving) return null;
    _isSaving = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cancelSubscription();

    final sampleDurationMs = _captureStartedAt == null
        ? WorkoutThreshold.defaultSampleDurationMs
        : DateTime.now().difference(_captureStartedAt!).inMilliseconds;
    _captureStartedAt = null;

    final threshold = _calibrator.calibrate(
      exerciseType: state.exerciseType,
      samples: _samples,
      sampleDurationMs: sampleDurationMs,
    );

    if (threshold == null) {
      state = state.copyWith(
        isCapturing: false,
        sampleDurationMs: sampleDurationMs,
      );
      _isSaving = false;
      return null;
    }

    final saveThreshold = _ref.read(saveWorkoutThresholdUseCaseProvider);
    await saveThreshold(threshold);

    state = state.copyWith(
      isCapturing: false,
      sampleDurationMs: sampleDurationMs,
      savedThreshold: threshold,
    );
    _ref.invalidate(workoutMeasureProvider(state.exerciseType));
    _isSaving = false;
    return threshold;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isCapturing) {
        timer.cancel();
        return;
      }

      final startedAt = _captureStartedAt;
      if (startedAt == null) return;

      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final remainingMs =
          WorkoutThresholdCalibrator.calibrationDurationMs - elapsedMs;
      final remainingSeconds = (remainingMs / Duration.millisecondsPerSecond)
          .ceil()
          .clamp(
            0,
            WorkoutThresholdCalibrator.calibrationDurationMs ~/
                Duration.millisecondsPerSecond,
          );
      state = state.copyWith(remainingSeconds: remainingSeconds);

      if (remainingMs <= 0) {
        timer.cancel();
        stopAndSave();
      }
    });
  }

  void _recordSample() {
    final startedAt = _captureStartedAt;
    if (startedAt == null || !state.isCapturing) return;

    _samples.add(
      WorkoutThresholdSample(
        elapsedMs: DateTime.now().difference(startedAt).inMilliseconds,
        accelerationMagnitude: state.snapshot.accelerometer.magnitude,
        gyroscopeMagnitude: state.snapshot.gyroscope.magnitude,
        magnetometerMagnitude: state.snapshot.magnetometer.magnitude,
      ),
    );
  }

  void _cancelSubscription() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
  }

  void _cancelCapture() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cancelSubscription();
  }
}
