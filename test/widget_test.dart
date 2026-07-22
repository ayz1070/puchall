import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puchall/app.dart';
import 'package:puchall/environment/environment.dart';
import 'package:puchall/environment/environment_type.dart';
import 'package:puchall/features/workout/di/workout_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const defaultProfileJson =
      '{"name":"Puchall User","imagePath":"assets/images/default_profile.png"}';

  testWidgets('starts onboarding at intro when profile is missing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_step': 'profile'});
    final preferences = await SharedPreferences.getInstance();
    Environment.init(EnvironmentType.prod);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PuchallApp(),
      ),
    );

    expect(find.text('PUCHALL'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('PUCHALL 시작하기'), findsOneWidget);
    expect(find.text('프로필 설정'), findsNothing);

    await tester.tap(find.text('PUCHALL 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'New User');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('푸쉬업 측정'), findsOneWidget);
    expect(preferences.getString('onboarding_step'), 'push_up_threshold');
    expect(preferences.getString('user_profile'), contains('New User'));
  });

  testWidgets('goes home after splash when profile exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_step': 'completed',
      'user_profile': defaultProfileJson,
    });
    final preferences = await SharedPreferences.getInstance();
    Environment.init(EnvironmentType.prod);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PuchallApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Puchall'), findsOneWidget);
    expect(find.text('PUSH UP'), findsOneWidget);
    expect(find.text('프로필 설정'), findsNothing);
  });

  testWidgets(
    'continues onboarding when profile exists but setup is incomplete',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_step': 'push_up_threshold',
        'user_profile': defaultProfileJson,
      });
      final preferences = await SharedPreferences.getInstance();
      Environment.init(EnvironmentType.prod);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: const PuchallApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pumpAndSettle();

      expect(find.text('푸쉬업 측정'), findsOneWidget);
      expect(find.text('Puchall'), findsNothing);
    },
  );

  testWidgets('skips onboarding threshold setup in order', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_step': 'push_up_threshold',
      'user_profile': defaultProfileJson,
    });
    final preferences = await SharedPreferences.getInstance();
    Environment.init(EnvironmentType.prod);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PuchallApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('푸쉬업 측정'), findsOneWidget);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.text('풀업 측정'), findsOneWidget);
    expect(preferences.getString('onboarding_step'), 'pull_up_threshold');

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.text('Puchall'), findsOneWidget);
    expect(preferences.getString('onboarding_step'), 'completed');
  });

  testWidgets('shows home and profile tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_step': 'completed',
      'user_profile': defaultProfileJson,
    });
    final preferences = await SharedPreferences.getInstance();
    Environment.init(EnvironmentType.prod);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PuchallApp(),
      ),
    );

    expect(find.text('PUCHALL'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Puchall'), findsOneWidget);
    expect(find.text('PUSH UP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Puchall User'), findsOneWidget);
    expect(find.text('데일리'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.text('데일리'));
    await tester.pumpAndSettle();

    expect(find.text('운동 기록'), findsOneWidget);
    expect(find.text('일'), findsOneWidget);
    expect(find.text('월'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.text('운동 기록 삭제'), findsOneWidget);

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    expect(find.text('사용자 이름'), findsOneWidget);
  });
}
