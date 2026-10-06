import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/holidays.dart';
import '../core/locale.dart';
import '../core/theme.dart';
import '../models/event_item.dart';

/// What to remind about. Persisted by the repository.
class NotifySettings {
  bool events = true; // alert before events
  int eventLead = 10; // minutes before
  bool reminders = true;
  bool briefing = true; // morning summary
  int briefingHour = 7;
  int briefingMinute = 0;
  bool holidays = true; // holiday & fast lines in the morning
}

const _chEvents = 'events';
const _chReminders = 'reminders';
const _chBriefing = 'briefing';
const _icon = 'ic_stat_calendar';
const actionDone = 'done';
const actionSnooze = 'snooze';

/// Runs in a background isolate when "Done" / "Snooze" is tapped on a
/// reminder notification, even while the app is closed.
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(NotificationResponse r) async {
  await NotificationService.handleAction(r, background: true);
}

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Called by the app after a notification action changed stored reminders.
  static VoidCallback? onRemindersChanged;

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(
          tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
        );
      } catch (_) {}
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => handleAction(r),
        onDidReceiveBackgroundNotificationResponse:
            onNotificationActionInBackground,
      );
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chEvents,
          'Upcoming events',
          description: 'Alerts before your events',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chReminders,
          'Reminders',
          description: 'Your reminders, with Done and Snooze',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chBriefing,
          'Morning briefing',
          description: 'Your day, holidays and fasts each morning',
          importance: Importance.defaultImportance,
        ),
      );
      _ready = true;
    } catch (_) {}
  }

  /// Ask for notification (and, on Android 12+, exact-alarm) permission.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    try {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final ok = await android.requestNotificationsPermission() ?? false;
        if (!(await android.canScheduleExactNotifications() ?? true)) {
          await android.requestExactAlarmsPermission();
        }
        return ok;
      }
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------- details
  static NotificationDetails _details(
    String channel,
    Color color, {
    StyleInformation? style,
    List<AndroidNotificationAction>? actions,
    String? subText,
  }) {
    final names = {
      _chEvents: 'Upcoming events',
      _chReminders: 'Reminders',
      _chBriefing: 'Morning briefing',
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        names[channel]!,
        icon: _icon,
        color: color,
        colorized: false,
        importance: channel == _chBriefing
            ? Importance.defaultImportance
            : Importance.high,
        priority: channel == _chBriefing
            ? Priority.defaultPriority
            : Priority.high,
        category: channel == _chReminders
            ? AndroidNotificationCategory.reminder
            : AndroidNotificationCategory.event,
        styleInformation: style,
        actions: actions,
        subText: subText,
        groupKey: 'glass_calendar_$channel',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: channel != _chBriefing,
        threadIdentifier: channel,
        subtitle: subText,
      ),
    );
  }

  static List<AndroidNotificationAction> _reminderActions() => [
    AndroidNotificationAction(
      actionDone,
      '✓  ${t('Done')}',
      titleColor: const Color(0xFF2E7D32),
    ),
    AndroidNotificationAction(actionSnooze, '⏰  ${t('Snooze 10 min')}'),
  ];

  static int _id(String kind, String key) =>
      (('$kind:$key').hashCode & 0x0fffffff) | (kind == 'b' ? 0x10000000 : 0);

  // ----------------------------------------------------------- content
  static (String, String, StyleInformation) eventContent(
    EventItem e,
    int lead,
  ) {
    final when = e.allDay
        ? t('All day')
        : '${fmtTime(e.start)} – ${fmtTime(e.end)}';
    final body = [
      when,
      if (e.location?.isNotEmpty ?? false) e.location!,
    ].join('  ·  ');
    final head = lead <= 0
        ? t('Starting now')
        : (AppLocale.am ? 'በ$lead ደቂቃ ውስጥ' : 'In $lead min');
    return (
      e.title,
      '$head  ·  $body',
      BigTextStyleInformation(
        '$head  ·  $body',
        contentTitle: '<b>${_esc(e.title)}</b>',
        htmlFormatContentTitle: true,
      ),
    );
  }

  static (String, String, StyleInformation) briefingContent(
    DateTime day,
    List<EventItem> events, {
    bool withHolidays = true,
  }) {
    final timed = events.where((e) => !e.isReminder).toList()
      ..sort(compareEvents);
    final reminders = events.where((e) => e.isReminder && !e.done).length;
    final hello = AppLocale.am ? 'እንደምን አደሩ' : 'Good morning';
    final title =
        '$hello  ·  ${weekdayName(day)}, ${monthShort(day)} ${dayNum(day)}';
    final lines = <String>[];
    if (withHolidays) {
      for (final h in holidaysOn(day)) {
        lines.add('✦  ${h.name}');
      }
      final f = fastOn(day);
      if (f != null) {
        lines.add(
          '🌿  ${t('Fasting day')} · ${f.name}${f.progress == null ? '' : ' · ${f.progress}'}',
        );
      }
    }
    if (timed.isEmpty) {
      lines.add(t('A clear day. Enjoy it.'));
    } else {
      final n = timed.length;
      lines.add(
        '${AppLocale.am ? '$n ${t(n == 1 ? 'event' : 'events')}' : '$n ${n == 1 ? 'event' : 'events'}'} · ${t('first')}: ${timed.first.allDay ? t('All day') : fmtTime(timed.first.start)} ${timed.first.title}',
      );
      for (final e in timed.skip(1).take(3)) {
        lines.add('${e.allDay ? t('All day') : fmtTime(e.start)}  ${e.title}');
      }
    }
    if (reminders > 0) {
      lines.add(
        '🔔  $reminders ${t(reminders == 1 ? 'reminder' : 'reminders')}',
      );
    }
    return (
      title,
      lines.first,
      InboxStyleInformation(
        lines,
        contentTitle: '<b>${_esc(title)}</b>',
        htmlFormatContentTitle: true,
      ),
    );
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // ---------------------------------------------------------- schedule
  /// Cancel everything and schedule the next two weeks (max 60 alerts,
  /// soonest first — iOS keeps at most 64 pending).
  static Future<void> rescheduleAll(
    List<EventItem> all,
    NotifySettings s,
  ) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await plugin.cancelAllPendingNotifications();
      final now = DateTime.now();
      final horizon = now.add(const Duration(days: 14));
      final jobs = <(DateTime, Future<void> Function(DateTime))>[];

      if (s.events) {
        for (final e in all.where((e) => !e.isReminder && !e.allDay)) {
          final at = e.start.subtract(Duration(minutes: s.eventLead));
          if (at.isBefore(now) || at.isAfter(horizon)) continue;
          final (title, body, style) = eventContent(e, s.eventLead);
          jobs.add((
            at,
            (when) => _schedule(
              _id('e', '${e.id}@${e.start.millisecondsSinceEpoch}'),
              when,
              title,
              body,
              _details(_chEvents, paletteAt(e.colorIndex).fg, style: style),
              payload: 'event:${e.id}',
            ),
          ));
        }
      }
      if (s.reminders) {
        for (final r in all.where((e) => e.isReminder && !e.done)) {
          var at = r.start;
          if (r.repeat != Repeat.none) {
            while (at.isBefore(now)) {
              at = at.add(Duration(days: r.repeat == Repeat.daily ? 1 : 7));
            }
          }
          if (at.isBefore(now) ||
              at.isAfter(horizon.add(const Duration(days: 365)))) {
            continue;
          }
          jobs.add((
            at,
            (when) => _schedule(
              _id('r', r.id),
              when,
              '🔔  ${r.title}',
              fmtTime(at),
              _details(
                _chReminders,
                const Color(0xFFB7791F),
                actions: _reminderActions(),
                subText: t('Reminder'),
              ),
              payload: 'reminder:${r.id}',
              repeat: switch (r.repeat) {
                Repeat.daily => DateTimeComponents.time,
                Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
                Repeat.none => null,
              },
            ),
          ));
        }
      }
      if (s.briefing || s.holidays) {
        for (var i = 0; i < 14; i++) {
          final day = addDays(dateOnly(now), i);
          final at = DateTime(
            day.year,
            day.month,
            day.day,
            s.briefingHour,
            s.briefingMinute,
          );
          if (at.isBefore(now)) continue;
          final todays = all.where((e) => e.occursOn(day)).toList();
          final special =
              holidaysOn(day).isNotEmpty || fastOn(day)?.length != null;
          if (!s.briefing && !(s.holidays && special)) continue;
          final (title, body, style) = briefingContent(
            day,
            s.briefing ? todays : const [],
            withHolidays: s.holidays,
          );
          jobs.add((
            at,
            (when) => _schedule(
              _id('b', dayKey(day)),
              when,
              title,
              body,
              _details(_chBriefing, const Color(0xFF141414), style: style),
              payload: 'day:${dayKey(day)}',
            ),
          ));
        }
      }
      jobs.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (at, run) in jobs.take(60)) {
        await run(at);
      }
    } catch (_) {}
  }

  static Future<void> _schedule(
    int id,
    DateTime when,
    String title,
    String body,
    NotificationDetails d, {
    String? payload,
    DateTimeComponents? repeat,
  }) async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    await plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: d,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
      matchDateTimeComponents: repeat,
    );
  }

  /// A preview of each notification style, right now.
  static Future<void> showTest(List<EventItem> today) async {
    if (!supported) return;
    await init();
    final now = DateTime.now();
    final (bt, bb, bs) = briefingContent(dateOnly(now), today);
    await plugin.show(
      id: 1,
      title: bt,
      body: bb,
      notificationDetails: _details(
        _chBriefing,
        const Color(0xFF141414),
        style: bs,
      ),
    );
    final sample = EventItem(
      id: 'test',
      title: t('Design review'),
      start: now.add(const Duration(minutes: 10)),
      end: now.add(const Duration(minutes: 70)),
      location: 'Zoom',
      colorIndex: 0,
    );
    final (et, eb, es) = eventContent(sample, 10);
    await plugin.show(
      id: 2,
      title: et,
      body: eb,
      notificationDetails: _details(_chEvents, paletteAt(0).fg, style: es),
    );
    await plugin.show(
      id: 3,
      title: '🔔  ${t('Call Wiz')}',
      body: fmtTime(now),
      notificationDetails: _details(
        _chReminders,
        const Color(0xFFB7791F),
        actions: _reminderActions(),
        subText: t('Reminder'),
      ),
    );
  }

  // ------------------------------------------------------------ actions
  /// Done / Snooze straight from the notification. Works in the background
  /// isolate by editing the stored reminders directly.
  static Future<void> handleAction(
    NotificationResponse r, {
    bool background = false,
  }) async {
    final payload = r.payload ?? '';
    if (!payload.startsWith('reminder:')) return;
    final id = payload.substring('reminder:'.length);
    if (r.actionId != actionDone && r.actionId != actionSnooze) return;
    if (background) {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(
          tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
        );
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString('local_events');
    if (raw == null) return;
    final items = (jsonDecode(raw) as List)
        .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final i = items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final item = items[i];
    if (r.actionId == actionDone) {
      items[i] = item.repeat == Repeat.none
          ? item.copyWith(done: true)
          : item.copyWith(
              start: nextOccurrence(
                item,
                item.start.isAfter(DateTime.now())
                    ? item.start
                    : DateTime.now(),
              ),
              end: nextOccurrence(
                item,
                item.start.isAfter(DateTime.now())
                    ? item.start
                    : DateTime.now(),
              ),
            );
    } else {
      final when = DateTime.now().add(const Duration(minutes: 10));
      items[i] = item.copyWith(start: when, end: when);
      if (!_ready) await init();
      await _schedule(
        _id('r', item.id),
        when,
        '🔔  ${item.title}',
        fmtTime(when),
        _details(
          _chReminders,
          const Color(0xFFB7791F),
          actions: _reminderActions(),
          subText: t('Snoozed'),
        ),
        payload: 'reminder:${item.id}',
      );
    }
    await prefs.setString(
      'local_events',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    onRemindersChanged?.call();
  }

  /// Next time a repeating reminder is due after [after].
  static DateTime nextOccurrence(EventItem r, DateTime after) {
    var at = r.start;
    final step = Duration(days: r.repeat == Repeat.weekly ? 7 : 1);
    while (!at.isAfter(after)) {
      at = at.add(step);
    }
    return at;
  }
}
