import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../workout/di/workout_dependencies.dart';
import '../../data/onboarding_local_data_source.dart';
import '../../domain/entities/onboarding_step.dart';

final onboardingLocalDataSourceProvider = Provider<OnboardingLocalDataSource>((
  ref,
) {
  return OnboardingLocalDataSource(ref.watch(sharedPreferencesProvider));
});

final onboardingStepProvider =
    StateNotifierProvider<OnboardingViewModel, OnboardingStep>((ref) {
      return OnboardingViewModel(ref.watch(onboardingLocalDataSourceProvider));
    });

class OnboardingViewModel extends StateNotifier<OnboardingStep> {
  OnboardingViewModel(this._dataSource) : super(_dataSource.getStep());

  final OnboardingLocalDataSource _dataSource;

  Future<void> setStep(OnboardingStep step) async {
    await _dataSource.saveStep(step);
    state = step;
  }

  Future<void> reset() async {
    await _dataSource.reset();
    state = OnboardingStep.start;
  }
}
