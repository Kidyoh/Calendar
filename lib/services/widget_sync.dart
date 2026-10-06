import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/dates.dart';
import '../core/locale.dart';
import '../models/event_item.dart';

const iosAppGroup = 'group.com.kidyoh.glass_calendar';
const glassWidgetName = 'GlassWidgetProvider';
const islandWidgetName = 'IslandWidgetProvider';
const _androidPkg = 'com.kidyoh.glass_calendar';

/// Pure data builder (unit-testable): what the native home-screen widgets need.
///
/// The widgets compute the date / week strip themselves so they stay correct
/// across midnight; the app only supplies event counts and the next event.
Map<String, String> buildWidgetPayload(
  List<EventItem> events,
  DateTime now, {
  bool weekStartsMonday = true,
}) {
  final today = dateOnly(now);
  final counts = <String>[];
  for (var i = -7; i <= 21; i++) {
    final day = addDays(today, i);
    final n = events.where((e) => !e.isReminder && e.occursOn(day)).length;
    if (n > 0) counts.add('${dayKey(day)}:$n');
  }

  final upcoming =
      events
          .where((e) => !e.isReminder && e.end.isAfter(now) && !e.allDay)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  var nextTitle = '';
  var nextWhen = '';
  if (upcoming.isNotEmpty) {
    final e = upcoming.first;
    nextTitle = e.title;
    final d = dateOnly(e.start);
    final prefix = sameDay(d, today)
        ? t('Today')
        : sameDay(d, addDays(today, 1))
        ? t('Tomorrow')
        : weekdayShort(d, len: 3);
    nextWhen = '$prefix ${fmtTime(e.start)}';
  }

  return {
    'counts': counts.join(','),
    'next_title': nextTitle,
    'next_when': nextWhen,
    'week_monday': weekStartsMonday ? '1' : '0',
    'eth': AppLocale.ethiopian ? '1' : '0',
    'lang': AppLocale.lang,
    'label_new': '＋ ${t('New Event')}',
    'label_none': t('No upcoming events'),
    'label_event': t('event'),
    'label_events': t('events'),
  };
}

class WidgetSync {
  static bool _ready = false;

  static Future<void> push(
    List<EventItem> events, {
    bool weekStartsMonday = true,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_ready) {
        await HomeWidget.setAppGroupId(iosAppGroup);
        _ready = true;
      }
      final payload = buildWidgetPayload(
        events,
        DateTime.now(),
        weekStartsMonday: weekStartsMonday,
      );
      for (final e in payload.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: '$_androidPkg.$glassWidgetName',
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: '$_androidPkg.$islandWidgetName',
      );
    } catch (_) {
      // Home-screen widgets are best effort (desktop / tests have no host).
    }
  }

  static Future<bool> pin(String widgetClass) async {
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: '$_androidPkg.$widgetClass',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
