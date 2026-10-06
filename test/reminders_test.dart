import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/locale.dart';
import 'package:glass_calendar/main.dart';
import 'package:glass_calendar/models/event_item.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:glass_calendar/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  tearDown(() {
    AppLocale.lang = 'en';
    AppLocale.ethiopian = false;
  });

  test('repeat survives JSON and next occurrence moves forward', () {
    final r = EventItem(
      id: 'r1',
      title: 'Water plants',
      start: DateTime(2026, 10, 6, 8),
      end: DateTime(2026, 10, 6, 8),
      isReminder: true,
      repeat: Repeat.weekly,
    );
    expect(EventItem.fromJson(r.toJson()).repeat, Repeat.weekly);
    expect(
      NotificationService.nextOccurrence(r, DateTime(2026, 10, 6, 9)),
      DateTime(2026, 10, 13, 8),
    );
    final daily = r.copyWith(repeat: Repeat.daily);
    expect(
      NotificationService.nextOccurrence(daily, DateTime(2026, 10, 8, 7)),
      DateTime(2026, 10, 8, 8),
    );
  });

  test('notification content: event alert and morning briefing with feast and fast', () {
    final e = EventItem(
      id: 'e',
      title: 'Design review',
      start: DateTime(2026, 2, 20, 10),
      end: DateTime(2026, 2, 20, 11),
      location: 'Zoom',
    );
    final (title, body, _) = NotificationService.eventContent(e, 10);
    expect(title, 'Design review');
    expect(body, 'In 10 min  ·  10:00 AM – 11:00 AM  ·  Zoom');

    final (bt, _, bs) = NotificationService.briefingContent(
      DateTime(2026, 2, 20),
      [e],
    );
    expect(bt, startsWith('Good morning'));
    final lines = (bs as dynamic).lines as List<String>;
    expect(
      lines.any((l) => l.contains('Abiy Tsom') && l.contains('Day 5 of 55')),
      isTrue,
    );
    expect(
      lines.any((l) => l.contains('1 event') && l.contains('Design review')),
      isTrue,
    );

    AppLocale.lang = 'am';
    final (amTitle, _, _) = NotificationService.briefingContent(
      DateTime(2026, 9, 27),
      const [],
    );
    expect(amTitle, startsWith('እንደምን አደሩ'));
  });

  testWidgets('reminders sheet: quick add, complete, repeat, snooze', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    tzdata.initializeTimeZones();
    tester.view.physicalSize = const Size(1170, 2532);
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

    await tester.tap(find.text('Reminders'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Remind me to…'), findsOneWidget);

    // Quick add "Call mom" in 1 hour, daily.
    await tester.enterText(find.byType(TextField), 'Call mom');
    await tester.pump();
    await tester.tap(find.text('Daily'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Add reminder'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 700));
    expect(repo.reminders.single.title, 'Call mom');
    expect(repo.reminders.single.repeat, Repeat.daily);
    expect(find.text('Call mom'), findsWidgets); // sheet + Today list
    expect(tester.takeException(), isNull);

    // Completing a daily reminder moves it to the next day instead of ticking it off.
    final before = repo.reminders.single.start;
    await tester.runAsync(() => repo.toggleDone(repo.reminders.single));
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.reminders.single.done, isFalse);
    expect(repo.reminders.single.start.isAfter(before), isTrue);

    // A one-off reminder completes and lands under Completed.
    await tester.runAsync(
      () => repo.addReminder(
        'Pay rent',
        DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final rent = repo.reminders.firstWhere((r) => r.title == 'Pay rent');
    await tester.runAsync(
      () => repo.snoozeReminder(rent, const Duration(hours: 1)),
    );
    final snoozed = repo.reminders.firstWhere((r) => r.title == 'Pay rent');
    expect(snoozed.start.isAfter(rent.start), isTrue);
    await tester.runAsync(() => repo.toggleDone(snoozed));
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      repo.reminders.firstWhere((r) => r.title == 'Pay rent').done,
      isTrue,
    );
    expect(find.textContaining('COMPLETED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
