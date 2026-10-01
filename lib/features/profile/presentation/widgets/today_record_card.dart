import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/workout_summary.dart';

class TodayRecordCard extends StatelessWidget {
  const TodayRecordCard({super.key, required this.summary});

  final DailyWorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘 운동 기록', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _RecordValue(label: '푸쉬업', value: '${summary.pushUpCount}'),
              _RecordValue(label: '풀업', value: '${summary.pullUpCount}'),
              _RecordValue(
                label: '런닝',
                value: _formatKm(summary.runningDistanceMeters),
              ),
              _RecordValue(
                label: '걷기',
                value: _formatKm(summary.walkingDistanceMeters),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.body),
      ],
    );
  }
}

String _formatKm(double meters) {
  return '${(meters / 1000).toStringAsFixed(2)}km';
}
