import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'environment/environment.dart';

class PuchallApp extends ConsumerWidget {
  const PuchallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: Environment.current.appTitle,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
