import '../repositories/profile_repository.dart';

class ClearUserProfile {
  const ClearUserProfile(this._repository);

  final ProfileRepository _repository;

  Future<void> call() {
    return _repository.clearProfile();
  }
}
