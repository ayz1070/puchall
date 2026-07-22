import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import 'environment_type.dart';
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
    final preferences = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PuchallApp(),
      ),
    );
  }
}
