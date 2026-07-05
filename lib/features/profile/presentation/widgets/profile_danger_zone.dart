import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

class ProfileDangerZone extends StatelessWidget {
  const ProfileDangerZone({super.key, required this.onClearHistory});

  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기록 관리', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          const Text('로컬에 저장된 운동 세션 기록을 삭제합니다.', style: AppTextStyles.body),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onClearHistory,
            icon: const Icon(Icons.delete_outline),
            label: const Text('운동 기록 삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
