import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../workout/presentation/viewmodels/workout_history_view_model.dart';
import '../viewmodels/profile_view_model.dart';
import '../widgets/daily_record_list.dart';
import '../widgets/exercise_record_summary_grid.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_danger_zone.dart';
import '../widgets/session_record_list.dart';
import '../widgets/today_record_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySummary = ref.watch(todayWorkoutSummaryProvider);
    final sessions = ref.watch(workoutHistoryProvider);
    final dailySummaries = ref.watch(dailyWorkoutSummariesProvider);
    final exerciseSummaries = ref.watch(exerciseWorkoutSummariesProvider);
    final profile = ref.watch(profileProvider);

    Future<void> clearHistory() async {
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
      await ref.read(clearWorkoutHistoryProvider.future);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('운동 기록을 삭제했습니다.')));
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Text('마이페이지', style: AppTextStyles.titleLarge),
          const SizedBox(height: 24),
          profile.when(
            data: (value) =>
                ProfileHeader(name: value.name, imagePath: value.imagePath),
            loading: () => const Text('프로필을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('프로필을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: '프로필 수정',
            icon: Icons.edit,
            isOutlined: true,
            onPressed: () => context.push(AppRoutes.profileEdit),
          ),
          const SizedBox(height: 16),
          todaySummary.when(
            data: (summary) => TodayRecordCard(summary: summary),
            loading: () =>
                const Text('오늘 기록을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('오늘 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
          const SizedBox(height: 24),
          exerciseSummaries.when(
            data: (items) => ExerciseRecordSummaryGrid(summaries: items),
            loading: () =>
                const Text('운동별 기록을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('운동별 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
          const SizedBox(height: 24),
          dailySummaries.when(
            data: (items) => DailyRecordList(summaries: items),
            loading: () =>
                const Text('매일의 기록을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('매일의 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
          const SizedBox(height: 24),
          sessions.when(
            data: (items) => SessionRecordList(sessions: items),
            loading: () =>
                const Text('세션 기록을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('세션 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
          const SizedBox(height: 24),
          ProfileDangerZone(onClearHistory: clearHistory),
        ],
      ),
    );
  }
}
