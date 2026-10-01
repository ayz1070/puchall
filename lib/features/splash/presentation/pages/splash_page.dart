import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  var _isVisible = false;

  @override
  void initState() {
    super.initState();
    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    setState(() => _isVisible = true);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    setState(() => _isVisible = false);

    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: _SplashLogo(isVisible: _isVisible)),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: const Text(
        'PUCHALL',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.onBrandPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }
}
