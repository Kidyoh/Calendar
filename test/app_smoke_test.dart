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

  for (final (lang, eth) in const [('en', false), ('am', true), ('en', true)]) {
    testWidgets(
      'every tab, picker and editor lay out cleanly ($lang, ethiopian=$eth)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'onboarded': true,
          'language': lang,
          'ethiopian': eth,
        });
        tzdata.initializeTimeZones();
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final repo = CalendarRepository();
        await tester.runAsync(() async {
          await repo.init(); // no device plugin in tests -> local-only mode
          await repo.createEvent(
            title: 'Weekly sync with the design team',
            start: DateTime.now().copyWith(hour: 15, minute: 0),
            end: DateTime.now().copyWith(hour: 15, minute: 30),
          );
          await repo.addReminder(
            'Call Wiz',
            DateTime.now().copyWith(hour: 18, minute: 0),
          );
        });
        expect(AppLocale.lang, lang);
        expect(AppLocale.ethiopian, eth);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: repo,
            child: const GlassCalendarApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(t('Today')), findsWidgets);
        expect(find.text('Weekly sync with the design team'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(t('Calendar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        // Page through a year of months (crosses Pagume in Ethiopian mode).
        for (var i = 0; i < 13; i++) {
          repo.shiftMonth(1);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(t('Widgets')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(t('Weekly')), findsOneWidget);
        await tester.tap(find.text(t('Monthly')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip(t('New event')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text(t('Add event')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Calendar-aware date picker.
        await tester.tap(find.byIcon(Icons.event_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text(t('OK')), findsOneWidget);
        await tester.tap(find.byIcon(Icons.chevron_right).last);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
