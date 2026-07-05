import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exercise_type.dart';
import '../viewmodels/workout_measure_view_model.dart';
import '../widgets/sensor_value_panel.dart';

class WorkoutMeasurePage extends ConsumerWidget {
  const WorkoutMeasurePage({super.key, required this.exerciseType});

  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutMeasureProvider(exerciseType));
    final notifier = ref.read(workoutMeasureProvider(exerciseType).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(exerciseType.label),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.thresholdFor(exerciseType)),
            icon: const Icon(Icons.tune),
            tooltip: '기준치 설정',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${state.count}', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '현재 카운트 · 기준치 ${state.threshold.toStringAsFixed(2)}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SensorValuePanel(snapshot: state.snapshot),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: state.isMeasuring ? '측정 정지' : '측정 시작',
                    icon: state.isMeasuring ? Icons.stop : Icons.play_arrow,
                    onPressed: state.isMeasuring
                        ? () async {
                            final savedCount = await notifier.stop();
                            if (!context.mounted || savedCount == null) return;
                            final message = savedCount > 0
                                ? '$savedCount회 세션을 저장했습니다.'
                                : '저장할 카운트가 없습니다.';
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        : notifier.start,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: '초기화',
                    icon: Icons.refresh,
                    isOutlined: true,
                    onPressed: notifier.reset,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
