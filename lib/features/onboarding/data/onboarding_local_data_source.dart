import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/onboarding_step.dart';

class OnboardingLocalDataSource {
  const OnboardingLocalDataSource(this._preferences);

  final SharedPreferences _preferences;

  static const _stepKey = 'onboarding_step';

  OnboardingStep getStep() {
    return OnboardingStep.fromStorageValue(_preferences.getString(_stepKey));
  }

  Future<void> saveStep(OnboardingStep step) {
    return _preferences.setString(_stepKey, step.storageValue);
  }

  Future<void> reset() {
    return saveStep(OnboardingStep.start);
  }
}
