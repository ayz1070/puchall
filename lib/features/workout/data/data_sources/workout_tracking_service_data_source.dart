import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/entities/workout_tracking_snapshot.dart';
import '../../domain/services/workout_threshold_calibrator.dart';

class WorkoutTrackingServiceDataSource {
  WorkoutTrackingServiceDataSource({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('puchall/workout_tracking'),
       _eventChannel =
           eventChannel ??
           const EventChannel('puchall/workout_tracking_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  static const _calibrationSampleType = 'calibrationSample';

  /// [PlatformException]은 의도적으로 잡지 않는다. 호출부(예: CardioMeasureViewModel)가
  /// 권한 거부 등 실패 사유를 UI에 반영하기 위해 이 예외를 직접 처리한다.
  Future<void> start({
    required ExerciseType exerciseType,
    required WorkoutThreshold threshold,
    required double weightKg,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('startTracking', {
        'exerciseType': exerciseType.slug,
        'amplitudeThreshold': threshold.amplitudeThreshold,
        'minHalfPeriodMs': threshold.minHalfPeriodMs,
        'maxHalfPeriodMs': threshold.maxHalfPeriodMs,
        'cooldownMs': threshold.cooldownMs,
        'lowPassCutoffHz': threshold.lowPassCutoffHz,
        'verticalAccelerationScale': threshold.verticalAccelerationScale,
        'weightKg': weightKg,
      });
    } on MissingPluginException {
      // 해당 플랫폼에 트래킹 채널이 구현되어 있지 않음.
    }
  }

  Future<void> startCardio({
    required ExerciseType exerciseType,
    required double weightKg,
    double heightCm = 0,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('startTracking', {
        'exerciseType': exerciseType.slug,
        'weightKg': weightKg,
        'heightCm': heightCm,
      });
    } on MissingPluginException {
      // 해당 플랫폼에 트래킹 채널이 구현되어 있지 않음.
    }
  }

  /// 기준치 측정용 센서 수집을 시작한다.
  ///
  /// 측정과 동일한 네이티브 파이프라인을 쓰므로, 여기서 얻은 샘플로 계산한 기준치가
  /// 실제 측정에 그대로 적용된다.
  Future<void> startCalibration() async {
    try {
      await _methodChannel.invokeMethod<void>('startCalibration');
    } on MissingPluginException {
      // 해당 플랫폼에 트래킹 채널이 구현되어 있지 않음.
    }
  }

  Future<void> stopCalibration() async {
    try {
      await _methodChannel.invokeMethod<void>('stopCalibration');
    } on PlatformException {
      // 정리 실패는 흐름을 막을 만큼 치명적이지 않다.
    } on MissingPluginException {
      // 해당 플랫폼에 트래킹 채널이 구현되어 있지 않음.
    }
  }

  Future<WorkoutTrackingSnapshot> stop() async {
    try {
      final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'stopTracking',
      );
      return WorkoutTrackingSnapshot.fromMap(result ?? const {});
    } on PlatformException {
      return _idleSnapshot;
    } on MissingPluginException {
      return _idleSnapshot;
    }
  }

  Future<void> reset() async {
    try {
      await _methodChannel.invokeMethod<void>('resetTracking');
    } on PlatformException {
      // 무시: 리셋 실패는 측정 흐름을 막을 만큼 치명적이지 않다.
    } on MissingPluginException {
      // 해당 플랫폼에 트래킹 채널이 구현되어 있지 않음.
    }
  }

  Future<WorkoutTrackingSnapshot> getState() async {
    try {
      final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'getTrackingState',
      );
      return WorkoutTrackingSnapshot.fromMap(result ?? const {});
    } on PlatformException {
      return _idleSnapshot;
    } on MissingPluginException {
      return _idleSnapshot;
    }
  }

  Future<WorkoutTrackingSnapshot?> consumeCompletedSession() async {
    try {
      final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'consumeCompletedSession',
      );
      if (result == null || result.isEmpty) return null;
      return WorkoutTrackingSnapshot.fromMap(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Stream<WorkoutTrackingSnapshot> watch() {
    return _events()
        .where((event) => event['type'] != _calibrationSampleType)
        .map(WorkoutTrackingSnapshot.fromMap);
  }

  /// 캘리브레이션 중 흐르는 원시 수직 가속도 샘플.
  Stream<WorkoutThresholdSample> watchCalibrationSamples() {
    return _events()
        .where((event) => event['type'] == _calibrationSampleType)
        .map(
          (event) => WorkoutThresholdSample(
            timestampMs: (event['timestampMs'] as num?)?.toInt() ?? 0,
            verticalAcceleration:
                (event['verticalAcceleration'] as num?)?.toDouble() ?? 0,
          ),
        );
  }

  Stream<Map<dynamic, dynamic>> _events() {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .cast<Map<dynamic, dynamic>>()
        .handleError(
          (Object _) {},
          test: (error) =>
              error is PlatformException || error is MissingPluginException,
        );
  }

  static const _idleSnapshot = WorkoutTrackingSnapshot(
    exerciseType: ExerciseType.pushUp,
    status: WorkoutTrackingStatus.idle,
    count: 0,
  );
}
