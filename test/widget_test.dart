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
    await tester.pumpAndSettle();

    expect(find.text('Puchall'), findsOneWidget);
    expect(find.text('푸쉬업'), findsOneWidget);

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();

    expect(find.text('Puchall User'), findsOneWidget);
    expect(find.text('프로필 수정'), findsOneWidget);

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    expect(find.text('사용자 이름'), findsOneWidget);
  });
}
