enum ExerciseType {
  pushUp(
    slug: 'push-up',
    label: '푸쉬업',
    assetPath: 'assets/buttons/btn_push_up.png',
  ),
  pullUp(
    slug: 'pull-up',
    label: '풀업',
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
