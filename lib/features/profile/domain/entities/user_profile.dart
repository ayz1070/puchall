class UserProfile {
  const UserProfile({required this.name, required this.imagePath});

  final String name;
  final String imagePath;

  static const defaultProfile = UserProfile(
    name: 'Puchall User',
    imagePath: 'assets/images/default_profile.png',
  );

  Map<String, dynamic> toJson() {
    return {'name': name, 'imagePath': imagePath};
  }

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? defaultProfile.name,
      imagePath: json['imagePath'] as String? ?? defaultProfile.imagePath,
    );
  }
}
