import 'dart:async';
import 'dart:convert';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar_faces.dart';
import '../core/dates.dart';
import '../core/holidays.dart';
import '../core/locale.dart';
import '../models/event_item.dart';
import 'notification_service.dart';
import 'widget_sync.dart';

/// Widget types on the Widgets tab (and matching home-screen widgets).
const widgetTypes = ['glass', 'island', 'date', 'progress', 'next', 'feasts'];

/// Views each widget type can switch between (first = default).
const widgetViews = <String, List<String>>{
  'glass': ['week', 'month', 'agenda'],
  'island': ['week', 'month'],
  'date': ['date'],
  'progress': ['day', 'week', 'month', 'year'],
  'next': ['next', 'agenda'],
  'feasts': ['feasts'],
};

/// Looks: frosted glass, black island, or light paper.
const widgetStyles = ['glass', 'dark', 'light'];

String defaultStyleOf(String type) => switch (type) {
  'glass' || 'date' => 'glass',
  'feasts' => 'light',
  _ => 'dark',
};

/// One widget on the Widgets tab. Each has its own calendar face, view and
/// style.
class WidgetInstance {
  WidgetInstance(this.id, this.type, this.face, {String? view, String? style})
    : view = (widgetViews[type] ?? const ['week']).contains(view)
          ? view!
          : (widgetViews[type] ?? const ['week']).first,
      style = widgetStyles.contains(style) ? style! : defaultStyleOf(type);
  final String id;
  final String type; // see [widgetTypes]
  CalFace face;
  String view;
  String style;

