import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../profile/di/profile_dependencies.dart';
import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/entities/workout_tracking_snapshot.dart';
import '../../domain/services/strength_calorie_calculator.dart';
import 'workout_history_view_model.dart';

class WorkoutMeasureState {
  const WorkoutMeasureState({
    required this.exerciseType,
    this.count = 0,
    this.status = WorkoutTrackingStatus.idle,
    this.threshold = WorkoutThreshold.defaultAccelerationMagnitude,
    this.thresholdConfig,
    this.sessionStartedAt,
  });

  final ExerciseType exerciseType;
  final int count;
  final WorkoutTrackingStatus status;
  final double threshold;
  final WorkoutThreshold? thresholdConfig;
  final DateTime? sessionStartedAt;

  bool get isMeasuring => status == WorkoutTrackingStatus.measuring;

  WorkoutMeasureState copyWith({
    int? count,
    WorkoutTrackingStatus? status,
    double? threshold,
    WorkoutThreshold? thresholdConfig,
    DateTime? sessionStartedAt,
    bool clearSessionStartedAt = false,
  }) {
    return WorkoutMeasureState(
      exerciseType: exerciseType,
      count: count ?? this.count,
      status: status ?? this.status,
      threshold: threshold ?? this.threshold,
      thresholdConfig: thresholdConfig ?? this.thresholdConfig,
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
    _subscribeTrackingState();
    _consumeCompletedSession();
  }

  final Ref _ref;
  StreamSubscription<WorkoutTrackingSnapshot>? _trackingSubscription;

  Future<void> _loadThreshold(ExerciseType exerciseType) async {
    final getThreshold = _ref.read(getWorkoutThresholdUseCaseProvider);
    final threshold = await getThreshold(exerciseType);
    state = state.copyWith(
      threshold: threshold?.accelerationThreshold ?? state.threshold,
      thresholdConfig: threshold,
    );
  }

  Future<void> start() async {
    if (state.isMeasuring) return;

    final thresholdConfig =
        state.thresholdConfig ??
        WorkoutThreshold.normalized(
          exerciseType: state.exerciseType,
          accelerationMagnitude: state.threshold,
        );
    state = state.copyWith(
      count: 0,
      status: WorkoutTrackingStatus.measuring,
      threshold: thresholdConfig.accelerationThreshold,
      thresholdConfig: thresholdConfig,
      sessionStartedAt: DateTime.now(),
    );
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    final profile = await _ref.read(getUserProfileUseCaseProvider)();
    await trackingService.start(
      exerciseType: state.exerciseType,
      threshold: thresholdConfig,
      weightKg: profile.weightKg,
    );
  }

  Future<int?> stop() async {
    if (!state.isMeasuring) return null;

    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    final snapshot = await trackingService.stop();
    final count = snapshot.count;

    state = state.copyWith(
      count: count,
      status: WorkoutTrackingStatus.completed,
      clearSessionStartedAt: true,
    );

    await _saveSession(snapshot);
    return count;
  }

  Future<void> reset() async {
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    await trackingService.reset();
    state = state.copyWith(count: 0);
  }

  void _subscribeTrackingState() {
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    _trackingSubscription = trackingService.watch().listen((snapshot) {
      if (snapshot.exerciseType != state.exerciseType) return;
      state = state.copyWith(
        count: snapshot.count,
        status: snapshot.status,
        sessionStartedAt: snapshot.startedAt,
        clearSessionStartedAt: snapshot.startedAt == null,
      );
    });
    trackingService.getState().then((snapshot) {
      if (!mounted || snapshot.exerciseType != state.exerciseType) return;
      state = state.copyWith(
        count: snapshot.count,
        status: snapshot.status,
        sessionStartedAt: snapshot.startedAt,
        clearSessionStartedAt: snapshot.startedAt == null,
      );
    });
  }

  Future<void> _consumeCompletedSession() async {
    final trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    final snapshot = await trackingService.consumeCompletedSession();
    if (snapshot == null) return;
    await _saveSession(snapshot);
    if (snapshot.exerciseType != state.exerciseType) return;
    if (!mounted) return;
    state = state.copyWith(
      count: snapshot.count,
      status: WorkoutTrackingStatus.completed,
      clearSessionStartedAt: true,
    );
  }

  Future<void> _saveSession(WorkoutTrackingSnapshot snapshot) async {
    if (snapshot.count <= 0) return;

    final startedAt = snapshot.startedAt ?? state.sessionStartedAt;
    final endedAt = snapshot.endedAt ?? DateTime.now();
    final duration = endedAt.difference(startedAt ?? endedAt);
    final profile = await _ref.read(getUserProfileUseCaseProvider)();
    final caloriesKcal = const StrengthCalorieCalculator().calculate(
      exerciseType: snapshot.exerciseType,
      weightKg: profile.weightKg,
      count: snapshot.count,
      duration: duration,
    );
    final saveSession = _ref.read(saveWorkoutSessionUseCaseProvider);
    await saveSession(
      WorkoutSession(
        id: endedAt.microsecondsSinceEpoch.toString(),
        exerciseType: snapshot.exerciseType,
        count: snapshot.count,
        startedAt: startedAt ?? endedAt,
        endedAt: endedAt,
        caloriesKcal: caloriesKcal,
        activeDurationSeconds: duration.inSeconds,
      ),
    );
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
