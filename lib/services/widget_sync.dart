import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/calendar_faces.dart';
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
  String holidayToday = '',
  CalFace face = CalFace.gregorian,
}) {
  final today = dateOnly(now);
  // Per-day text of every calendar face (label/title/day/line), so the
  // home-screen widget can switch faces and stay right for two weeks.
  final faces = <String, List<List<String>>>{};
  for (var i = -1; i <= 14; i++) {
    final d = addDays(today, i);
    faces[dayKey(d)] = [
      for (final f in CalFace.values)
        () {
          final v = faceView(f, d);
          return [v.label, v.title, v.day, v.line, v.line2];
        }(),
    ];
  }
  // Day numbers per face for the week strip: "yyyymmdd:g,e,h,o;…"
  final faceDays = [
    for (var i = -8; i <= 21; i++)
      () {
        final d = addDays(today, i);
        return '${dayKey(d)}:${CalFace.values.map((f) => faceDay(f, d)).join(',')}';
      }(),
  ].join(';');
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
    'holiday': holidayToday,
    'face': '${face.index}',
    'faces': jsonEncode(faces),
    'face_days': faceDays,
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
    String holidayToday = '',
    CalFace face = CalFace.gregorian,
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
        holidayToday: holidayToday,
        face: face,
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

  /// Face chosen with ⇄ on the home screen (null when unavailable).
  static Future<int?> readFace() async {
    if (kIsWeb) return null;
    try {
      final v = await HomeWidget.getWidgetData<String>('face');
      return v == null ? null : int.tryParse(v);
    } catch (_) {
      return null;
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
