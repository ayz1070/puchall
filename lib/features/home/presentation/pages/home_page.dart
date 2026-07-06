import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../widgets/exercise_image_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ExerciseImageButton(
            exerciseType: ExerciseType.pushUp,
            onTap: () => context.go(AppRoutes.workoutFor(ExerciseType.pushUp)),
          ),
        ),
        Expanded(
          child: ExerciseImageButton(
            exerciseType: ExerciseType.pullUp,
            onTap: () => context.go(AppRoutes.workoutFor(ExerciseType.pullUp)),
          ),
        ),
      ],
    );
  }
}
