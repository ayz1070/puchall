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
                    '1회 동작을 수행하는 동안 가속도 최대값을 저장합니다.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '현재 최대값 ${state.maxAccelerationMagnitude.toStringAsFixed(2)}',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '저장된 기준치 ${state.savedThreshold?.toStringAsFixed(2) ?? '-'}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SensorValuePanel(snapshot: state.snapshot),
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
                          : '기준치를 ${savedThreshold.toStringAsFixed(2)}로 저장했습니다.';
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
