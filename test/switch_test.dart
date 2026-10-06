import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/locale.dart';
import 'package:glass_calendar/main.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  tearDown(() {
    AppLocale.lang = 'en';
    AppLocale.ethiopian = false;
  });

  testWidgets(
    'switching language and calendar from Settings keeps the app intact',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      tzdata.initializeTimeZones();
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = CalendarRepository();
      await tester.runAsync(() async {
        await repo.init();
        await repo.createEvent(
          title: 'AI-team daily',
          start: DateTime.now().copyWith(hour: 9, minute: 0),
          end: DateTime.now().copyWith(hour: 9, minute: 15),
        );
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: repo,
          child: const GlassCalendarApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      // Go to the Calendar tab first: switching language must not reset it.
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('አማርኛ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text('ቅንብሮች'), findsOneWidget); // sheet title now Amharic
      expect(find.byType(ErrorWidget), findsNothing);

      await tester.tap(find.textContaining('ኢትዮጵያዊ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);

      // Close the sheet: home must be fully translated, still on the Calendar tab.
      await tester.tapAt(const Offset(200, 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      expect(find.text('ቀን መቁጠሪያ'), findsOneWidget);
      expect(find.text('Calendar'), findsNothing);
      expect(find.text('መስከረም'), findsWidgets); // month switcher in Ethiopian
      expect(find.byType(ErrorWidget), findsNothing);
    },
  );
}
