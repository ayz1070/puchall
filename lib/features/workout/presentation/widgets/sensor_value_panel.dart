import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/sensor_snapshot.dart';
import '../../domain/entities/workout_threshold.dart';

class SensorValuePanel extends StatelessWidget {
  const SensorValuePanel({
    super.key,
    required this.snapshot,
    required this.thresholdConfig,
  });

  final SensorSnapshot snapshot;
  final WorkoutThreshold? thresholdConfig;

  @override
  Widget build(BuildContext context) {
    final threshold = thresholdConfig;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        children: [
          _SensorThresholdBar(
            label: '가속도',
            currentValue: snapshot.accelerometer.magnitude,
            thresholdValue:
                threshold?.accelerationThreshold ??
                WorkoutThreshold.defaultAccelerationMagnitude *
                    WorkoutThreshold.defaultAccelerationTriggerRatio,
          ),
          const SizedBox(height: 16),
          _SensorThresholdBar(
            label: '자이로',
            currentValue: snapshot.gyroscope.magnitude,
            thresholdValue:
                threshold?.gyroscopeThreshold ??
                WorkoutThreshold.defaultGyroscopeMagnitude *
                    WorkoutThreshold.defaultGyroscopeTriggerRatio,
          ),
          const SizedBox(height: 16),
          _SensorThresholdBar(
            label: '지자기',
            currentValue: snapshot.magnetometer.magnitude,
            thresholdValue:
                threshold?.magnetometerThreshold ??
                WorkoutThreshold.defaultMagnetometerMagnitude *
                    WorkoutThreshold.defaultMagnetometerTriggerRatio,
          ),
        ],
      ),
    );
  }
}

class _SensorThresholdBar extends StatelessWidget {
  const _SensorThresholdBar({
    required this.label,
    required this.currentValue,
    required this.thresholdValue,
  });

  static const _thresholdPosition = 0.75;

  final String label;
  final double currentValue;
  final double thresholdValue;

  @override
  Widget build(BuildContext context) {
    final safeThreshold = thresholdValue <= 0 ? 1.0 : thresholdValue;
    final ratio = currentValue / safeThreshold;
    final progress = (ratio * _thresholdPosition).clamp(0.0, 1.0);
    final color = _barColor(ratio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.label)),
            Text(
              '${currentValue.toStringAsFixed(1)} / ${safeThreshold.toStringAsFixed(1)}',
              style: AppTextStyles.body.copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 3,
                bottom: 3,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.surfaceHigh),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: child,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      color: color,
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _thresholdPosition,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ThresholdMarker(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _barColor(double ratio) {
    if (ratio >= 1) return const Color(0xFFA3E635);
    if (ratio >= 0.8) return const Color(0xFFF97316);
    return AppColors.danger;
  }
}

class _ThresholdMarker extends StatelessWidget {
  const _ThresholdMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        border: Border.all(color: AppColors.background),
      ),
      child: const SizedBox(width: 3, height: 18),
    );
  }
}
