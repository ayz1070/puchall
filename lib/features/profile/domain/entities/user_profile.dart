class UserProfile {
  const UserProfile({
    required this.name,
    required this.imagePath,
    required this.weightKg,
  });

  final String name;
  final String imagePath;
  final double weightKg;

  static const defaultProfile = UserProfile(
    name: 'Puchall User',
    imagePath: 'assets/images/default_profile.png',
    weightKg: 70,
  );

  Map<String, dynamic> toJson() {
    return {'name': name, 'imagePath': imagePath, 'weightKg': weightKg};
  }

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? defaultProfile.name,
      imagePath: json['imagePath'] as String? ?? defaultProfile.imagePath,
      weightKg:
          (json['weightKg'] as num?)?.toDouble() ?? defaultProfile.weightKg,
    );
  }
}
