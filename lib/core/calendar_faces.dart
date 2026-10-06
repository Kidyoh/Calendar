import 'dates.dart';
import 'ethiopian.dart';
import 'hijri.dart';
import 'holidays.dart';
import 'locale.dart';

/// The four calendar "faces" the widgets can be swiped between.
enum CalFace { gregorian, ethiopian, islamic, orthodox }

class FaceView {
  const FaceView({
    required this.label,
    required this.title,
    required this.day,
    required this.line,
    this.line2 = '',
  });
  final String label; // "Gregorian", "ኢትዮጵያዊ", …
  final String title; // month + year
  final String day; // big day number
  final String line; // what matters today
  final String line2; // extra detail / countdown
}

String faceLabel(CalFace f) => switch (f) {
  CalFace.gregorian => t('Gregorian'),
  CalFace.ethiopian => t('Ethiopian'),
  CalFace.islamic => t('Islamic'),
  CalFace.orthodox => t('Orthodox'),
};

/// Day-of-month shown in week strips for [f].
int faceDay(CalFace f, DateTime d) => switch (f) {
  CalFace.gregorian => d.day,
  CalFace.ethiopian || CalFace.orthodox => toEthiopian(d).day,
  CalFace.islamic => toHijri(d).day,
};

String inDays(int n) {
  if (n <= 0) return t('today');
  if (n == 1) return t('tomorrow');
  return AppLocale.am ? 'በ$n ቀን ውስጥ' : 'in $n days';
}

String _ethMonth(int m) =>
    AppLocale.am ? ethMonthsAm[m - 1] : ethMonthsEn[m - 1];
String _ethYear(int y) => AppLocale.am ? '$y ዓ.ም' : '$y E.C.';

/// Evangelist year of the Ethiopian calendar (leap years are St. Luke's).
String evangelistYear(int ethYear) {
  const am = ['ዘመነ ዮሐንስ', 'ዘመነ ማቴዎስ', 'ዘመነ ማርቆስ', 'ዘመነ ሉቃስ'];
  const en = [
    'Year of St. John',
    'Year of St. Matthew',
    'Year of St. Mark',
    'Year of St. Luke',
  ];
  return AppLocale.am ? am[ethYear % 4] : en[ethYear % 4];
}

bool _isChurchFeast(Holiday h) =>
    h.kind == HolidayKind.orthodox || h.kind == HolidayKind.saint;

/// Next major Orthodox feast (Fasika, Genna, Timket, Meskel, …) after [d].
(Holiday, int)? nextOrthodoxFeast(DateTime d) {
  for (var i = 1; i <= 400; i++) {
    final x = addDays(d, i);
    for (final h in holidaysOn(x)) {
      if (h.kind == HolidayKind.orthodox && h.dayOff) return (h, i);
    }
  }
  return null;
}

/// Next Islamic occasion (Ramadan start, Eid al-Fitr, Eid al-Adha, Mawlid).
(String, int)? nextIslamic(DateTime d) {
  final today = dateOnly(d);
  final h = toHijri(today);
  const events = [
    (9, 1, 'Ramadan begins', 'ረመዳን ይጀምራል'),
    (10, 1, 'Eid al-Fitr', 'ዒድ አል ፈጥር'),
    (12, 10, 'Eid al-Adha', 'ዒድ አል አድሐ'),
    (3, 12, 'Mawlid', 'መውሊድ'),
  ];
  (String, int)? best;
  for (final y in [h.year, h.year + 1]) {
    for (final (m, day, en, am) in events) {
      final g = hijriToGregorian(y, m, day);
      final n =
          g.difference(today).inHours ~/ 24 +
          (g.difference(today).inHours % 24 > 12 ? 1 : 0);
      if (n >= 0 && (best == null || n < best.$2)) {
        best = (AppLocale.am ? am : en, n);
      }
    }
  }
  return best;
}

