import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puchall/app.dart';
import 'package:puchall/environment/environment.dart';
import 'package:puchall/environment/environment_type.dart';
import 'package:puchall/features/workout/di/workout_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows home and profile tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.text('운동 기록 삭제'), findsOneWidget);

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    expect(find.text('사용자 이름'), findsOneWidget);
  });
}
