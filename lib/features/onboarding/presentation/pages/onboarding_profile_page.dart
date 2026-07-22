import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../profile/di/profile_dependencies.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/viewmodels/profile_view_model.dart';
import '../../domain/entities/onboarding_step.dart';
import '../viewmodels/onboarding_view_model.dart';

class OnboardingProfilePage extends ConsumerStatefulWidget {
  const OnboardingProfilePage({super.key});

  @override
  ConsumerState<OnboardingProfilePage> createState() =>
      _OnboardingProfilePageState();
}

class _OnboardingProfilePageState extends ConsumerState<OnboardingProfilePage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: UserProfile.defaultProfile.name,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final profile = UserProfile(
      name: name,
      imagePath: UserProfile.defaultProfile.imagePath,
    );
    await ref.read(saveUserProfileUseCaseProvider)(profile);
    ref.invalidate(profileProvider);
    await ref
        .read(onboardingStepProvider.notifier)
        .setStep(OnboardingStep.pushUpThreshold);
    if (!mounted) return;
    context.go(AppRoutes.onboardingPushUpThreshold);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text('기본 프로필 입력', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            const Text('운동 기록에 표시할 이름을 입력해주세요.', style: AppTextStyles.body),
            const SizedBox(height: 18),
            AppTextField(
              controller: _nameController,
              label: '사용자 이름',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            AppButton(label: '다음', icon: Icons.arrow_forward, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
