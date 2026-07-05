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
          Row(
            children: [
              Expanded(
                child: _RecordValue(label: '푸쉬업', count: summary.pushUpCount),
              ),
              Expanded(
                child: _RecordValue(label: '풀업', count: summary.pullUpCount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count', style: AppTextStyles.titleLarge),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.body),
      ],
    );
  }
}
