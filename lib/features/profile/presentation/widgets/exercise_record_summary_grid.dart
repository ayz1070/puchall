import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/workout_summary.dart';

class ExerciseRecordSummaryGrid extends StatelessWidget {
  const ExerciseRecordSummaryGrid({super.key, required this.summaries});

  final List<ExerciseWorkoutSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('운동별 기록', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        for (final summary in summaries) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.exerciseType.label} 기록',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: '총 횟수',
                        value: '${summary.totalCount}',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: '세션',
                        value: '${summary.sessionCount}',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: '최고',
                        value: '${summary.bestSessionCount}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.titleMedium),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.body),
      ],
    );
  }
}
