import '../../features/workout/domain/entities/exercise_type.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const onboardingBase = '/onboarding';
  static const onboardingStart = '$onboardingBase/start';
  static const onboardingProfile = '$onboardingBase/profile';
  static const onboardingPushUpThreshold = '$onboardingBase/threshold/push-up';
  static const onboardingPullUpThreshold = '$onboardingBase/threshold/pull-up';
  static const mainBase = '/main';
  static const home = '$mainBase/home';
  static const daily = '$mainBase/daily';
  static const profile = '$mainBase/profile';
  static const profileSettings = '/profile/settings';
  static const workoutRecords = '/profile/workout-records';
  static const profileEdit = '/profile/edit';
  static const workoutBase = '/workout';
  static const workout = '$workoutBase/:exercise';
  static const thresholdBase = '/threshold';
  static const threshold = '$thresholdBase/:exercise';

  static String workoutFor(ExerciseType exerciseType) {
    return '$workoutBase/${exerciseType.slug}';
  }

  static String thresholdFor(ExerciseType exerciseType) {
    return '$thresholdBase/${exerciseType.slug}';
  }
}
