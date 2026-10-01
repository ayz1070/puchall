import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../widgets/exercise_image_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const exerciseTypes = [
      ExerciseType.pushUp,
      ExerciseType.pullUp,
      ExerciseType.running,
      ExerciseType.walking,
    ];

    return Column(
      children: [
        for (final exerciseType in exerciseTypes)
          Expanded(
            child: ExerciseImageButton(
              exerciseType: exerciseType,
              onTap: () => context.go(AppRoutes.workoutFor(exerciseType)),
            ),
          ),
      ],
    );
  }
}
