import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';

class ProfileLocalDataSource {
  const ProfileLocalDataSource(this._preferences);

  final SharedPreferences _preferences;

  static const _profileKey = 'user_profile';

  bool hasProfile() {
    return _preferences.containsKey(_profileKey);
  }

  Future<UserProfile> getProfile() async {
    final rawValue = _preferences.getString(_profileKey);
    if (rawValue == null) return UserProfile.defaultProfile;

    try {
      final json = jsonDecode(rawValue) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } on FormatException {
      return UserProfile.defaultProfile;
    } on TypeError {
      return UserProfile.defaultProfile;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearProfile() async {
    await _preferences.remove(_profileKey);
  }
}
