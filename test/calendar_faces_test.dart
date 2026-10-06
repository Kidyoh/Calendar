import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/calendar_faces.dart';
import 'package:glass_calendar/core/hijri.dart';
import 'package:glass_calendar/core/locale.dart';
import 'package:glass_calendar/main.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:glass_calendar/widgets/face_pager.dart';
import 'package:glass_calendar/widgets/islands.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  tearDown(() {
    AppLocale.lang = 'en';
    AppLocale.ethiopian = false;
  });
  final d = DateTime(2026, 10, 6);

  test(
    'Hijri conversion round-trips and matches observed months within a day',
    () {
      for (
        var x = DateTime(2000, 1, 1);
        x.year < 2032;
        x = DateTime(x.year, x.month, x.day + 1)
      ) {
        final h = toHijri(x);
        expect(hijriToGregorian(h.year, h.month, h.day), x);
      }
      expect(
        toHijri(DateTime(2026, 2, 18)),
        const HijriDate(1447, 9, 1),
      ); // 1 Ramadan 1447
      expect(toHijri(d), const HijriDate(1448, 4, 23));
    },
  );

  test('each face describes the same day in its own calendar', () {
    final g = faceView(CalFace.gregorian, d);
    expect(g.title, 'October 2026');
    expect(g.day, '6');
    expect(g.line, 'Tuesday · Week 41');

    final e = faceView(CalFace.ethiopian, d);
    expect(e.title, 'Meskerem 2019 E.C.');
    expect(e.day, '26');
    expect(e.line2, 'Year of St. Luke');

    final i = faceView(CalFace.islamic, d);
    expect(i.title, startsWith('Rabiʿ al-Thani 1448'));
    expect(i.day, '23');
    expect(i.line, contains('ربيع الآخر'));
    expect(i.line2, isNotEmpty); // next Ramadan / Eid countdown

    final o = faceView(CalFace.orthodox, d);
    expect(o.day, '26');
    expect(o.line, 'No fast today'); // a Tuesday outside fasting seasons
    expect(o.line2, contains('Genna')); // next major feast countdown

    // Meskel: the feast is the headline, fast status underneath.
    final meskel = faceView(CalFace.orthodox, DateTime(2026, 9, 27));
    expect(meskel.line, contains('Meskel'));

    AppLocale.lang = 'am';
    expect(faceView(CalFace.ethiopian, d).title, 'መስከረም 2019 ዓ.ም');
    expect(faceView(CalFace.ethiopian, d).line2, 'ዘመነ ሉቃስ');
    expect(faceView(CalFace.islamic, d).title, 'ረቢዑል አኺር 1448');
  });

  test('week-strip day numbers per face', () {
    expect(faceDay(CalFace.gregorian, d), 6);
    expect(faceDay(CalFace.ethiopian, d), 26);
    expect(faceDay(CalFace.orthodox, d), 26);
    expect(faceDay(CalFace.islamic, d), 23);
  });

  testWidgets(
    'each widget keeps its own calendar; widgets can be added and removed',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      tzdata.initializeTimeZones();
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = CalendarRepository();
      await tester.runAsync(repo.init);
      repo.selectDay(d);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: repo,
          child: const GlassCalendarApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Widgets'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(repo.widgets.map((w) => w.id), [
        'glass-1',
        'island-1',
        'progress-1',
        'next-1',
      ]);
      expect(repo.faceOf('glass-1'), CalFace.gregorian);
      expect(repo.faceOf('island-1'), CalFace.gregorian);

      // Swipe the glass widget: only the glass widget changes.
      await tester.drag(find.byType(FacePager), const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(repo.faceOf('glass-1'), CalFace.ethiopian);
      expect(repo.faceOf('island-1'), CalFace.gregorian);
      expect(find.text('Meskerem 2019 E.C.'), findsWidgets); // glass
      // Scroll to the island: it still reads Gregorian.
      await tester.scrollUntilVisible(
        find.byType(IslandWeek),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.descendant(
          of: find.byType(IslandWeek),
          matching: find.text('October 2026'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byType(FacePager),
        -300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Wrap around both ways on the glass widget.
      for (final expected in [
        CalFace.islamic,
        CalFace.orthodox,
        CalFace.gregorian,
      ]) {
        await tester.drag(find.byType(FacePager), const Offset(-300, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(repo.faceOf('glass-1'), expected);
      }
      await tester.drag(find.byType(FacePager), const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(repo.faceOf('glass-1'), CalFace.orthodox);
      expect(repo.faceOf('island-1'), CalFace.gregorian);

      // Swipe the island: only the island changes.
      repo.cycleFaceFor('island-1', 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.faceOf('island-1'), CalFace.ethiopian);
      expect(repo.faceOf('glass-1'), CalFace.orthodox);

      // Add a second glass widget on the Islamic calendar.
      final id = await tester.runAsync(
        () => repo.addWidget('glass', face: CalFace.islamic),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(repo.widgets.length, 5);
      expect(repo.faceOf(id!), CalFace.islamic);
      expect(repo.faceOf('glass-1'), CalFace.orthodox);
      expect(tester.takeException(), isNull);

      // Remove it and undo.
      final removed = await tester.runAsync(() => repo.removeWidget(id));
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.widgets.length, 4);
      await tester.runAsync(() => repo.restoreWidget(removed!.$1, removed.$2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.faceOf(id), CalFace.islamic);

      // Everything persists.
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      final saved = prefs!.getString('widgets_v1')!;
      expect(saved, contains('"glass-1"'));
      expect(saved, contains('"island-1"'));
      expect(saved, contains(id));
      expect(tester.takeException(), isNull);
    },
  );
}
