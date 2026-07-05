import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../widgets/exercise_image_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Text('Puchall', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          const Text('오늘 측정할 운동을 선택하세요.', style: AppTextStyles.body),
          const SizedBox(height: 28),
          ExerciseImageButton(
            exerciseType: ExerciseType.pushUp,
            onTap: () => context.go(AppRoutes.workoutFor(ExerciseType.pushUp)),
          ),
          const SizedBox(height: 16),
          ExerciseImageButton(
            exerciseType: ExerciseType.pullUp,
            onTap: () => context.go(AppRoutes.workoutFor(ExerciseType.pullUp)),
          ),
        ],
      ),
    );
  }
}
