import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_tracking_snapshot.dart';
import 'workout_history_view_model.dart';

class CardioMeasureState {
  const CardioMeasureState({
    required this.exerciseType,
    this.status = WorkoutTrackingStatus.idle,
    this.elapsed = Duration.zero,
    this.movingDuration = Duration.zero,
    this.distanceMeters = 0,
    this.caloriesKcal = 0,
    this.steps = 0,
    this.currentSpeedMetersPerSecond = 0,
    this.averageSpeedMetersPerSecond = 0,
    this.averagePaceSecondsPerKm = 0,
    this.cadenceSpm = 0,
    this.motionState = 'stationary',
    this.isAutoPaused = false,
    this.startedAt,
  });

  final ExerciseType exerciseType;
  final WorkoutTrackingStatus status;
  final Duration elapsed;
  final Duration movingDuration;
  final double distanceMeters;
  final double caloriesKcal;
  final int steps;
  final double currentSpeedMetersPerSecond;
  final double averageSpeedMetersPerSecond;
  final double averagePaceSecondsPerKm;
  final int cadenceSpm;
  final String motionState;
  final bool isAutoPaused;
  final DateTime? startedAt;

  bool get isMeasuring => status == WorkoutTrackingStatus.measuring;

  CardioMeasureState copyWith({
    WorkoutTrackingStatus? status,
    Duration? elapsed,
    Duration? movingDuration,
    double? distanceMeters,
    double? caloriesKcal,
    int? steps,
    double? currentSpeedMetersPerSecond,
    double? averageSpeedMetersPerSecond,
    double? averagePaceSecondsPerKm,
    int? cadenceSpm,
    String? motionState,
    bool? isAutoPaused,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return CardioMeasureState(
      exerciseType: exerciseType,
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      movingDuration: movingDuration ?? this.movingDuration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      steps: steps ?? this.steps,
      currentSpeedMetersPerSecond:
          currentSpeedMetersPerSecond ?? this.currentSpeedMetersPerSecond,
      averageSpeedMetersPerSecond:
          averageSpeedMetersPerSecond ?? this.averageSpeedMetersPerSecond,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      cadenceSpm: cadenceSpm ?? this.cadenceSpm,
      motionState: motionState ?? this.motionState,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    );
  }
}

final cardioMeasureProvider = StateNotifierProvider.autoDispose
    .family<CardioMeasureViewModel, CardioMeasureState, ExerciseType>(
      (ref, exerciseType) => CardioMeasureViewModel(ref, exerciseType),
    );

class CardioMeasureViewModel extends StateNotifier<CardioMeasureState> {
  CardioMeasureViewModel(this._ref, ExerciseType exerciseType)
    : super(CardioMeasureState(exerciseType: exerciseType)) {
    _ref.onDispose(_cancelSubscriptions);
    _subscribeTrackingState();
    _consumeCompletedSession();
  }

  final Ref _ref;
  StreamSubscription<WorkoutTrackingSnapshot>? _trackingSubscription;

  Future<void> start({required double weightKg}) async {
    if (state.isMeasuring) return;

    state = CardioMeasureState(
      exerciseType: state.exerciseType,
      status: WorkoutTrackingStatus.measuring,
      startedAt: DateTime.now(),
    );
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    try {
      await trackingService.startCardio(
        exerciseType: state.exerciseType,
        weightKg: weightKg,
      );
    } on PlatformException {
      state = CardioMeasureState(
        exerciseType: state.exerciseType,
        status: WorkoutTrackingStatus.failed,
      );
    }
  }

  Future<WorkoutSession?> stop() async {
    if (!state.isMeasuring) return null;

    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    final snapshot = await trackingService.stop();
    state = _stateFromSnapshot(
      snapshot,
    ).copyWith(status: WorkoutTrackingStatus.completed, clearStartedAt: true);
    return _saveSession(snapshot);
  }

  Future<void> reset() async {
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    await trackingService.reset();
    state = CardioMeasureState(exerciseType: state.exerciseType);
  }

  void _subscribeTrackingState() {
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    _trackingSubscription = trackingService.watch().listen((snapshot) {
      if (snapshot.exerciseType != state.exerciseType) return;
      state = _stateFromSnapshot(snapshot);
    });
    trackingService.getState().then((snapshot) {
      if (!mounted || snapshot.exerciseType != state.exerciseType) return;
      state = _stateFromSnapshot(snapshot);
    });
  }

  Future<void> _consumeCompletedSession() async {
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    final snapshot = await trackingService.consumeCompletedSession();
    if (snapshot == null || snapshot.exerciseType != state.exerciseType) return;
    await _saveSession(snapshot);
    if (!mounted) return;
    state = _stateFromSnapshot(
      snapshot,
    ).copyWith(status: WorkoutTrackingStatus.completed, clearStartedAt: true);
  }

  CardioMeasureState _stateFromSnapshot(WorkoutTrackingSnapshot snapshot) {
    return state.copyWith(
      status: snapshot.status,
      elapsed: Duration(seconds: snapshot.elapsedSeconds),
      movingDuration: Duration(seconds: snapshot.movingDurationSeconds),
      distanceMeters: snapshot.distanceMeters,
      caloriesKcal: snapshot.caloriesKcal,
      steps: snapshot.steps,
      currentSpeedMetersPerSecond: snapshot.currentSpeedMetersPerSecond,
      averageSpeedMetersPerSecond: snapshot.averageSpeedMetersPerSecond,
      averagePaceSecondsPerKm: snapshot.averagePaceSecondsPerKm,
      cadenceSpm: snapshot.cadenceSpm,
      motionState: snapshot.motionState,
      isAutoPaused: snapshot.isAutoPaused,
      startedAt: snapshot.startedAt,
      clearStartedAt: snapshot.startedAt == null,
    );
  }

  Future<WorkoutSession?> _saveSession(WorkoutTrackingSnapshot snapshot) async {
    if (snapshot.elapsedSeconds <= 0) return null;

    final endedAt = snapshot.endedAt ?? DateTime.now();
    final startedAt =
        snapshot.startedAt ??
        endedAt.subtract(Duration(seconds: snapshot.elapsedSeconds));
    final session = WorkoutSession(
      id: endedAt.microsecondsSinceEpoch.toString(),
      exerciseType: snapshot.exerciseType,
      count: 0,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: snapshot.distanceMeters,
      caloriesKcal: snapshot.caloriesKcal,
      steps: snapshot.steps,
      activeDurationSeconds: snapshot.activeDurationSeconds,
      movingDurationSeconds: snapshot.movingDurationSeconds,
      averageSpeedMetersPerSecond: snapshot.averageSpeedMetersPerSecond,
      averagePaceSecondsPerKm: snapshot.averagePaceSecondsPerKm,
    );
    await _ref.read(saveWorkoutSessionUseCaseProvider)(session);
    _invalidateHistory();
    return session;
  }

  void _invalidateHistory() {
    _ref.invalidate(workoutHistoryProvider);
    _ref.invalidate(todayWorkoutSummaryProvider);
    _ref.invalidate(dailyWorkoutSummariesProvider);
    _ref.invalidate(exerciseWorkoutSummariesProvider);
  }

  void _cancelSubscriptions() {
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
  }
}