  List<String> get views => widgetViews[type] ?? const ['week'];

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'face': face.index,
    'view': view,
    'style': style,
  };
  factory WidgetInstance.fromJson(Map<String, dynamic> j) => WidgetInstance(
    j['id'] as String,
    j['type'] as String,
    CalFace.values[((j['face'] as int?) ?? 0).clamp(
      0,
      CalFace.values.length - 1,
    )],
    view: j['view'] as String?,
    style: j['style'] as String?,
  );
}

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
  bool showNational = true;
  bool showOrthodox = true;
  bool showIslamic = true;
  bool showSaints = false;

  /// In-app widgets, each with its own calendar face (swipe to change).
  List<WidgetInstance> widgets = [];

  /// Default face for newly added widgets (and new home-screen widgets).
  CalFace get widgetFace =>
      widgets.isEmpty ? CalFace.gregorian : widgets.first.face;

  /// Notification preferences (event alerts, reminders, morning briefing).
  final notify = NotifySettings();
  Timer? _notifyDebounce;
  String get language => AppLocale.lang;
  bool get ethiopian => AppLocale.ethiopian;
  String? defaultCalendarId;

  bool get hasDeviceAccess => permission == CalendarPermissionStatus.granted;
  String get secondZoneLabel => t(zoneChoices[secondZone] ?? secondZone);
  String get localZoneLabel =>
      t(localZoneId.split('/').last.replaceAll('_', ' '));

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
    showNational = _prefs!.getBool('hol_national') ?? true;
    showOrthodox = _prefs!.getBool('hol_orthodox') ?? true;
    showIslamic = _prefs!.getBool('hol_islamic') ?? true;
    showSaints = _prefs!.getBool('hol_saints') ?? false;
    // First run on an Amharic phone defaults to Amharic + Ethiopian calendar.
    final amPhone = PlatformDispatcher.instance.locale.languageCode == 'am';
    AppLocale.lang = _prefs!.getString('language') ?? (amPhone ? 'am' : 'en');
    AppLocale.ethiopian = _prefs!.getBool('ethiopian') ?? amPhone;
    focusedMonth = monthStart(selectedDay);
    _loadWidgets();
    defaultCalendarId = _prefs!.getString('default_calendar');
    try {
      localZoneId = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    notify
      ..events = _prefs!.getBool('n_events') ?? true
      ..eventLead = _prefs!.getInt('n_lead') ?? 10
      ..reminders = _prefs!.getBool('n_reminders') ?? true
      ..briefing = _prefs!.getBool('n_briefing') ?? true
      ..briefingHour = _prefs!.getInt('n_brief_h') ?? 7
      ..briefingMinute = _prefs!.getInt('n_brief_m') ?? 0
      ..holidays = _prefs!.getBool('n_holidays') ?? true;
    NotificationService.onRemindersChanged = () => reloadLocal();
    await NotificationService.init();
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
    _pushWidgets();
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

  Future<void> addReminder(
    String title,
    DateTime when, {
    Repeat repeat = Repeat.none,
    int colorIndex = 4,
  }) async {
    _local.add(
      EventItem(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        start: when,
        end: when,
        isReminder: true,
        colorIndex: colorIndex,
        repeat: repeat,
      ),
    );
    await _persist();
  }

  Future<void> snoozeReminder(EventItem r, Duration by) async {
    final i = _local.indexWhere((x) => x.id == r.id);
    if (i < 0) return;
    final base = r.start.isBefore(DateTime.now()) ? DateTime.now() : r.start;
    final when = base.add(by);
    _local[i] = r.copyWith(start: when, end: when, done: false);
    await _persist();
  }

  /// Re-read reminders saved by a notification action (Done / Snooze).
  Future<void> reloadLocal() async {
    await _prefs?.reload();
    final raw = _prefs?.getString('local_events');
    if (raw == null) return;
    try {
      _local = (jsonDecode(raw) as List)
          .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
      _pushWidgets();
    } catch (_) {}
  }

  Future<String?> updateEvent(
    EventItem old, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String? location,
    int? colorIndex,
    Repeat? repeat,
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
        repeat: repeat,
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
    if (!e.done && e.repeat != Repeat.none) {
      // Repeating: completing it moves it to the next occurrence.
      // Next occurrence after the one being completed (or after now, if it was overdue).
      final now = DateTime.now();
      final next = NotificationService.nextOccurrence(
        e,
        e.start.isAfter(now) ? e.start : now,
      );
      _local[i] = e.copyWith(start: next, end: next);
    } else {
      _local[i] = e.copyWith(done: !e.done);
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      'local_events',
      jsonEncode(_local.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
    _pushWidgets();
  }

  // ------------------------------------------------------------ settings
  Future<void> setLanguage(String lang) async {
    AppLocale.lang = lang;
    await _prefs?.setString('language', lang);
    notifyListeners();
    _pushWidgets();
  }

  Future<void> setEthiopian(bool v) async {
    AppLocale.ethiopian = v;
    focusedMonth = monthStart(selectedDay);
    await _prefs?.setBool('ethiopian', v);
    notifyListeners();
    _pushWidgets();
    if (hasDeviceAccess) reload();
  }

  // ------------------------------------------------------------ holidays
  /// Holidays on [day] for the categories the user has switched on.
  List<Holiday> holidaysFor(DateTime day) =>
      holidaysOn(day, saints: showSaints).where((h) {
        // Days off (e.g. Fasika, Eid) stay visible under "public holidays"
        // even if their religious category is switched off.
        if (h.dayOff && showNational) return true;
        return switch (h.kind) {
          HolidayKind.national => showNational,
          HolidayKind.orthodox => showOrthodox,
          HolidayKind.islamic => showIslamic,
          HolidayKind.saint => showSaints,
        };
      }).toList();

  /// Orthodox fast on [day] (only when Orthodox feasts & fasts are on).
  FastDay? fastFor(DateTime day) => showOrthodox ? fastOn(day) : null;

  bool isDayOff(DateTime day) => holidaysFor(day).any((h) => h.dayOff);

  Future<void> setHolidayCategory(HolidayKind kind, bool v) async {
    switch (kind) {
      case HolidayKind.national:
        showNational = v;
        await _prefs?.setBool('hol_national', v);
      case HolidayKind.orthodox:
        showOrthodox = v;
        await _prefs?.setBool('hol_orthodox', v);
      case HolidayKind.islamic:
        showIslamic = v;
        await _prefs?.setBool('hol_islamic', v);
      case HolidayKind.saint:
        showSaints = v;
        await _prefs?.setBool('hol_saints', v);
    }
    notifyListeners();
    _pushWidgets();
  }

  /// Notification settings changed.
  Future<void> setNotify(void Function(NotifySettings n) change) async {
    change(notify);
    await _prefs?.setBool('n_events', notify.events);
    await _prefs?.setInt('n_lead', notify.eventLead);
    await _prefs?.setBool('n_reminders', notify.reminders);
    await _prefs?.setBool('n_briefing', notify.briefing);
    await _prefs?.setInt('n_brief_h', notify.briefingHour);
    await _prefs?.setInt('n_brief_m', notify.briefingMinute);
    await _prefs?.setBool('n_holidays', notify.holidays);
    notifyListeners();
    _scheduleNotifications();
  }

  void _scheduleNotifications() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 700), () {
      NotificationService.rescheduleAll(allEvents, notify);
    });
  }

  void _pushWidgets() {
    _scheduleNotifications();
    _pushWidgetsNow();
  }

  void _pushWidgetsNow() => WidgetSync.push(
    allEvents,
    weekStartsMonday: weekStartsMonday,
    face: widgetFace,
    holidayToday: holidaysFor(DateTime.now()).map((h) => h.name).join(' · '),
    holidays: holidaysFor,
    fasts: fastFor,
  );

  // ------------------------------------------------------- widget instances
  void _loadWidgets() {
    final raw = _prefs?.getString('widgets_v1');
    if (raw != null) {
      try {
        widgets = (jsonDecode(raw) as List)
            .map((e) => WidgetInstance.fromJson(e as Map<String, dynamic>))
            .where((w) => widgetTypes.contains(w.type))
            .toList();
        // Upgrade from v1: the day-progress and next-up islands used to be
        // fixed; they are now widgets of their own.
        if (_prefs?.getBool('widgets_v2') != true) {
          final f = widgets.isEmpty ? CalFace.gregorian : widgets.first.face;
          widgets.addAll([
            WidgetInstance('progress-1', 'progress', f),
            WidgetInstance('next-1', 'next', f),
          ]);
          _prefs?.setBool('widgets_v2', true);
          _saveWidgets();
        }
        return;
      } catch (_) {}
    }
    // First run / upgrade: one glass + one island, keeping any earlier choice.
    final old = _prefs?.getInt('widget_face');
    final start = old != null && old < CalFace.values.length
        ? CalFace.values[old]
        : (AppLocale.ethiopian ? CalFace.ethiopian : CalFace.gregorian);
    widgets = [
      WidgetInstance('glass-1', 'glass', start),
      WidgetInstance('island-1', 'island', start),
      WidgetInstance('progress-1', 'progress', start),
      WidgetInstance('next-1', 'next', start),
    ];
    _prefs?.setBool('widgets_v2', true);
  }

  Future<void> _saveWidgets() async {
    await _prefs?.setString(
      'widgets_v1',
      jsonEncode(widgets.map((w) => w.toJson()).toList()),
    );
  }

  WidgetInstance? widgetById(String id) {
    for (final w in widgets) {
      if (w.id == id) return w;
    }
    return null;
  }

  CalFace faceOf(String id) => widgetById(id)?.face ?? widgetFace;

  Future<void> setFaceFor(String id, CalFace f) async {
    final w = widgetById(id);
    if (w == null || w.face == f) return;
    w.face = f;
    await _saveWidgets();
    notifyListeners();
    if (widgets.first.id == id) _pushWidgets(); // default for new home widgets
  }

  /// Swipe helper: next (+1) or previous (-1) face of one widget, wrapping.
  void cycleFaceFor(String id, int dir) => setFaceFor(
    id,
    CalFace.values[(faceOf(id).index + dir) % CalFace.values.length],
  );

  /// Customize one widget: its view (week / month / agenda …) and style.
  Future<void> customizeWidget(String id, {String? view, String? style}) async {
    final w = widgetById(id);
    if (w == null) return;
    if (view != null && w.views.contains(view)) w.view = view;
    if (style != null && widgetStyles.contains(style)) w.style = style;
    await _saveWidgets();
    notifyListeners();
  }

  Future<String> addWidget(
    String type, {
    CalFace? face,
    String? view,
    String? style,
  }) async {
    final n = widgets.where((w) => w.type == type).length + 1;
    var id = '$type-$n';
    while (widgetById(id) != null) {
      id = '$type-${DateTime.now().microsecondsSinceEpoch}';
    }
    widgets.add(
      WidgetInstance(id, type, face ?? widgetFace, view: view, style: style),
    );
    await _saveWidgets();
    notifyListeners();
    return id;
  }

  /// Removes a widget; returns it and its position so it can be restored (Undo).
  Future<(WidgetInstance, int)?> removeWidget(String id) async {
    final i = widgets.indexWhere((w) => w.id == id);
    if (i < 0) return null;
    final w = widgets.removeAt(i);
    await _saveWidgets();
    notifyListeners();
    return (w, i);
  }

  Future<void> restoreWidget(WidgetInstance w, int index) async {
    widgets.insert(index.clamp(0, widgets.length), w);
    await _saveWidgets();
    notifyListeners();
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
    _pushWidgets();
  }
}
