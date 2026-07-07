import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exercise_type.dart';
import '../viewmodels/threshold_setup_view_model.dart';
import '../widgets/sensor_value_panel.dart';

class ThresholdSetupPage extends ConsumerWidget {
  const ThresholdSetupPage({super.key, required this.exerciseType});

  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thresholdSetupProvider(exerciseType));
    final notifier = ref.read(thresholdSetupProvider(exerciseType).notifier);

    return Scaffold(
      appBar: AppBar(title: Text('${exerciseType.label} 기준치')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('기준치 측정', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '1회 동작의 가속도와 자이로 패턴을 기준치로 저장합니다.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '가속도 최대 ${state.maxAccelerationMagnitude.toStringAsFixed(2)}',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '자이로 최대 ${state.maxGyroscopeMagnitude.toStringAsFixed(2)}',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '지자기 최대 ${state.maxMagnetometerMagnitude.toStringAsFixed(2)}',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.savedThreshold == null
                        ? '저장된 기준치 -'
                        : '저장됨 가속도 ${state.savedThreshold!.accelerationMagnitude.toStringAsFixed(2)} · 자이로 ${state.savedThreshold!.gyroscopeMagnitude.toStringAsFixed(2)} · 지자기 ${state.savedThreshold!.magnetometerMagnitude.toStringAsFixed(2)}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SensorValuePanel(
              snapshot: state.snapshot,
              thresholdConfig: state.previewThreshold,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: state.isCapturing ? '측정 종료 및 저장' : '기준치 측정 시작',
              icon: state.isCapturing ? Icons.save : Icons.play_arrow,
              onPressed: state.isCapturing
                  ? () async {
                      final savedThreshold = await notifier.stopAndSave();
                      if (!context.mounted) return;
                      final message = savedThreshold == null
                          ? '측정된 센서값이 없어 기준치를 저장하지 않았습니다.'
                          : '기준치를 저장했습니다. 가속도 ${savedThreshold.accelerationMagnitude.toStringAsFixed(2)}, 자이로 ${savedThreshold.gyroscopeMagnitude.toStringAsFixed(2)}, 지자기 ${savedThreshold.magnetometerMagnitude.toStringAsFixed(2)}';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  : notifier.startCapture,
            ),
          ],
        ),
      ),
    );
  }
}
