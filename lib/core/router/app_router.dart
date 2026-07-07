import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/main/presentation/pages/main_navigation_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/workout/domain/entities/exercise_type.dart';
import '../../features/workout/presentation/pages/threshold_setup_page.dart';
import '../../features/workout/presentation/pages/workout_measure_page.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.splash),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.path;
          final currentIndex = location.startsWith(AppRoutes.profile) ? 1 : 0;

          return MainNavigationPage(currentIndex: currentIndex, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
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
