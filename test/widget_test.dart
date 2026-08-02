import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puchall/app.dart';
import 'package:puchall/environment/environment.dart';
import 'package:puchall/environment/environment_type.dart';
import 'package:puchall/features/workout/data/data_sources/workout_session_database.dart';
import 'package:puchall/features/workout/di/workout_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const defaultProfileJson =
      '{"name":"Puchall User","imagePath":"assets/images/default_profile.png","weightKg":70}';

  testWidgets('starts onboarding at intro when profile is missing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_step': 'profile'});
    final preferences = await SharedPreferences.getInstance();
    Environment.init(EnvironmentType.prod);
    late final Database database;
    await tester.runAsync(() async {
      database = await openWorkoutSessionDatabase(path: inMemoryDatabasePath);
    });
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          workoutDatabaseProvider.overrideWithValue(database),
        ],
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

    await tester.enterText(find.byType(TextField).at(0), 'New User');
    await tester.enterText(find.byType(TextField).at(1), '72');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('푸쉬업 측정'), findsOneWidget);
    expect(preferences.getString('onboarding_step'), 'push_up_threshold');
    expect(preferences.getString('user_profile'), contains('New User'));
    expect(preferences.getString('user_profile'), contains('"weightKg":72'));
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
    late final Database database;
    await tester.runAsync(() async {
      database = await openWorkoutSessionDatabase(path: inMemoryDatabasePath);
    });
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          workoutDatabaseProvider.overrideWithValue(database),
        ],
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
      late final Database database;
      await tester.runAsync(() async {
        database = await openWorkoutSessionDatabase(path: inMemoryDatabasePath);
      });
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            workoutDatabaseProvider.overrideWithValue(database),
          ],
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
    late final Database database;
    await tester.runAsync(() async {
      database = await openWorkoutSessionDatabase(path: inMemoryDatabasePath);
    });
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          workoutDatabaseProvider.overrideWithValue(database),
        ],
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
    late final Database database;
    await tester.runAsync(() async {
      database = await openWorkoutSessionDatabase(path: inMemoryDatabasePath);
    });
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          workoutDatabaseProvider.overrideWithValue(database),
        ],
        child: const PuchallApp(),
      ),
    );

    expect(find.text('PUCHALL'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Puchall'), findsOneWidget);
    expect(find.text('PUSH UP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pump();
    // 데일리 화면은 SQLite에서 세션을 비동기로 읽어온 뒤에야 그려진다. pumpAndSettle은
    // FakeAsync 클럭만 넘기므로, 실제 isolate 통신이 끝날 시간을 real 존에서 확보해준다.
    // (pump 계열 메서드는 runAsync 콜백 안에서 호출하면 안 되므로 밖에서 이어서 부른다.)
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('데일리'), findsWidgets);
    expect(find.text('일'), findsOneWidget);
    expect(find.text('월'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Puchall User님'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.text('운동 기록 삭제'), findsOneWidget);

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    expect(find.text('사용자 이름'), findsOneWidget);
    expect(find.text('체중(kg)'), findsOneWidget);
  });
}
