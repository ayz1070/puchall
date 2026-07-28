import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class MainNavigationPage extends StatelessWidget {
  const MainNavigationPage({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  void _goToTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.daily);
        break;
      case 2:
        context.go(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (currentIndex) {
      1 => '데일리',
      2 => '마이페이지',
      _ => 'Puchall',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: currentIndex == 2
            ? [
                IconButton(
                  onPressed: () => context.push(AppRoutes.profileSettings),
                  icon: const Icon(Icons.settings),
                  tooltip: '설정',
                ),
              ]
            : null,
      ),
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: BottomNavigationBar(
              currentIndex: currentIndex.clamp(0, 2),
              onTap: (index) => _goToTab(context, index),
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: '',
                  tooltip: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  activeIcon: Icon(Icons.calendar_today),
                  label: '',
                  tooltip: '데일리',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: '',
                  tooltip: '마이페이지',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
