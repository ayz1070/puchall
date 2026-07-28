import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$name님',
      style: AppTextStyles.titleMedium,
      overflow: TextOverflow.ellipsis,
    );
  }
}
