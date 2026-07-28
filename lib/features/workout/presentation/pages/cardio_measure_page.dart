import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../profile/presentation/viewmodels/profile_view_model.dart';
import '../../domain/entities/exercise_type.dart';
import '../viewmodels/cardio_measure_view_model.dart';

class CardioMeasurePage extends ConsumerWidget {
  const CardioMeasurePage({super.key, required this.exerciseType});

  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardioMeasureProvider(exerciseType));
    final notifier = ref.read(cardioMeasureProvider(exerciseType).notifier);
    final profile = ref.watch(profileProvider);
    final weightKg = profile.maybeWhen(
      data: (value) => value.weightKg,
      orElse: () => 70.0,
    );

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
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(state.elapsed),
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 54,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricPanel(
                              label: '거리',
                              value: _formatDistance(state.distanceMeters),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricPanel(
                              label: '칼로리',
                              value: '${state.caloriesKcal.round()} kcal',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _statusLabel(state.status),
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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
                                final session = await notifier.stop();
                                if (!context.mounted) return;
                                final message = session == null
                                    ? '저장할 기록이 없습니다.'
                                    : '${_formatDistance(session.distanceMeters)} 세션을 저장했습니다.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            : () => notifier.start(weightKg: weightKg),
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours <= 0) return '$minutes:$seconds';
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _statusLabel(CardioMeasureStatus status) {
    return switch (status) {
      CardioMeasureStatus.measuring => '측정 중',
      CardioMeasureStatus.completed => '측정 완료',
      CardioMeasureStatus.idle => '측정 대기',
    };
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.body),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
