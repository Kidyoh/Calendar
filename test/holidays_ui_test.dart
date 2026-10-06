import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/holidays.dart';
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

  for (final lang in ['en', 'am']) {
    testWidgets('holiday and fasting banners render ($lang)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'language': lang,
        'ethiopian': lang == 'am',
      });
      tzdata.initializeTimeZones();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = CalendarRepository();
      await tester.runAsync(repo.init);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: repo,
          child: const GlassCalendarApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      repo.selectDay(DateTime(2026, 9, 27)); // Meskel
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text(lang == 'am' ? 'መስቀል' : 'Meskel'), findsOneWidget);
      expect(tester.takeException(), isNull);

      repo.selectDay(DateTime(2026, 2, 20)); // Abiy Tsom, day 5
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        find.textContaining(lang == 'am' ? 'ዐቢይ ጾም' : 'Abiy Tsom'),
        findsOneWidget,
      );
      expect(
        find.text(lang == 'am' ? 'ቀን 5 ከ 55' : 'Day 5 of 55'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Calendar tab with the month's holiday list.
      await tester.tap(find.text(t('Calendar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text(t('Holidays & fasts').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Turning Orthodox off hides the fast.
      await tester.tap(find.text(t('Today')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => repo.setHolidayCategory(HolidayKind.orthodox, false),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.textContaining(lang == 'am' ? 'ዐቢይ ጾም' : 'Abiy Tsom'),
        findsNothing,
      );
    });
  }
}
