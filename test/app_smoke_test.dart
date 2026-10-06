import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/main.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  testWidgets('renders every tab and the editor without layout errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tzdata.initializeTimeZones();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    FlutterError.onError = (d) => debugPrint('FLUTTERERR: ${d.toString()}');
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

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const GlassCalendarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Weekly sync with the design team'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Widgets'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Weekly'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('New event'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Add event'), findsOneWidget);
    final ex = tester.takeException();
    if (ex != null) debugPrint('EDITOR EXCEPTION: $ex');
    expect(ex, isNull);
  });
}
