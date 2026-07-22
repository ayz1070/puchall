import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../../../workout/presentation/viewmodels/threshold_setup_view_model.dart';
import '../../domain/entities/onboarding_step.dart';
import '../viewmodels/onboarding_view_model.dart';

class OnboardingPushUpThresholdPage extends StatelessWidget {
  const OnboardingPushUpThresholdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OnboardingThresholdPage(
      exerciseType: ExerciseType.pushUp,
      nextStep: OnboardingStep.pullUpThreshold,
      nextRoute: AppRoutes.onboardingPullUpThreshold,
    );
  }
}

class OnboardingPullUpThresholdPage extends StatelessWidget {
  const OnboardingPullUpThresholdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OnboardingThresholdPage(
      exerciseType: ExerciseType.pullUp,
      nextStep: OnboardingStep.completed,
      nextRoute: AppRoutes.home,
      showBackButton: true,
    );
  }
}

class _OnboardingThresholdPage extends ConsumerWidget {
  const _OnboardingThresholdPage({
    required this.exerciseType,
    required this.nextStep,
    required this.nextRoute,
    this.showBackButton = false,
  });

  final ExerciseType exerciseType;
  final OnboardingStep nextStep;
  final String nextRoute;
  final bool showBackButton;

  static const _countdownSeconds = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thresholdSetupProvider(exerciseType));
    final notifier = ref.read(thresholdSetupProvider(exerciseType).notifier);
    final canGoNext = !state.isCapturing && state.savedThreshold != null;

    ref.listen(thresholdSetupProvider(exerciseType), (previous, next) async {
      if (previous?.isCapturing == true &&
          !next.isCapturing &&
          next.savedThreshold != null) {
        await SystemSound.play(SystemSoundType.alert);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('측정이 완료되었습니다.')));
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? IconButton(
                onPressed: () async {
                  await _goPrevious(context, ref);
                },
                icon: const Icon(Icons.arrow_back),
                tooltip: '뒤로',
              )
            : null,
        title: Text('${_koreanExerciseName(exerciseType)} 측정'),
        actions: [
          TextButton(
            onPressed: () => _goNext(context, ref),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${_koreanExerciseName(exerciseType)} 기준치 측정',
                        style: AppTextStyles.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '30초 동안 평소처럼 반복해주세요.',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _CountdownCircle(
                        seconds: state.remainingSeconds,
                        totalSeconds: _countdownSeconds,
                        isCapturing: state.isCapturing,
                        isComplete: canGoNext,
                      ),
                      const SizedBox(height: 20),
                      Text(_statusText(state), style: AppTextStyles.label),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox.expand(
                      child: AppButton(
                        label: state.isCapturing ? '측정 중' : '측정 시작',
                        icon: state.isCapturing
                            ? Icons.timer
                            : Icons.play_arrow,
                        onPressed: state.isCapturing
                            ? null
                            : notifier.startCapture,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox.expand(
                      child: AppButton(
                        label: '다음',
                        icon: Icons.arrow_forward,
                        onPressed: canGoNext
                            ? () => _goNext(context, ref)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goNext(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingStepProvider.notifier).setStep(nextStep);
    if (!context.mounted) return;
    context.go(nextRoute);
  }

  Future<void> _goPrevious(BuildContext context, WidgetRef ref) async {
    await ref
        .read(onboardingStepProvider.notifier)
        .setStep(OnboardingStep.pushUpThreshold);
    if (!context.mounted) return;
    context.go(AppRoutes.onboardingPushUpThreshold);
  }

  String _koreanExerciseName(ExerciseType exerciseType) {
    return switch (exerciseType) {
      ExerciseType.pushUp => '푸쉬업',
      ExerciseType.pullUp => '풀업',
    };
  }

  String _statusText(ThresholdSetupState state) {
    if (state.isCapturing) return '측정 중입니다.';
    if (state.savedThreshold != null) return '측정 완료';
    return '측정 시작을 눌러주세요.';
  }
}

class _CountdownCircle extends StatelessWidget {
  const _CountdownCircle({
    required this.seconds,
    required this.totalSeconds,
    required this.isCapturing,
    required this.isComplete,
  });

  final int seconds;
  final int totalSeconds;
  final bool isCapturing;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final color = isComplete
        ? const Color(0xFFA3E635)
        : isCapturing
        ? AppColors.brandPrimary
        : AppColors.border;
    final progress = isComplete
        ? 0.0
        : seconds.clamp(0, totalSeconds) / totalSeconds;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
            ),
          ),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surfaceHigh,
                  color: color,
                );
              },
            ),
          ),
          Text(
            seconds.toString().padLeft(2, '0'),
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 72,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
