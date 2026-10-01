import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exercise_type.dart';
import '../viewmodels/threshold_setup_view_model.dart';
import '../widgets/vertical_acceleration_panel.dart';

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
                    '휴대폰을 주머니에 넣고 30초 동안 평소 속도로 반복해 주세요. '
                    '측정한 동작의 평균 크기를 기준으로 개인 기준치를 만듭니다.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '남은 시간 ${state.remainingSeconds.toString().padLeft(2, '0')}초',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(_savedText(state), style: AppTextStyles.body),
                  if (state.lastResult != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '이 기준치로 방금 측정 구간을 다시 세어 보니 '
                      '${state.lastResult!.detectedRepCount}회로 인식됩니다.',
                      style: AppTextStyles.body,
                    ),
                  ],
                  if (state.failureMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(state.failureMessage!, style: AppTextStyles.body),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            VerticalAccelerationPanel(
              verticalAcceleration: state.verticalAcceleration,
              amplitudeThreshold: state.displayThreshold,
              repCount: state.liveRepCount,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: state.isCapturing ? '측정 종료 및 저장' : '30초 기준치 측정 시작',
              icon: state.isCapturing ? Icons.save : Icons.play_arrow,
              onPressed: state.isCapturing
                  ? () async {
                      final result = await notifier.stopAndSave();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result == null
                                ? '기준치를 저장하지 못했습니다.'
                                : '기준치를 저장했습니다. ${result.detectedRepCount}회로 인식했습니다.',
                          ),
                        ),
                      );
                    }
                  : notifier.startCapture,
            ),
          ],
        ),
      ),
    );
  }

  String _savedText(ThresholdSetupState state) {
    final saved = state.savedThreshold;
    if (saved == null) return '저장된 기준치가 없어 기본값으로 측정합니다.';
    return '저장된 기준치 ±${saved.amplitudeThreshold.toStringAsFixed(2)} m/s² · '
        '반복 간격 ${saved.minHalfPeriodMs}~${saved.maxHalfPeriodMs}ms';
  }
}
