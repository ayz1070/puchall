import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../workout/presentation/viewmodels/workout_history_view_model.dart';
import '../widgets/workout_calendar.dart';

class WorkoutRecordsPage extends ConsumerWidget {
  const WorkoutRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('운동 기록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            sessions.when(
              data: (items) => WorkoutCalendar(sessions: items),
              loading: () =>
                  const Text('운동 기록을 불러오는 중', style: AppTextStyles.body),
              error: (error, stackTrace) =>
                  const Text('운동 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}
