class UserProfile {
  const UserProfile({
    required this.name,
    required this.imagePath,
    required this.weightKg,
    this.heightCm = 0,
  });

  final String name;
  final String imagePath;
  final double weightKg;

  /// 0이면 "입력 안 함". 러닝/워킹의 초기 보폭 추정에만 쓰이는 선택 입력이라
  /// 비워둬도 기존처럼 고정 기본값으로 동작한다.
  final double heightCm;

  static const defaultProfile = UserProfile(
    name: 'Puchall User',
    imagePath: 'assets/images/default_profile.png',
    weightKg: 70,
  );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imagePath': imagePath,
      'weightKg': weightKg,
      'heightCm': heightCm,
    };
  }

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? defaultProfile.name,
      imagePath: json['imagePath'] as String? ?? defaultProfile.imagePath,
      weightKg:
          (json['weightKg'] as num?)?.toDouble() ?? defaultProfile.weightKg,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
    );
  }
}
