import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
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
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.home);
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로',
        ),
        title: Text(exerciseType.label),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.thresholdFor(exerciseType)),
            icon: const Icon(Icons.tune),
            tooltip: '기준치 설정',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  children: [
                    Text(
                      '${state.count}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontSize: 82,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '기준치 ${state.threshold.toStringAsFixed(2)}',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 24),
                    SensorValuePanel(snapshot: state.snapshot),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox.expand(
                      child: AppButton(
                        label: state.isMeasuring ? '측정 정지' : '측정 시작',
                        icon: state.isMeasuring ? Icons.stop : Icons.play_arrow,
                        onPressed: state.isMeasuring
                            ? () async {
                                final savedCount = await notifier.stop();
                                if (!context.mounted || savedCount == null) {
                                  return;
                                }
                                final message = savedCount > 0
                                    ? '$savedCount회 세션을 저장했습니다.'
                                    : '저장할 카운트가 없습니다.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            : notifier.start,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox.expand(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.background,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          side: BorderSide.none,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: notifier.reset,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: 8),
                            Text('초기화'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