FaceView faceView(CalFace f, DateTime d) {
  final day = dateOnly(d);
  switch (f) {
    case CalFace.gregorian:
      return FaceView(
        label: faceLabel(f),
        title: '${gregMonthName(day)} ${day.year}',
        day: '${day.day}',
        line: '${weekdayName(day)} · ${t('Week')} ${isoWeek(day)}',
        line2: _otherEth(day),
      );
    case CalFace.ethiopian:
      final e = toEthiopian(day);
      return FaceView(
        label: faceLabel(f),
        title: '${_ethMonth(e.month)} ${_ethYear(e.year)}',
        day: '${e.day}',
        line:
            '${weekdayName(day)} · ${gregMonthName(day)} ${day.day}, ${day.year}',
        line2: evangelistYear(e.year),
      );
    case CalFace.islamic:
      final h = toHijri(day);
      final next = nextIslamic(day);
      return FaceView(
        label: faceLabel(f),
        title:
            '${AppLocale.am ? hijriMonthsAm[h.month - 1] : hijriMonthsEn[h.month - 1]} ${h.year}${AppLocale.am ? '' : ' AH'}',
        day: '${h.day}',
        line: '${hijriMonthsAr[h.month - 1]} ${h.year} هـ',
        line2: next == null
            ? ''
            : (next.$2 == 0
                  ? '${t('today')}: ${next.$1}'
                  : '${next.$1} ${inDays(next.$2)}'),
      );
    case CalFace.orthodox:
      final e = toEthiopian(day);
      final feasts = holidaysOn(
        day,
        saints: true,
      ).where(_isChurchFeast).map((h) => h.name).toList();
      final fast = fastOn(day);
      final next = nextOrthodoxFeast(day);
      final fastText = fast == null
          ? t('No fast today')
          : '${t('Fasting day')} · ${fast.name}${fast.progress == null ? '' : ' · ${fast.progress}'}';
      return FaceView(
        label: faceLabel(f),
        title: '${_ethMonth(e.month)} ${_ethYear(e.year)}',
        day: '${e.day}',
        line: feasts.isEmpty ? fastText : feasts.join(' · '),
        line2: feasts.isEmpty
            ? (next == null ? '' : '${next.$1.name} ${inDays(next.$2)}')
            : fastText,
      );
  }
}

String _otherEth(DateTime d) {
  final e = toEthiopian(d);
  return '${_ethMonth(e.month)} ${e.day}, ${_ethYear(e.year)}';
}

/// First (Gregorian) day of the month containing [d] in face [f], and the
/// month's length — month grids in widgets follow their own calendar.
(DateTime, int) faceMonth(CalFace f, DateTime d) {
  final day = dateOnly(d);
  switch (f) {
    case CalFace.gregorian:
      return (
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1, 0).day,
      );
    case CalFace.ethiopian || CalFace.orthodox:
      final e = toEthiopian(day);
      return (
        fromEthiopian(e.year, e.month, 1),
        ethDaysInMonth(e.year, e.month),
      );
    case CalFace.islamic:
      final h = toHijri(day);
      return (
        hijriToGregorian(h.year, h.month, 1),
        hijriMonthLength(h.year, h.month),
      );
  }
}

/// Month start [delta] months away in face [f] (any day → that month's day 1).
DateTime shiftFaceMonth(CalFace f, DateTime d, int delta) {
  var (start, len) = faceMonth(f, d);
  for (var i = 0; i < delta; i++) {
    start = addDays(start, len);
    len = faceMonth(f, start).$2;
  }
  for (var i = 0; i > delta; i--) {
    start = faceMonth(f, addDays(start, -1)).$1;
  }
  return start;
}

/// Start and end (exclusive) of the year containing [d] in face [f].
(DateTime, DateTime) faceYear(CalFace f, DateTime d) {
  switch (f) {
    case CalFace.gregorian:
      return (DateTime(d.year), DateTime(d.year + 1));
    case CalFace.ethiopian || CalFace.orthodox:
      final y = toEthiopian(d).year;
      return (fromEthiopian(y, 1, 1), fromEthiopian(y + 1, 1, 1));
    case CalFace.islamic:
      final y = toHijri(d).year;
      return (hijriToGregorian(y, 1, 1), hijriToGregorian(y + 1, 1, 1));
  }
}
