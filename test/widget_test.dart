import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/dates.dart';
import 'package:glass_calendar/models/event_item.dart';
import 'package:glass_calendar/services/widget_sync.dart';

EventItem ev(
  String id,
  DateTime s,
  DateTime e, {
  bool allDay = false,
  bool reminder = false,
}) => EventItem(
  id: id,
  title: id,
  start: s,
  end: e,
  allDay: allDay,
  isReminder: reminder,
);

void main() {
  test('occursOn handles timed, all-day and multi-day events', () {
    final timed = ev(
      'a',
      DateTime(2026, 10, 7, 15),
      DateTime(2026, 10, 7, 15, 30),
    );
    expect(timed.occursOn(DateTime(2026, 10, 7)), isTrue);
    expect(timed.occursOn(DateTime(2026, 10, 8)), isFalse);

    // All-day events end at the next midnight (exclusive).
    final allDay = ev(
      'b',
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 8),
      allDay: true,
    );
    expect(allDay.occursOn(DateTime(2026, 10, 7)), isTrue);
    expect(allDay.occursOn(DateTime(2026, 10, 8)), isFalse);

    final multi = ev('c', DateTime(2026, 10, 6, 22), DateTime(2026, 10, 8, 2));
    expect(multi.occursOn(DateTime(2026, 10, 7)), isTrue);
    expect(multi.occursOn(DateTime(2026, 10, 8)), isTrue);
    expect(multi.occursOn(DateTime(2026, 10, 9)), isFalse);

    final reminder = ev(
      'd',
      DateTime(2026, 10, 7, 9),
      DateTime(2026, 10, 7, 9),
      reminder: true,
    );
    expect(reminder.occursOn(DateTime(2026, 10, 7)), isTrue);
  });

  test('startOfWeek respects week start', () {
    final tue = DateTime(2026, 10, 6); // Tuesday
    expect(startOfWeek(tue), DateTime(2026, 10, 5));
    expect(startOfWeek(tue, monday: false), DateTime(2026, 10, 4));
  });

  test('json round trip', () {
    final e = ev('x', DateTime(2026, 10, 7, 9), DateTime(2026, 10, 7, 10));
    final back = EventItem.fromJson(e.toJson());
    expect(back.title, 'x');
    expect(back.start, e.start);
  });

  test('widget payload carries counts and the next event', () {
    final now = DateTime(2026, 10, 6, 12);
    final p = buildWidgetPayload([
      ev('Standup', DateTime(2026, 10, 6, 9), DateTime(2026, 10, 6, 9, 30)),
      ev('Lunch', DateTime(2026, 10, 6, 13), DateTime(2026, 10, 6, 14)),
      ev('Review', DateTime(2026, 10, 7, 10), DateTime(2026, 10, 7, 11)),
    ], now);
    expect(p['counts'], contains('20261006:2'));
    expect(p['counts'], contains('20261007:1'));
    expect(p['next_title'], 'Lunch');
    expect(p['next_when'], startsWith('Today'));
  });
}
