import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../workout/presentation/viewmodels/workout_history_view_model.dart';
import '../viewmodels/profile_view_model.dart';
import '../widgets/profile_header.dart';
import '../widgets/daily_workout_line_chart.dart';
import '../widgets/today_record_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySummary = ref.watch(todayWorkoutSummaryProvider);
    final sessions = ref.watch(workoutHistoryProvider);
    final profile = ref.watch(profileProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          profile.when(
            data: (value) =>
                ProfileHeader(name: value.name, imagePath: value.imagePath),
            loading: () => const Text('프로필을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('프로필을 불러오지 못했습니다.', style: AppTextStyles.body),
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
          sessions.when(
            data: (items) => DailyWorkoutLineChart(
              sessions: items,
              onTap: () => context.push(AppRoutes.workoutRecords),
            ),
            loading: () =>
                const Text('데일리 기록을 불러오는 중', style: AppTextStyles.body),
            error: (error, stackTrace) =>
                const Text('데일리 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}
