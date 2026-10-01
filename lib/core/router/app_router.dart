import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/main/presentation/pages/main_navigation_page.dart';
import '../../features/onboarding/domain/entities/onboarding_step.dart';
import '../../features/onboarding/presentation/pages/onboarding_profile_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_start_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_threshold_pages.dart';
import '../../features/onboarding/presentation/viewmodels/onboarding_view_model.dart';
import '../../features/profile/di/profile_dependencies.dart';
import '../../features/profile/presentation/pages/daily_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_settings_page.dart';
import '../../features/profile/presentation/pages/workout_records_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/workout/domain/entities/exercise_type.dart';
import '../../features/workout/presentation/pages/cardio_measure_page.dart';
import '../../features/workout/presentation/pages/threshold_setup_page.dart';
import '../../features/workout/presentation/pages/workout_measure_page.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final onboardingStep = ref.read(onboardingStepProvider);
      final hasSavedProfile = ref
          .read(profileLocalDataSourceProvider)
          .hasProfile();
      final location = state.uri.path;
      final isSplash = location == AppRoutes.splash;
      final isOnboarding = location.startsWith(AppRoutes.onboardingBase);
      final isCompleted = onboardingStep == OnboardingStep.completed;

      if (isSplash) return null;

      if (!hasSavedProfile) {
        if (location == AppRoutes.onboardingStart ||
            (location == AppRoutes.onboardingProfile &&
                onboardingStep == OnboardingStep.profile)) {
          return null;
        }

        return AppRoutes.onboardingStart;
      }

      if (!isCompleted) {
        final expectedRoute = _routeForOnboardingStep(onboardingStep);
        if (location != expectedRoute) {
          return expectedRoute;
        }

        return null;
      }

      if (isOnboarding) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.splash),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStart,
        builder: (context, state) => const OnboardingStartPage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingProfile,
        builder: (context, state) => const OnboardingProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPushUpThreshold,
        builder: (context, state) => const OnboardingPushUpThresholdPage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPullUpThreshold,
        builder: (context, state) => const OnboardingPullUpThresholdPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.path;
          final currentIndex = location.startsWith(AppRoutes.profile)
              ? 2
              : location.startsWith(AppRoutes.daily)
              ? 1
              : 0;

          return MainNavigationPage(currentIndex: currentIndex, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.daily,
            builder: (context, state) => const DailyPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.workoutRecords,
        builder: (context, state) => const WorkoutRecordsPage(),
      ),
      GoRoute(
        path: AppRoutes.profileSettings,
        builder: (context, state) => const ProfileSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: AppRoutes.workout,
        builder: (context, state) {
          final exerciseType = ExerciseType.fromSlug(
            state.pathParameters['exercise'],
          );
          if (exerciseType.isCardio) {
            return CardioMeasurePage(exerciseType: exerciseType);
          }
          return WorkoutMeasurePage(exerciseType: exerciseType);
        },
      ),
      GoRoute(
        path: AppRoutes.threshold,
        builder: (context, state) {
          final exerciseType = ExerciseType.fromSlug(
            state.pathParameters['exercise'],
          );
          return ThresholdSetupPage(exerciseType: exerciseType);
        },
      ),
    ],
  );
});

String _routeForOnboardingStep(OnboardingStep step) {
  return switch (step) {
    OnboardingStep.start => AppRoutes.onboardingStart,
    OnboardingStep.profile => AppRoutes.onboardingProfile,
    OnboardingStep.pushUpThreshold => AppRoutes.onboardingPushUpThreshold,
    OnboardingStep.pullUpThreshold => AppRoutes.onboardingPullUpThreshold,
    OnboardingStep.completed => AppRoutes.home,
  };
}
