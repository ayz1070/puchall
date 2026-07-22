import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../onboarding/presentation/viewmodels/onboarding_view_model.dart';
import '../../../workout/di/workout_dependencies.dart';
import '../../../workout/presentation/viewmodels/workout_history_view_model.dart';
import '../../di/profile_dependencies.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsListItem(
                    label: '프로필 수정',
                    onTap: () => context.push(AppRoutes.profileEdit),
                  ),
                  const Divider(height: 1),
                  _SettingsListItem(
                    label: '운동 기록 삭제',
                    foregroundColor: AppColors.danger,
                    onTap: () => _clearHistory(context, ref),
                  ),
                  const Divider(height: 1),
                  _SettingsListItem(
                    label: '사용자 초기화',
                    foregroundColor: AppColors.danger,
                    onTap: () => _resetUser(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('운동 기록 삭제'),
          content: const Text('저장된 모든 운동 세션 기록을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    ref.invalidate(clearWorkoutHistoryProvider);
    await ref.read(clearWorkoutHistoryProvider.future);
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('운동 기록을 삭제했습니다.')));
  }

  Future<void> _resetUser(BuildContext context, WidgetRef ref) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('사용자 초기화'),
          content: const Text('프로필, 운동 기록, 기준치를 모두 삭제하고 처음부터 다시 시작할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) return;

    await ref.read(clearUserProfileUseCaseProvider)();
    await ref.read(clearWorkoutSessionsUseCaseProvider)();
    await ref.read(clearWorkoutThresholdsUseCaseProvider)();
    await ref.read(onboardingStepProvider.notifier).reset();

    ref.invalidate(profileProvider);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(todayWorkoutSummaryProvider);
    ref.invalidate(dailyWorkoutSummariesProvider);
    ref.invalidate(exerciseWorkoutSummariesProvider);

    if (!context.mounted) return;
    context.go(AppRoutes.onboardingStart);
  }
}

class _SettingsListItem extends StatelessWidget {
  const _SettingsListItem({
    required this.label,
    required this.onTap,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(color: color),
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
