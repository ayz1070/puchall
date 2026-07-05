import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class SaveUserProfile {
  const SaveUserProfile(this._repository);

  final ProfileRepository _repository;

  Future<void> call(UserProfile profile) {
    return _repository.saveProfile(profile);
  }
}
