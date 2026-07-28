import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/workout_summary.dart';

class DailyRecordList extends StatelessWidget {
  const DailyRecordList({super.key, required this.summaries});

  final List<DailyWorkoutSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const AppCard(
        child: Text('매일의 운동 기록이 없습니다.', style: AppTextStyles.body),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('매일의 운동 기록', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        for (final summary in summaries.take(14)) ...[
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(summary.dateKey, style: AppTextStyles.label),
                ),
                Flexible(
                  child: Text(
                    '푸쉬업 ${summary.pushUpCount} · 풀업 ${summary.pullUpCount} · 런닝 ${_formatKm(summary.runningDistanceMeters)} · 걷기 ${_formatKm(summary.walkingDistanceMeters)}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
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

String _formatKm(double meters) {
  return '${(meters / 1000).toStringAsFixed(2)}km';
}
