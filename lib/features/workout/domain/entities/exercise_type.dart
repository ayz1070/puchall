import 'package:flutter/material.dart';

enum ExerciseType {
  pushUp(
    slug: 'push-up',
    label: 'PUSH UP',
    assetPath: 'assets/buttons/btn_push_up.jpeg',
    icon: Icons.fitness_center,
  ),
  pullUp(
    slug: 'pull-up',
    label: 'PULL UP',
    assetPath: 'assets/buttons/btn_pull_up.jpeg',
    icon: Icons.sports_gymnastics,
  ),
  running(
    slug: 'running',
    label: 'RUNNING',
    assetPath: 'assets/buttons/btn_running.jpeg',
    icon: Icons.directions_run,
  ),
  walking(
    slug: 'walking',
    label: 'WALKING',
    assetPath: 'assets/buttons/btn_walking.jpeg',
    icon: Icons.directions_walk,
  );

  const ExerciseType({
    required this.slug,
    required this.label,
    required this.icon,
    this.assetPath,
  });

  final String slug;
  final String label;
  final IconData icon;
  final String? assetPath;

  bool get isStrength => this == pushUp || this == pullUp;
  bool get isCardio => this == running || this == walking;

  static ExerciseType fromSlug(String? slug) {
    return ExerciseType.values.firstWhere(
      (type) => type.slug == slug,
      orElse: () => ExerciseType.pushUp,
    );
  }
}
