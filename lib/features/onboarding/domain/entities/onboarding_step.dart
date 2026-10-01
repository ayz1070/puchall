enum OnboardingStep {
  start('start'),
  profile('profile'),
  pushUpThreshold('push_up_threshold'),
  pullUpThreshold('pull_up_threshold'),
  completed('completed');

  const OnboardingStep(this.storageValue);

  final String storageValue;

  static OnboardingStep fromStorageValue(String? value) {
    return OnboardingStep.values.firstWhere(
      (step) => step.storageValue == value,
      orElse: () => OnboardingStep.start,
    );
  }
}
