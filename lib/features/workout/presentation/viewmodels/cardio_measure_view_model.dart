import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/services/cardio_calorie_calculator.dart';
import 'workout_history_view_model.dart';

class CardioMeasureState {
  const CardioMeasureState({
    required this.exerciseType,
    this.status = CardioMeasureStatus.idle,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.distanceMeters = 0,
    this.caloriesKcal = 0,
  });

  final ExerciseType exerciseType;
  final CardioMeasureStatus status;
  final DateTime? startedAt;
  final Duration elapsed;
  final double distanceMeters;
  final double caloriesKcal;

  bool get isMeasuring => status == CardioMeasureStatus.measuring;

  CardioMeasureState copyWith({
    CardioMeasureStatus? status,
    DateTime? startedAt,
    Duration? elapsed,
    double? distanceMeters,
    double? caloriesKcal,
    bool clearStartedAt = false,
  }) {
    return CardioMeasureState(
      exerciseType: exerciseType,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      elapsed: elapsed ?? this.elapsed,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
    );
  }
}

enum CardioMeasureStatus { idle, measuring, completed }

final cardioMeasureProvider = StateNotifierProvider.autoDispose
    .family<CardioMeasureViewModel, CardioMeasureState, ExerciseType>(
      (ref, exerciseType) => CardioMeasureViewModel(ref, exerciseType),
    );

class CardioMeasureViewModel extends StateNotifier<CardioMeasureState> {
  CardioMeasureViewModel(this._ref, ExerciseType exerciseType)
    : super(CardioMeasureState(exerciseType: exerciseType)) {
    _ref.onDispose(_cancelTimer);
  }

  final Ref _ref;
  Timer? _timer;
  double _weightKg = 70;

  void start({required double weightKg}) {
    if (state.isMeasuring) return;

    _weightKg = weightKg;
    state = CardioMeasureState(
      exerciseType: state.exerciseType,
      status: CardioMeasureStatus.measuring,
      startedAt: DateTime.now(),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<WorkoutSession?> stop() async {
    if (!state.isMeasuring) return null;

    _cancelTimer();
    final endedAt = DateTime.now();
    final startedAt = state.startedAt ?? endedAt;
    final elapsed = endedAt.difference(startedAt);
    final distanceMeters = _distanceFor(elapsed);
    final caloriesKcal = const CardioCalorieCalculator().calculate(
      exerciseType: state.exerciseType,
      weightKg: _weightKg,
      duration: elapsed,
      distanceMeters: distanceMeters,
    );

    state = state.copyWith(
      status: CardioMeasureStatus.completed,
      elapsed: elapsed,
      distanceMeters: distanceMeters,
      caloriesKcal: caloriesKcal,
      clearStartedAt: true,
    );

    if (elapsed.inSeconds <= 0) return null;

    final session = WorkoutSession(
      id: endedAt.microsecondsSinceEpoch.toString(),
      exerciseType: state.exerciseType,
      count: 0,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters,
      caloriesKcal: caloriesKcal,
    );
    await _ref.read(saveWorkoutSessionUseCaseProvider)(session);
    _invalidateHistory();
    return session;
  }

  void reset() {
    _cancelTimer();
    state = CardioMeasureState(exerciseType: state.exerciseType);
  }

  void _tick() {
    final startedAt = state.startedAt;
    if (startedAt == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    final distanceMeters = _distanceFor(elapsed);
    final caloriesKcal = const CardioCalorieCalculator().calculate(
      exerciseType: state.exerciseType,
      weightKg: _weightKg,
      duration: elapsed,
      distanceMeters: distanceMeters,
    );
    state = state.copyWith(
      elapsed: elapsed,
      distanceMeters: distanceMeters,
      caloriesKcal: caloriesKcal,
    );
  }

  double _distanceFor(Duration elapsed) {
    final metersPerSecond = switch (state.exerciseType) {
      ExerciseType.running => 2.5,
      ExerciseType.walking => 1.25,
      ExerciseType.pushUp || ExerciseType.pullUp => 0.0,
    };
    return elapsed.inSeconds * metersPerSecond;
  }

  void _invalidateHistory() {
    _ref.invalidate(workoutHistoryProvider);
    _ref.invalidate(todayWorkoutSummaryProvider);
    _ref.invalidate(dailyWorkoutSummariesProvider);
    _ref.invalidate(exerciseWorkoutSummariesProvider);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
