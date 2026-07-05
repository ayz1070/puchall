import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/profile_dependencies.dart';
import '../../domain/entities/user_profile.dart';

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final getProfile = ref.watch(getUserProfileUseCaseProvider);
  return getProfile();
});

final saveProfileProvider = FutureProvider.autoDispose
    .family<void, UserProfile>((ref, profile) async {
      final saveProfile = ref.watch(saveUserProfileUseCaseProvider);
      await saveProfile(profile);
      ref.invalidate(profileProvider);
    });
