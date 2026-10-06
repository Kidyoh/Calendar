import 'dart:convert';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dates.dart';
import '../core/locale.dart';
import '../models/event_item.dart';
import 'widget_sync.dart';

/// A world-clock choice for the second clock on the Today screen.
const zoneChoices = <String, String>{
  'America/New_York': 'New York',
  'America/Los_Angeles': 'Los Angeles',
  'Europe/London': 'United Kingdom',
  'Europe/Paris': 'Paris',
  'Africa/Lagos': 'Lagos',
  'Africa/Nairobi': 'Nairobi',
  'Asia/Dubai': 'Dubai',
  'Asia/Kolkata': 'India',
  'Asia/Singapore': 'Singapore',
  'Asia/Tokyo': 'Tokyo',
  'Australia/Sydney': 'Sydney',
};

/// Single source of truth: merges the phone's calendars (synced with Google,
/// iCloud, Outlook, … through the OS accounts) with app-local entries.
class CalendarRepository extends ChangeNotifier {
  CalendarRepository({DeviceCalendar? plugin})
    : _plugin = plugin ?? DeviceCalendar.instance;

  final DeviceCalendar _plugin;
  SharedPreferences? _prefs;

  List<EventItem> _local = [];
  List<EventItem> _device = [];
  List<Calendar> calendars = [];
  Set<String> hiddenCalendarIds = {};

  CalendarPermissionStatus permission = CalendarPermissionStatus.notDetermined;
  bool deviceSyncSupported = true;
  bool loading = false;
  String? lastError;

  late DateTime selectedDay = dateOnly(DateTime.now());
  late DateTime focusedMonth = monthStart(selectedDay);

  String secondZone = 'America/New_York';
  String localZoneId = 'UTC';
  bool weekStartsMonday = true;
  bool onboarded = false;
  String get language => AppLocale.lang;
  bool get ethiopian => AppLocale.ethiopian;
  String? defaultCalendarId;

  bool get hasDeviceAccess => permission == CalendarPermissionStatus.granted;
  String get secondZoneLabel => zoneChoices[secondZone] ?? secondZone;
  String get localZoneLabel => localZoneId.split('/').last.replaceAll('_', ' ');

  List<Calendar> get writableCalendars =>
      calendars.where((c) => !c.readOnly).toList();

  List<EventItem> get allEvents => [..._device, ..._local];

  // ---------------------------------------------------------------- init
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('local_events');
    if (raw != null) {
      try {
        _local = (jsonDecode(raw) as List)
            .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _local = [];
      }
    }
    hiddenCalendarIds = (_prefs!.getStringList('hidden_calendars') ?? [])
        .toSet();
    secondZone = _prefs!.getString('second_zone') ?? secondZone;
    weekStartsMonday = _prefs!.getBool('week_monday') ?? true;
    onboarded = _prefs!.getBool('onboarded') ?? false;
    // First run on an Amharic phone defaults to Amharic + Ethiopian calendar.
    final amPhone = PlatformDispatcher.instance.locale.languageCode == 'am';
    AppLocale.lang = _prefs!.getString('language') ?? (amPhone ? 'am' : 'en');
    AppLocale.ethiopian = _prefs!.getBool('ethiopian') ?? amPhone;
    focusedMonth = monthStart(selectedDay);
    defaultCalendarId = _prefs!.getString('default_calendar');
    try {
      localZoneId = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    await refreshPermission();
    await reload();
  }

  Future<void> refreshPermission() async {
    try {
      permission = await _plugin.hasPermissions();
      deviceSyncSupported = true;
    } catch (_) {
      permission = CalendarPermissionStatus.denied;
      deviceSyncSupported = false;
    }
  }

  /// Ask the OS for calendar access, then pull everything in.
  Future<void> connectDeviceCalendars() async {
    try {
      permission = await _plugin.requestPermissions();
    } catch (e) {
      lastError = 'Calendar access is unavailable on this device.';
      deviceSyncSupported = false;
    }
    await reload();
  }

  Future<void> openSystemSettings() async {
    try {
      await _plugin.openAppSettings();
    } catch (_) {}
  }

  // -------------------------------------------------------------- loading
  Future<void> reload() async {
    loading = true;
    notifyListeners();
    if (hasDeviceAccess) {
      try {
        calendars = (await _plugin.listCalendars())
            .where((c) => !c.hidden)
            .toList();
        final today = dateOnly(DateTime.now());
        final from = minDate(addDays(focusedMonth, -35), addDays(today, -8));
        final to = maxDate(addDays(focusedMonth, 70), addDays(today, 22));
        final visible = calendars
            .where((c) => !hiddenCalendarIds.contains(c.id))
            .toList();
        if (visible.isEmpty) {
          _device = [];
        } else {
          final byId = {for (final c in visible) c.id: c};
          final raw = await _plugin.listEvents(
            from,
            to,
            calendarIds: visible.map((c) => c.id).toList(),
          );
          _device = raw.map((e) => _fromDevice(e, byId[e.calendarId])).toList();
        }
        lastError = null;
      } catch (e) {
        lastError = 'Could not read device calendars.';
      }
    }
    loading = false;
    notifyListeners();
    WidgetSync.push(allEvents, weekStartsMonday: weekStartsMonday);
  }

  EventItem _fromDevice(Event e, Calendar? cal) => EventItem(
    id: e.instanceId,
    title: e.title.isEmpty ? '(No title)' : e.title,
    start: e.startDate,
    end: e.endDate,
    allDay: e.isAllDay,
    location: e.location,
    description: e.description,
    source: EventSource.device,
    calendarId: e.calendarId,
    calendarName: cal?.name,
    accountName: cal?.accountName,
    colorIndex: e.calendarId.hashCode,
  );

