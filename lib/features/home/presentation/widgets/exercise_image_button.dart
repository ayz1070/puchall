import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../workout/domain/entities/exercise_type.dart';

class ExerciseImageButton extends StatelessWidget {
  const ExerciseImageButton({
    super.key,
    required this.exerciseType,
    required this.onTap,
  });

  final ExerciseType exerciseType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${exerciseType.label} 측정 시작',
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (exerciseType.assetPath != null)
                Image.asset(
                  exerciseType.assetPath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _ExerciseFallbackIcon(exerciseType: exerciseType);
                  },
                )
              else
                _ExerciseFallbackIcon(exerciseType: exerciseType),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exerciseType.label,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseFallbackIcon extends StatelessWidget {
  const _ExerciseFallbackIcon({required this.exerciseType});

  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceHigh,
      child: Icon(exerciseType.icon, color: AppColors.textSecondary, size: 44),
    );
  }
}
