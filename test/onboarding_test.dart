import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/main.dart';
import 'package:glass_calendar/screens/home_shell.dart';
import 'package:glass_calendar/screens/onboarding.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  testWidgets('first launch shows onboarding; finishing it lands on home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tzdata.initializeTimeZones();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = CalendarRepository();
    await tester.runAsync(repo.init);
    expect(repo.onboarded, isFalse);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const GlassCalendarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.textContaining('Your days'), findsOneWidget);

    // Walk through every page with the arrow button.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Connect my calendars'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Maybe later'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
    expect(repo.onboarded, isTrue);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
