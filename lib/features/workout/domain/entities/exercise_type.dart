enum ExerciseType {
  pushUp(
    slug: 'push-up',
    label: 'PUSH UP',
    assetPath: 'assets/buttons/btn_push_up.jpeg',
  ),
  pullUp(
    slug: 'pull-up',
    label: 'PULL UP',
    assetPath: 'assets/buttons/btn_pull_up.jpeg',
  );

  const ExerciseType({
    required this.slug,
    required this.label,
    required this.assetPath,
  });

  final String slug;
  final String label;
  final String assetPath;

  static ExerciseType fromSlug(String? slug) {
    return ExerciseType.values.firstWhere(
      (type) => type.slug == slug,
      orElse: () => ExerciseType.pushUp,
    );
  }
}
