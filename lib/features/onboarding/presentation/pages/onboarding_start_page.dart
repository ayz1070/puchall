import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/onboarding_step.dart';
import '../viewmodels/onboarding_view_model.dart';

class OnboardingStartPage extends ConsumerStatefulWidget {
  const OnboardingStartPage({super.key});

  @override
  ConsumerState<OnboardingStartPage> createState() =>
      _OnboardingStartPageState();
}

class _OnboardingStartPageState extends ConsumerState<OnboardingStartPage> {
  late final VideoPlayerController _videoController;
  var _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/bg_login.mp4')
      ..setLooping(true)
      ..setVolume(0);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _isVideoReady = true);
    await _videoController.play();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await ref
        .read(onboardingStepProvider.notifier)
        .setStep(OnboardingStep.profile);
    if (!mounted) return;
    context.go(AppRoutes.onboardingProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            Image.asset('assets/images/bg_login_poster.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x88000000), Color(0xEE000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    'PUCHALL',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'PUCHALL 시작하기',
                    icon: Icons.arrow_forward,
                    onPressed: _start,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
