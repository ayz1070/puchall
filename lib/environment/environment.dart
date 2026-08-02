import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ads/ad_config.dart';
import '../app.dart';
import 'environment_type.dart';
import '../features/workout/data/data_sources/workout_session_database.dart';
import '../features/workout/di/workout_dependencies.dart';

class Environment {
  const Environment._(this.type);

  final EnvironmentType type;

  static Environment _current = const Environment._(EnvironmentType.prod);

  static Environment get current => _current;

  static Environment init(EnvironmentType type) {
    _current = Environment._(type);
    return _current;
  }

  bool get isDev => type == EnvironmentType.dev;
  bool get isProd => type == EnvironmentType.prod;

  String get appTitle => isProd ? 'Puchall' : 'Puchall DEV';

  Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await _loadEnv(type);
    if (AdConfig.supportsAds) {
      unawaited(_initializeMobileAds());
    }
    final preferences = await SharedPreferences.getInstance();
    final database = await openWorkoutSessionDatabase();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          workoutDatabaseProvider.overrideWithValue(database),
        ],
        child: const PuchallApp(),
      ),
    );
  }
}

Future<void> _loadEnv(EnvironmentType type) async {
  final fileName = switch (type) {
    EnvironmentType.dev => '.env.dev',
    EnvironmentType.prod => '.env.prod',
  };
  try {
    await dotenv.load(fileName: fileName);
  } catch (_) {
    // Local env files can be absent in tests or fresh checkouts.
  }
}

Future<void> _initializeMobileAds() async {
  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // Ads are optional; startup should not fail if the native plugin is absent.
  }
}
