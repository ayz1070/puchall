import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/presentation/viewmodels/workout_history_view_model.dart';
import '../widgets/daily_cardio_distance_chart.dart';
import '../widgets/daily_workout_line_chart.dart';
import '../widgets/workout_calendar.dart';

class DailyPage extends ConsumerStatefulWidget {
  const DailyPage({super.key});

  @override
  ConsumerState<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends ConsumerState<DailyPage> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(workoutHistoryProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          sessions.when(
            data: (items) => Column(
              children: [
                AppCard(
                  child: Column(
                    children: [
                      DailyWorkoutLineChart(
                        sessions: items,
                        visibleMonth: _visibleMonth,
                        wrapInCard: false,
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      DailyCardioDistanceChart(
                        sessions: items,
                        visibleMonth: _visibleMonth,
                        wrapInCard: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                WorkoutCalendar(
                  sessions: items,
                  visibleMonth: _visibleMonth,
                  onMonthChanged: (month) {
                    setState(() {
                      _visibleMonth = month;
                    });
                  },
                ),
              ],
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
