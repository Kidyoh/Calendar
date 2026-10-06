import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
DateTime maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// First day of the week containing [d].
DateTime startOfWeek(DateTime d, {bool monday = true}) {
  final back = monday ? d.weekday - 1 : d.weekday % 7;
  return addDays(dateOnly(d), -back);
}

String dayKey(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String monthName(DateTime d) => monthNames[d.month - 1];
String monthShort(DateTime d) => monthNames[d.month - 1].substring(0, 3);
String weekdayName(DateTime d) => weekdayNames[d.weekday - 1];
String weekdayShort(DateTime d, {int len = 2}) =>
    weekdayNames[d.weekday - 1].substring(0, len);

String fmtTime(DateTime d) => DateFormat('h:mm a').format(d);
String fmtHour(int h) =>
    DateFormat('h a').format(DateTime(2000, 1, 1, h)).toLowerCase();

String fmtDuration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m Min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r m';
}

/// "in 25 min", "in 2 h", "now".
String fmtCountdown(Duration d) {
  if (d.inMinutes <= 0) return 'now';
  if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
  if (d.inHours < 24) return 'in ${d.inHours} h';
  return 'in ${d.inDays} d';
}
