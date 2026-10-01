import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetUserProfile {
  const GetUserProfile(this._repository);

  final ProfileRepository _repository;

  Future<UserProfile> call() {
    return _repository.getProfile();
  }
}
