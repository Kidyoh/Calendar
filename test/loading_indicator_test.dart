import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/main.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  testWidgets('syncing never shifts the top bar; ring only for slow loads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
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
    await tester.pump(const Duration(milliseconds: 800));

    Rect where(String text) => tester.getRect(find.text(text));
    final widgetsPill = where('Widgets');
    final settings = tester.getRect(find.byTooltip('Settings'));

    repo.loading = true;
    repo.notifyListeners();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
    ); // quick loads: nothing
    expect(where('Widgets'), widgetsPill);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
    ); // slow: quiet ring
    expect(where('Widgets'), widgetsPill); // nothing moved
    expect(tester.getRect(find.byTooltip('Settings')), settings);

    repo.loading = false;
    repo.notifyListeners();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(where('Widgets'), widgetsPill);
  });
}
