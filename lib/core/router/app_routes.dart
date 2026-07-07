import '../../features/workout/domain/entities/exercise_type.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const mainBase = '/main';
  static const home = '$mainBase/home';
  static const profile = '$mainBase/profile';
  static const profileSettings = '/profile/settings';
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
