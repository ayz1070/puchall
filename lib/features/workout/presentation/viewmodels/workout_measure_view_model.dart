import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/sensor_snapshot.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/services/workout_counter.dart';
import 'workout_history_view_model.dart';

class WorkoutMeasureState {
  const WorkoutMeasureState({
    required this.exerciseType,
    this.snapshot = const SensorSnapshot(),
    this.count = 0,
    this.isMeasuring = false,
    this.threshold = WorkoutThreshold.defaultAccelerationMagnitude,
    this.sessionStartedAt,
  });

  final ExerciseType exerciseType;
  final SensorSnapshot snapshot;
  final int count;
  final bool isMeasuring;
  final double threshold;
  final DateTime? sessionStartedAt;

  WorkoutMeasureState copyWith({
    SensorSnapshot? snapshot,
    int? count,
    bool? isMeasuring,
    double? threshold,
    DateTime? sessionStartedAt,
    bool clearSessionStartedAt = false,
  }) {
    return WorkoutMeasureState(
      exerciseType: exerciseType,
      snapshot: snapshot ?? this.snapshot,
      count: count ?? this.count,
      isMeasuring: isMeasuring ?? this.isMeasuring,
      threshold: threshold ?? this.threshold,
      sessionStartedAt: clearSessionStartedAt
          ? null
          : sessionStartedAt ?? this.sessionStartedAt,
    );
  }
}

final workoutMeasureProvider = StateNotifierProvider.autoDispose
    .family<WorkoutMeasureViewModel, WorkoutMeasureState, ExerciseType>(
      (ref, exerciseType) => WorkoutMeasureViewModel(ref, exerciseType),
    );

class WorkoutMeasureViewModel extends StateNotifier<WorkoutMeasureState> {
  WorkoutMeasureViewModel(this._ref, ExerciseType exerciseType)
    : super(WorkoutMeasureState(exerciseType: exerciseType)) {
    _ref.onDispose(_cancelSubscriptions);
    _loadThreshold(exerciseType);
  }

  final Ref _ref;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  WorkoutCounter? _counter;

  Future<void> _loadThreshold(ExerciseType exerciseType) async {
    final getThreshold = _ref.read(getWorkoutThresholdUseCaseProvider);
    final threshold = await getThreshold(exerciseType);
    state = state.copyWith(
      threshold: threshold?.accelerationMagnitude ?? state.threshold,
    );
  }

  void start() {
    if (state.isMeasuring) return;

    _counter = WorkoutCounter(threshold: state.threshold);
    state = state.copyWith(
      count: 0,
      isMeasuring: true,
      sessionStartedAt: DateTime.now(),
    );

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final vector = SensorVector(x: event.x, y: event.y, z: event.z);
      final snapshot = SensorSnapshot(
        accelerometer: vector,
        gyroscope: state.snapshot.gyroscope,
        magnetometer: state.snapshot.magnetometer,
      );
      state = state.copyWith(snapshot: snapshot);
      _updateCount(vector.magnitude);
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

  Future<int?> stop() async {
    if (!state.isMeasuring) return null;

    _cancelSubscriptions();
    final startedAt = state.sessionStartedAt ?? DateTime.now();
    final count = state.count;

    state = state.copyWith(isMeasuring: false, clearSessionStartedAt: true);

    if (count <= 0) return count;

    final saveSession = _ref.read(saveWorkoutSessionUseCaseProvider);
    await saveSession(
      WorkoutSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        exerciseType: state.exerciseType,
        count: count,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      ),
    );
    _ref.invalidate(workoutHistoryProvider);
    _ref.invalidate(todayWorkoutSummaryProvider);
    _ref.invalidate(dailyWorkoutSummariesProvider);
    _ref.invalidate(exerciseWorkoutSummariesProvider);
    return count;
  }

  void reset() {
    state = state.copyWith(count: 0);
    _counter?.reset();
  }

  void _updateCount(double accelerationMagnitude) {
    if (!state.isMeasuring) return;

    if (_counter?.update(accelerationMagnitude) ?? false) {
      state = state.copyWith(count: state.count + 1);
    }
  }

  void _cancelSubscriptions() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
    _counter = null;
  }
}
