import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/exercise_type.dart';
import '../../domain/entities/workout_tracking_snapshot.dart';
import '../viewmodels/workout_measure_view_model.dart';

class WorkoutMeasurePage extends ConsumerWidget {
  const WorkoutMeasurePage({super.key, required this.exerciseType});

  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutMeasureProvider(exerciseType));
    final notifier = ref.read(workoutMeasureProvider(exerciseType).notifier);

    final canPop = context.canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
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
              onPressed: () =>
                  context.push(AppRoutes.thresholdFor(exerciseType)),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${state.count}',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontSize: 82,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _statusLabel(state.status),
                                style: AppTextStyles.body,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                state.isMeasuring
                                    ? '휴대폰을 바지 주머니에 넣은 상태로 운동해 주세요.'
                                    : '시작 후 휴대폰을 바지 주머니에 넣어 주세요. 앱을 나가도 측정은 계속됩니다.',
                                style: AppTextStyles.body,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                          icon: state.isMeasuring
                              ? Icons.stop
                              : Icons.play_arrow,
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
                              : () {
                                  notifier.start();
                                },
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
                          onPressed: () {
                            notifier.reset();
                          },
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
      ),
    );
  }

  String _statusLabel(WorkoutTrackingStatus status) {
    return switch (status) {
      WorkoutTrackingStatus.measuring => '측정 중',
      WorkoutTrackingStatus.paused => '일시정지',
      WorkoutTrackingStatus.completed => '측정 완료',
      WorkoutTrackingStatus.failed => '측정할 수 없습니다',
      WorkoutTrackingStatus.idle => '측정 대기',
    };
  }
}
