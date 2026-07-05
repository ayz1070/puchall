import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/user_profile.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(UserProfile currentProfile) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updatedProfile = UserProfile(
      name: name,
      imagePath: currentProfile.imagePath,
    );

    await ref.read(saveProfileProvider(updatedProfile).future);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('프로필 수정')),
      body: SafeArea(
        child: profile.when(
          data: (value) {
            if (_nameController.text.isEmpty) {
              _nameController.text = value.name;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text('이름', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _nameController,
                  label: '사용자 이름',
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: '저장',
                  icon: Icons.save,
                  onPressed: () => _save(value),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Padding(
            padding: EdgeInsets.all(20),
            child: Text('프로필을 불러오지 못했습니다.', style: AppTextStyles.body),
          ),
        ),
      ),
    );
  }
}
