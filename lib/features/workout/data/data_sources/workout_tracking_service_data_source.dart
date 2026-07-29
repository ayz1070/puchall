import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_threshold.dart';
import '../../domain/entities/workout_tracking_snapshot.dart';

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

  Future<void> start({
    required ExerciseType exerciseType,
    required WorkoutThreshold threshold,
    required double weightKg,
  }) {
    return _methodChannel.invokeMethod<void>('startTracking', {
      'exerciseType': exerciseType.slug,
      'accelerationThreshold': threshold.accelerationThreshold,
      'gyroscopeThreshold': threshold.gyroscopeThreshold,
      'releaseRatio': threshold.releaseRatio,
      'cooldownMs': threshold.cooldownMs,
      'weightKg': weightKg,
    });
  }

  Future<void> startCardio({
    required ExerciseType exerciseType,
    required double weightKg,
  }) {
    return _methodChannel.invokeMethod<void>('startTracking', {
      'exerciseType': exerciseType.slug,
      'weightKg': weightKg,
    });
  }

  Future<WorkoutTrackingSnapshot> stop() async {
    final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
      'stopTracking',
    );
    return WorkoutTrackingSnapshot.fromMap(result ?? const {});
  }

  Future<void> reset() {
    return _methodChannel.invokeMethod<void>('resetTracking');
  }

  Future<WorkoutTrackingSnapshot> getState() async {
    final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
      'getTrackingState',
    );
    return WorkoutTrackingSnapshot.fromMap(result ?? const {});
  }

  Future<WorkoutTrackingSnapshot?> consumeCompletedSession() async {
    final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
      'consumeCompletedSession',
    );
    if (result == null || result.isEmpty) return null;
    return WorkoutTrackingSnapshot.fromMap(result);
  }

  Stream<WorkoutTrackingSnapshot> watch() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) return WorkoutTrackingSnapshot.fromMap(event);
      return const WorkoutTrackingSnapshot(
        exerciseType: ExerciseType.pushUp,
        status: WorkoutTrackingStatus.idle,
        count: 0,
      );
    });
  }
}
