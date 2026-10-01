import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/di/workout_dependencies.dart';
import '../data/data_sources/profile_local_data_source.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/use_cases/clear_user_profile.dart';
import '../domain/use_cases/get_user_profile.dart';
import '../domain/use_cases/save_user_profile.dart';

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  return ProfileLocalDataSource(ref.watch(sharedPreferencesProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileLocalDataSourceProvider));
});

final getUserProfileUseCaseProvider = Provider<GetUserProfile>((ref) {
  return GetUserProfile(ref.watch(profileRepositoryProvider));
});

final saveUserProfileUseCaseProvider = Provider<SaveUserProfile>((ref) {
  return SaveUserProfile(ref.watch(profileRepositoryProvider));
});

final clearUserProfileUseCaseProvider = Provider<ClearUserProfile>((ref) {
  return ClearUserProfile(ref.watch(profileRepositoryProvider));
});