  // ----------------------------------------------------------- selection
  void selectDay(DateTime d) {
    selectedDay = dateOnly(d);
    final m = monthStart(d);
    final monthChanged = m != focusedMonth;
    focusedMonth = m;
    notifyListeners();
    if (monthChanged && hasDeviceAccess) reload();
  }

  void shiftMonth(int delta) {
    // Keep the same day-of-month where possible (clamped to month length).
    final dom = dayNum(selectedDay);
    focusedMonth = shiftMonths(focusedMonth, delta);
    final maxDay = daysInMonthOf(focusedMonth);
    selectedDay = addDays(focusedMonth, (dom > maxDay ? maxDay : dom) - 1);
    notifyListeners();
    if (hasDeviceAccess) reload();
  }

  List<EventItem> eventsOn(DateTime day, {bool includeReminders = true}) {
    final list =
        allEvents
            .where(
              (e) => (includeReminders || !e.isReminder) && e.occursOn(day),
            )
            .toList()
          ..sort(compareEvents);
    return list;
  }

  bool hasEvents(DateTime day) => allEvents.any((e) => e.occursOn(day));

  /// The next timed event that has not finished yet.
  EventItem? get nextUp {
    final now = DateTime.now();
    final l =
        allEvents
            .where((e) => !e.isReminder && !e.allDay && e.end.isAfter(now))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return l.isEmpty ? null : l.first;
  }

  List<EventItem> get reminders =>
      _local.where((e) => e.isReminder).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  // ------------------------------------------------------------- writing
  /// Creates an event. When [calendarId] is set it is written to the phone's
  /// calendar (so it syncs to the account behind it); otherwise it stays local.
  Future<String?> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    int colorIndex = 0,
    String? calendarId,
  }) async {
    String? warning;
    if (calendarId != null && hasDeviceAccess) {
      try {
        var e = end;
        if (allDay && !e.isAfter(start)) e = addDays(start, 1);
        await _plugin.createEvent(
          calendarId: calendarId,
          title: title,
          startDate: start,
          endDate: e,
          isAllDay: allDay,
          location: (location?.trim().isEmpty ?? true)
              ? null
              : location!.trim(),
        );
        defaultCalendarId = calendarId;
        await _prefs?.setString('default_calendar', calendarId);
        await reload();
        return null;
      } catch (_) {
        // Fall through and keep it locally so nothing the user typed is lost.
        warning = t(
          'Could not save to that calendar. Saved on this phone only.',
        );
      }
    }
    _local.add(
      EventItem(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        location: location,
        colorIndex: colorIndex,
      ),
    );
    await _persist();
    return warning;
  }

  Future<void> addReminder(String title, DateTime when) async {
    _local.add(
      EventItem(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        start: when,
        end: when,
        isReminder: true,
        colorIndex: 4,
      ),
    );
    await _persist();
  }

  Future<String?> updateEvent(
    EventItem old, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String? location,
    int? colorIndex,
  }) async {
    if (old.source == EventSource.device) {
      try {
        await _plugin.updateEvent(
          instanceId: old.id,
          title: title,
          startDate: start,
          endDate: end,
          isAllDay: allDay,
        );
        await reload();
        return null;
      } catch (e) {
        return 'Could not update this event: $e';
      }
    }
    final i = _local.indexWhere((e) => e.id == old.id);
    if (i >= 0) {
      _local[i] = old.copyWith(
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        location: location,
        colorIndex: colorIndex,
      );
      await _persist();
    }
    return null;
  }

  Future<String?> deleteEvent(EventItem e) async {
    if (e.source == EventSource.device) {
      try {
        await _plugin.deleteEvent(instanceId: e.id);
        await reload();
        return null;
      } catch (err) {
        return 'Could not delete this event: $err';
      }
    }
    _local.removeWhere((x) => x.id == e.id);
    await _persist();
    return null;
  }

  Future<void> toggleDone(EventItem e) async {
    final i = _local.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    _local[i] = e.copyWith(done: !e.done);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      'local_events',
      jsonEncode(_local.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
    WidgetSync.push(allEvents, weekStartsMonday: weekStartsMonday);
  }

  // ------------------------------------------------------------ settings
  Future<void> setLanguage(String lang) async {
    AppLocale.lang = lang;
    await _prefs?.setString('language', lang);
    notifyListeners();
    WidgetSync.push(allEvents, weekStartsMonday: weekStartsMonday);
  }

  Future<void> setEthiopian(bool v) async {
    AppLocale.ethiopian = v;
    focusedMonth = monthStart(selectedDay);
    await _prefs?.setBool('ethiopian', v);
    notifyListeners();
    WidgetSync.push(allEvents, weekStartsMonday: weekStartsMonday);
    if (hasDeviceAccess) reload();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await _prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setCalendarVisible(String id, bool visible) async {
    visible ? hiddenCalendarIds.remove(id) : hiddenCalendarIds.add(id);
    await _prefs?.setStringList('hidden_calendars', hiddenCalendarIds.toList());
    await reload();
  }

  Future<void> setSecondZone(String id) async {
    secondZone = id;
    await _prefs?.setString('second_zone', id);
    notifyListeners();
  }

  Future<void> setWeekStartsMonday(bool v) async {
    weekStartsMonday = v;
    await _prefs?.setBool('week_monday', v);
    notifyListeners();
    WidgetSync.push(allEvents, weekStartsMonday: v);
  }
}
