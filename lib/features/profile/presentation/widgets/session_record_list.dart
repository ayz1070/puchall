import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/workout_session.dart';

class SessionRecordList extends StatelessWidget {
  const SessionRecordList({super.key, required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const AppCard(
        child: Text('저장된 운동 세션이 없습니다.', style: AppTextStyles.body),
      );
    }

    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('운동 세션', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        for (final session in sessions.take(20)) ...[
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.exerciseType.label,
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(session.startedAt)} · ${_formatDuration(session.exerciseType.isCardio ? session.activeDuration : session.duration)}',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
                Text(_sessionValue(session), style: AppTextStyles.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _sessionValue(WorkoutSession session) {
    if (session.exerciseType.isCardio) {
      return '${(session.distanceMeters / 1000).toStringAsFixed(2)}km';
    }

    if (session.caloriesKcal <= 0) return '${session.count}회';
    return '${session.count}회 · ${session.caloriesKcal.round()}kcal';
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';

    final minutes = duration.inMinutes;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) return '${minutes}m';
    return '${minutes}m ${remainingSeconds}s';
  }
}
