import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../data_sources/profile_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dataSource);

  final ProfileLocalDataSource _dataSource;

  @override
  Future<UserProfile> getProfile() {
    return _dataSource.getProfile();
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    return _dataSource.saveProfile(profile);
  }
}
