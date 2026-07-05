import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';

class ProfileLocalDataSource {
  const ProfileLocalDataSource(this._preferences);

  final SharedPreferences _preferences;

  static const _profileKey = 'user_profile';

  Future<UserProfile> getProfile() async {
    final rawValue = _preferences.getString(_profileKey);
    if (rawValue == null) return UserProfile.defaultProfile;

    final json = jsonDecode(rawValue) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }
}
