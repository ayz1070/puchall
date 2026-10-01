import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/data_sources/workout_tracking_service_data_source.dart';
import '../../di/workout_dependencies.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/services/rep_detector.dart';
import '../../domain/services/workout_threshold_calibrator.dart';
import 'workout_measure_view_model.dart';

class ThresholdSetupState {
  const ThresholdSetupState({
    required this.exerciseType,
    this.isCapturing = false,
    this.remainingSeconds = _totalSeconds,
    this.verticalAcceleration = 0,
    this.liveRepCount = 0,
    this.sampleCount = 0,
    this.savedThreshold,
    this.lastResult,
    this.failureMessage,
  });

  static const _totalSeconds =
      WorkoutThresholdCalibrator.calibrationDurationMs ~/
      Duration.millisecondsPerSecond;

  final ExerciseType exerciseType;
  final bool isCapturing;
  final int remainingSeconds;

  /// 지금 들어오는 수직 가속도 (m/s², 위쪽이 양수).
  final double verticalAcceleration;

  /// 측정 중 임시 기준치로 센 횟수. 사용자가 인식 여부를 즉시 확인할 수 있게 한다.
  final int liveRepCount;
  final int sampleCount;

  final WorkoutThreshold? savedThreshold;

  /// 마지막으로 산출한 기준치와 그 기준치로 다시 세어 본 결과.
  final WorkoutCalibrationResult? lastResult;
  final String? failureMessage;

  bool get hasSavedThreshold => savedThreshold != null;

  /// 화면에 표시할 임계값. 측정 전에는 저장값(없으면 기본값)을 쓴다.
  double get displayThreshold =>
      (savedThreshold ?? WorkoutThreshold.defaultsFor(exerciseType))
          .amplitudeThreshold;

  ThresholdSetupState copyWith({
    bool? isCapturing,
    int? remainingSeconds,
    double? verticalAcceleration,
    int? liveRepCount,
    int? sampleCount,
    WorkoutThreshold? savedThreshold,
    WorkoutCalibrationResult? lastResult,
    String? failureMessage,
    bool clearFailureMessage = false,
    bool clearLastResult = false,
  }) {
    return ThresholdSetupState(
      exerciseType: exerciseType,
      isCapturing: isCapturing ?? this.isCapturing,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      verticalAcceleration: verticalAcceleration ?? this.verticalAcceleration,
      liveRepCount: liveRepCount ?? this.liveRepCount,
      sampleCount: sampleCount ?? this.sampleCount,
      savedThreshold: savedThreshold ?? this.savedThreshold,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
      failureMessage: clearFailureMessage
          ? null
          : failureMessage ?? this.failureMessage,
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
    // dispose 콜백 안에서는 Ref를 쓸 수 없으므로 미리 잡아 둔다.
    _trackingService = _ref.read(workoutTrackingServiceDataSourceProvider);
    _ref.onDispose(_cancelCapture);
    _loadSavedThreshold(exerciseType);
  }

  final Ref _ref;
  late final WorkoutTrackingServiceDataSource _trackingService;
  final WorkoutThresholdCalibrator _calibrator =
      const WorkoutThresholdCalibrator();
  final List<WorkoutThresholdSample> _samples = [];

  StreamSubscription<WorkoutThresholdSample>? _sampleSubscription;
  Timer? _countdownTimer;
  DateTime? _captureStartedAt;
  RepDetector? _liveDetector;
  bool _isSaving = false;

  Future<void> _loadSavedThreshold(ExerciseType exerciseType) async {
    final threshold = await _ref.read(getWorkoutThresholdUseCaseProvider)(
      exerciseType,
    );
    if (threshold == null || !mounted) return;
    state = state.copyWith(savedThreshold: threshold);
  }

  Future<void> startCapture() async {
    if (state.isCapturing) return;

    _samples.clear();
    _captureStartedAt = DateTime.now();
    // 측정 중 라이브 카운트는 저장된 기준치(없으면 기본값)로 센다.
    _liveDetector = RepDetector(
      (state.savedThreshold ??
              WorkoutThreshold.defaultsFor(state.exerciseType))
          .detectorConfig,
    );

    state = state.copyWith(
      isCapturing: true,
      remainingSeconds: ThresholdSetupState._totalSeconds,
      liveRepCount: 0,
      sampleCount: 0,
      verticalAcceleration: 0,
      clearFailureMessage: true,
      clearLastResult: true,
    );

    _sampleSubscription = _trackingService.watchCalibrationSamples().listen(
      _onSample,
    );
    await _trackingService.startCalibration();

    _startCountdown();
  }

  void _onSample(WorkoutThresholdSample sample) {
    if (!mounted || !state.isCapturing) return;

    _samples.add(sample);
    _liveDetector?.update(sample.verticalAcceleration, sample.timestampMs);

    state = state.copyWith(
      verticalAcceleration: sample.verticalAcceleration,
      sampleCount: _samples.length,
      liveRepCount: _liveDetector?.count ?? 0,
    );
  }

  Future<WorkoutCalibrationResult?> stopAndSave() async {
    if (!state.isCapturing || _isSaving) return null;
    _isSaving = true;

    _countdownTimer?.cancel();
    _countdownTimer = null;
    await _cancelSampleSubscription();

    final startedAt = _captureStartedAt;
    final sampleDurationMs = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMilliseconds;
    _captureStartedAt = null;

    final result = _calibrator.calibrate(
      exerciseType: state.exerciseType,
      samples: _samples,
      sampleDurationMs: sampleDurationMs,
    );

    if (result == null) {
      if (mounted) {
        state = state.copyWith(
          isCapturing: false,
          failureMessage: _failureMessage(sampleDurationMs),
        );
      }
      _isSaving = false;
      return null;
    }

    await _ref.read(saveWorkoutThresholdUseCaseProvider)(result.threshold);

    if (mounted) {
      state = state.copyWith(
        isCapturing: false,
        savedThreshold: result.threshold,
        lastResult: result,
        clearFailureMessage: true,
      );
    }

    _ref.invalidate(workoutMeasureProvider(state.exerciseType));
    _isSaving = false;
    return result;
  }

  String _failureMessage(int sampleDurationMs) {
    if (sampleDurationMs < WorkoutThresholdCalibrator.minimumDurationMs) {
      return '측정 시간이 너무 짧습니다. 다시 시도해 주세요.';
    }
    if (_samples.isEmpty) {
      return '센서 값을 받지 못했습니다. 기기 센서 상태를 확인해 주세요.';
    }
    return '반복 동작이 충분히 감지되지 않았습니다. '
        '휴대폰을 주머니에 넣고 평소 속도로 ${WorkoutThresholdCalibrator.minimumRepCount}회 이상 반복해 주세요.';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !state.isCapturing) {
        timer.cancel();
        return;
      }

      final startedAt = _captureStartedAt;
      if (startedAt == null) return;

      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final remainingMs =
          WorkoutThresholdCalibrator.calibrationDurationMs - elapsedMs;
      state = state.copyWith(
        remainingSeconds: (remainingMs / Duration.millisecondsPerSecond)
            .ceil()
            .clamp(0, ThresholdSetupState._totalSeconds),
      );

      if (remainingMs <= 0) {
        timer.cancel();
        stopAndSave();
      }
    });
  }

  Future<void> _cancelSampleSubscription() async {
    await _sampleSubscription?.cancel();
    _sampleSubscription = null;
    _liveDetector = null;
    await _trackingService.stopCalibration();
  }

  void _cancelCapture() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _sampleSubscription?.cancel();
    _sampleSubscription = null;
    _liveDetector = null;
    _trackingService.stopCalibration();
  }
}
