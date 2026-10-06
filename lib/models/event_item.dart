import '../core/dates.dart';

enum EventSource { device, local }

/// One calendar entry, whether it came from the phone's calendar database
/// (which is what syncs with Google / iCloud / Outlook accounts) or was
/// created locally inside this app.
class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location,
    this.description,
    this.source = EventSource.local,
    this.calendarId,
    this.calendarName,
    this.accountName,
    this.colorIndex = 0,
    this.isReminder = false,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? location;
  final String? description;
  final EventSource source;
  final String? calendarId;
  final String? calendarName;
  final String? accountName;
  final int colorIndex;
  final bool isReminder;
  final bool done;

  Duration get duration => end.difference(start);

  /// Whether this entry overlaps the calendar [day].
  bool occursOn(DateTime day) {
    final s = dateOnly(day);
    final e = addDays(s, 1);
    if (!start.isBefore(e)) return false;
    if (end.isAfter(s)) return true;
    // Zero-length entries (reminders) sit on their start day.
    return !start.isBefore(s) && start.isBefore(e);
  }

  EventItem copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    String? location,
    int? colorIndex,
    bool? done,
  }) => EventItem(
    id: id,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    allDay: allDay ?? this.allDay,
    location: location ?? this.location,
    description: description,
    source: source,
    calendarId: calendarId,
    calendarName: calendarName,
    accountName: accountName,
    colorIndex: colorIndex ?? this.colorIndex,
    isReminder: isReminder,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'allDay': allDay,
    'location': location,
    'description': description,
    'colorIndex': colorIndex,
    'isReminder': isReminder,
    'done': done,
  };

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
    id: j['id'] as String,
    title: j['title'] as String,
    start: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(j['end'] as int),
    allDay: j['allDay'] as bool? ?? false,
    location: j['location'] as String?,
    description: j['description'] as String?,
    colorIndex: j['colorIndex'] as int? ?? 0,
    isReminder: j['isReminder'] as bool? ?? false,
    done: j['done'] as bool? ?? false,
  );
}

/// Sort: all-day first, then by start time.
int compareEvents(EventItem a, EventItem b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  return a.start.compareTo(b.start);
}
