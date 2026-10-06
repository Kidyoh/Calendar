import 'ethiopian.dart';
import 'locale.dart';

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
const _monthNamesAm = [
  'ጃንዩወሪ',
  'ፌብሩወሪ',
  'ማርች',
  'ኤፕሪል',
  'ሜይ',
  'ጁን',
  'ጁላይ',
  'ኦገስት',
  'ሴፕቴምበር',
  'ኦክቶበር',
  'ኖቬምበር',
  'ዲሴምበር',
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
const _weekdayAm = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];
const _weekdayAmShort = ['ሰኞ', 'ማክ', 'ረቡ', 'ሐሙ', 'ዓር', 'ቅዳ', 'እሑ'];
const _weekdayAmLetter = ['ሰ', 'ማ', 'ረ', 'ሐ', 'ዓ', 'ቅ', 'እ'];

// ---------------------------------------------------------------------------
// Calendar-system aware helpers. All take/return Gregorian [DateTime] days;
// they only change how months are grouped and how dates are labelled.

/// First day of the month containing [d] in the active calendar.
DateTime monthStart(DateTime d) {
  if (!AppLocale.ethiopian) return DateTime(d.year, d.month);
  final e = toEthiopian(d);
  return fromEthiopian(e.year, e.month, 1);
}

int daysInMonthOf(DateTime d) {
  if (!AppLocale.ethiopian) return DateTime(d.year, d.month + 1, 0).day;
  final e = toEthiopian(d);
  return ethDaysInMonth(e.year, e.month);
}

/// Month start [delta] months away from the month containing [d].
DateTime shiftMonths(DateTime d, int delta) {
  if (!AppLocale.ethiopian) return DateTime(d.year, d.month + delta);
  final e = toEthiopian(d);
  var idx = e.year * 13 + (e.month - 1) + delta; // 13 months a year
  return fromEthiopian(idx ~/ 13, idx % 13 + 1, 1);
}

bool sameMonth(DateTime a, DateTime b) => monthStart(a) == monthStart(b);

int dayNum(DateTime d) => AppLocale.ethiopian ? toEthiopian(d).day : d.day;
int monthNum(DateTime d) =>
    AppLocale.ethiopian ? toEthiopian(d).month : d.month;
int yearNum(DateTime d) => AppLocale.ethiopian ? toEthiopian(d).year : d.year;

String monthName(DateTime d) {
  if (AppLocale.ethiopian) {
    final m = toEthiopian(d).month - 1;
    return AppLocale.am ? ethMonthsAm[m] : ethMonthsEn[m];
  }
  return AppLocale.am ? _monthNamesAm[d.month - 1] : monthNames[d.month - 1];
}

/// Compact month label for big headings ("OCT", "መስከረም", "MESKEREM").
String monthShort(DateTime d) {
  if (AppLocale.am || AppLocale.ethiopian) return monthName(d);
  return monthNames[d.month - 1].substring(0, 3);
}

String weekdayName(DateTime d) =>
    AppLocale.am ? _weekdayAm[d.weekday - 1] : weekdayNames[d.weekday - 1];

String weekdayShort(DateTime d, {int len = 2}) {
  if (AppLocale.am) {
    return len == 1
        ? _weekdayAmLetter[d.weekday - 1]
        : _weekdayAmShort[d.weekday - 1];
  }
  return weekdayNames[d.weekday - 1].substring(0, len);
}

/// "Oct 6, 2026" / "መስከረም 26, 2019" in the active calendar.
String fmtDate(DateTime d) => '${monthShort(d)} ${dayNum(d)}, ${yearNum(d)}';

/// The same day in the *other* calendar, e.g. under the big Today date.
String fmtOtherCalendar(DateTime d) {
  if (AppLocale.ethiopian) {
    final m = AppLocale.am
        ? _monthNamesAm[d.month - 1]
        : monthNames[d.month - 1].substring(0, 3);
    return '$m ${d.day}, ${d.year}';
  }
  final e = toEthiopian(d);
  final m = AppLocale.am ? ethMonthsAm[e.month - 1] : ethMonthsEn[e.month - 1];
  return '$m ${e.day}, ${e.year}';
}

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  if (AppLocale.am) return '$h:$mm ${d.hour < 12 ? 'ጥዋት' : 'ከሰዓት'}';
  return '$h:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtHour(int h) {
  final hh = h % 12 == 0 ? 12 : h % 12;
  if (AppLocale.am) return '$hh ${h < 12 ? 'ጥዋት' : 'ከሰዓት'}';
  return '$hh ${h < 12 ? 'am' : 'pm'}';
}

String fmtDuration(Duration d) {
  final m = d.inMinutes;
  final am = AppLocale.am;
  if (m < 60) return am ? '$m ደቂቃ' : '$m Min';
  final h = m ~/ 60;
  final r = m % 60;
  if (am) return r == 0 ? '$h ሰዓት' : '$h ሰዓት $r ደ';
  return r == 0 ? '$h h' : '$h h $r m';
}

/// "in 25 min", "in 2 h", "now".
String fmtCountdown(Duration d) {
  final am = AppLocale.am;
  if (d.inMinutes <= 0) return am ? 'አሁን' : 'now';
  if (d.inMinutes < 60)
    return am ? 'በ${d.inMinutes} ደቂቃ ውስጥ' : 'in ${d.inMinutes} min';
  if (d.inHours < 24) return am ? 'በ${d.inHours} ሰዓት ውስጥ' : 'in ${d.inHours} h';
  return am ? 'በ${d.inDays} ቀን ውስጥ' : 'in ${d.inDays} d';
}
