import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../core/calendar_faces.dart';
import '../core/dates.dart';
import '../core/ethiopian.dart';
import '../core/hijri.dart';
import '../core/holidays.dart';
import '../core/theme.dart';
import '../core/locale.dart';
import '../models/event_item.dart';

const iosAppGroup = 'group.com.kidyoh.glass_calendar';
const glassWidgetName = 'GlassWidgetProvider';
const islandWidgetName = 'IslandWidgetProvider';
const dateWidgetName = 'DateWidgetProvider';
const progressWidgetName = 'ProgressWidgetProvider';
const nextWidgetName = 'NextWidgetProvider';
const feastsWidgetName = 'FeastsWidgetProvider';
const allWidgetNames = [
  glassWidgetName,
  islandWidgetName,
  dateWidgetName,
  progressWidgetName,
  nextWidgetName,
  feastsWidgetName,
];
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
  List<Holiday> Function(DateTime day)? holidays,
  FastDay? Function(DateTime day)? fasts,
}) {
  final today = dateOnly(now);
  final extra = _extraPayload(
    events,
    now,
    holidays: holidays ?? (_) => const [],
    fasts: fasts ?? (_) => null,
  );
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
    for (var i = -45; i <= 80; i++)
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
    ...extra,
  };
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Month grids, agenda, feasts, fasts and labels for the customizable
/// home-screen widgets (month / agenda / date / progress / next / feasts).
Map<String, String> _extraPayload(
  List<EventItem> events,
  DateTime now, {
  required List<Holiday> Function(DateTime day) holidays,
  required FastDay? Function(DateTime day) fasts,
}) {
  final today = dateOnly(now);

  // Months per face overlapping the cached range: [startKey, length, title].
  final months = <List<List<Object>>>[];
  final years = <List<Object>>[];
  for (final f in CalFace.values) {
    final list = <List<Object>>[];
    var start = faceMonth(f, addDays(today, -45)).$1;
    while (start.isBefore(addDays(today, 81))) {
      final len = faceMonth(f, start).$2;
      list.add([dayKey(start), len, faceView(f, start).title]);
      start = addDays(start, len);
    }
    months.add(list);
    // Current year in this face: [startKey, endKey, title, months].
    final (ys, ye) = faceYear(f, today);
    years.add([
      dayKey(ys),
      dayKey(ye),
      switch (f) {
        CalFace.gregorian => '${today.year}',
        CalFace.ethiopian || CalFace.orthodox =>
          '${toEthiopian(today).year} ${AppLocale.am ? 'ዓ.ም' : 'E.C.'}',
        CalFace.islamic => '${toHijri(today).year}${AppLocale.am ? '' : ' AH'}',
      },
      f == CalFace.ethiopian || f == CalFace.orthodox ? 13 : 12,
    ]);
  }

  // Agenda: upcoming events and holidays for three weeks.
  final agenda = <List<Object>>[];
  for (var i = 0; i < 21 && agenda.length < 14; i++) {
    final day = addDays(today, i);
    for (final h in holidays(day)) {
      agenda.add([dayKey(day), '★', h.name, '#FFE08A84', 0, 0, 1]);
    }
    final list = events.where((e) => !e.isReminder && e.occursOn(day)).toList()
      ..sort(compareEvents);
    for (final e in list) {
      if (!sameDay(dateOnly(e.start), day) && !e.allDay) continue;
      agenda.add([
        dayKey(day),
        e.allDay ? t('All day') : fmtTime(e.start),
        e.title,
        _hex(paletteAt(e.colorIndex).bg),
        e.start.millisecondsSinceEpoch,
        e.end.millisecondsSinceEpoch,
        e.allDay ? 1 : 0,
      ]);
    }
  }

  // Feasts: the next holidays (honouring the user's filters).
  final feasts = <List<Object>>[];
  final holDays = <String>[];
  for (var i = -45; i <= 200; i++) {
    final day = addDays(today, i);
    final List<Holiday> hs = (i <= 80 || feasts.length < 8)
        ? holidays(day)
        : const [];
    if (hs.isEmpty) continue;
    if (i <= 80) holDays.add(dayKey(day));
    if (i >= 0 && feasts.length < 8) {
      for (final h in hs) {
        feasts.add([dayKey(day), h.name, h.kind.name, h.dayOff ? 1 : 0]);
      }
    }
  }
  final fastList = <String>[];
  for (var i = -1; i <= 60; i++) {
    final day = addDays(today, i);
    final f = fasts(day);
    if (f != null) {
      fastList.add(
        '${dayKey(day)}=${f.name}${f.progress == null ? '' : ' · ${f.progress}'}',
      );
    }
  }

  final am = AppLocale.am;
  return {
    'face_months': jsonEncode(months),
    'face_years': jsonEncode(years),
    'agenda': jsonEncode(agenda),
    'feasts': jsonEncode(feasts),
    'hol_days': holDays.join(','),
    'fasts': fastList.join(';'),
    'label_today': t('Today'),
    'label_tomorrow': t('Tomorrow'),
    'label_today_l': t('today'),
    'label_tomorrow_l': t('tomorrow'),
    'label_in_days': am ? 'በ%d ቀን ውስጥ' : 'in %d days',
    'label_days_left': am ? '%d ቀናት ቀርተዋል' : '%d days left',
    'label_left': am ? '%s ቀርቷል' : '%s left',
    'label_in': am ? 'በ%s ውስጥ' : 'in %s',
    'label_h': am ? 'ሰዓት' : 'h',
    'label_min': am ? 'ደ' : 'm',
    'label_day': t('Day'),
    'label_week': t('Week'),
    'label_next': t('Next up'),
    'label_now': t('happening now'),
    'label_clear': t('All clear — nothing coming up'),
    'label_no_fast': t('No fast today'),
    'label_feasts': t('Feasts & fasts'),
    'label_agenda': t('Agenda'),
    'label_no_holidays': t('No holidays'),
    'face_names': [for (final f in CalFace.values) faceLabel(f)].join('|'),
  };
}

class WidgetSync {
  static bool _ready = false;

  static Future<void> push(
    List<EventItem> events, {
    bool weekStartsMonday = true,
    String holidayToday = '',
    CalFace face = CalFace.gregorian,
    List<Holiday> Function(DateTime day)? holidays,
    FastDay? Function(DateTime day)? fasts,
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
        holidays: holidays,
        fasts: fasts,
      );
      for (final e in payload.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      for (final name in allWidgetNames) {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: '$_androidPkg.$name',
        );
      }
    } catch (_) {
      // Home-screen widgets are best effort (desktop / tests have no host).
    }
  }

  static const _channel = MethodChannel('glass_calendar/widgets');

  /// Asks the launcher to add a widget of [type] to the home screen, set up
  /// with this [face], [view] and [style] (empty = the widget's defaults).
  /// Returns true when the launcher's "Add widget" prompt was shown; false
  /// when this launcher can't add widgets from apps (the settings are still
  /// remembered, so a widget added from the widget picker starts with them).
  static Future<bool> pin(
    String type, {
    CalFace face = CalFace.gregorian,
    String view = '',
    String style = '',
  }) async {
    if (kIsWeb) return false;
    try {
      final r = await _channel.invokeMethod<String>('pin', {
        'type': type,
        'face': face.index,
        'view': view,
        'style': style,
      });
      return r == 'requested';
    } catch (_) {
      return false;
    }
  }
}
