import 'dates.dart';
import 'ethiopian.dart';
import 'locale.dart';

enum HolidayKind { national, orthodox, islamic, saint }

class Holiday {
  const Holiday(
    this.en,
    this.am,
    this.kind, {
    this.dayOff = false,
    this.approximate = false,
  });
  final String en;
  final String am;
  final HolidayKind kind;

  /// Official public holiday (offices closed).
  final bool dayOff;

  /// Lunar date that may move a day with the moon sighting.
  final bool approximate;

  String get name => AppLocale.am ? am : en;
}

/// An Ethiopian Orthodox fasting day. [day]/[length] are set for the named
/// fasting seasons (e.g. day 12 of 55 of Abiy Tsom), null for weekly fasts.
class FastDay {
  const FastDay(this.en, this.am, {this.day, this.length});
  final String en;
  final String am;
  final int? day;
  final int? length;

  String get name => AppLocale.am ? am : en;

  String? get progress {
    if (day == null || length == null) return null;
    return AppLocale.am ? 'ቀን $day ከ $length' : 'Day $day of $length';
  }
}

// ---------------------------------------------------------------------------
// Movable dates

/// Ethiopian Fasika / Orthodox Easter: Julian computus (Meeus), shifted to
/// the Gregorian calendar. Same date Bahire Hasab produces.
DateTime orthodoxEaster(int year) {
  final a = year % 4, b = year % 7, c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final day = (d + e + 114) % 31 + 1;
  // Julian -> Gregorian offset (13 days for 1900-2099).
  final offset = year ~/ 100 - year ~/ 400 - 2;
  return DateTime(year, month, day + offset);
}

/// Tabular Islamic calendar (civil epoch). Real observance follows the moon
/// sighting and can differ by a day, so these are flagged [approximate].
DateTime _hijriToGregorian(int y, int m, int d) {
  final jd =
      d +
      (29.5 * (m - 1)).ceil() +
      (y - 1) * 354 +
      ((3 + 11 * y) / 30).floor() +
      1948439.5 -
      1;
  final jdn = (jd + 0.5).floor();
  // JDN -> Gregorian
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - 146097 * b ~/ 4;
  final dd = (4 * c + 3) ~/ 1461;
  final e = c - 1461 * dd ~/ 4;
  final mm = (5 * e + 2) ~/ 153;
  return DateTime(
    100 * b + dd - 4800 + mm ~/ 10,
    mm + 3 - 12 * (mm ~/ 10),
    e - (153 * mm + 2) ~/ 5 + 1,
  );
}

// ---------------------------------------------------------------------------
// Fixed feasts (Ethiopian month, day)

const _fixed = <(int, int, Holiday)>[
  (
    1,
    1,
    Holiday(
      'Enkutatash (New Year)',
      'እንቁጣጣሽ (አዲስ ዓመት)',
      HolidayKind.national,
      dayOff: true,
    ),
  ),
  (1, 16, Holiday('Demera', 'ደመራ', HolidayKind.orthodox)),
  (1, 17, Holiday('Meskel', 'መስቀል', HolidayKind.national, dayOff: true)),
  (3, 21, Holiday('Hidar Tsion', 'ኅዳር ጽዮን', HolidayKind.orthodox)),
  (4, 19, Holiday('Kulubi Gabriel', 'ቁልቢ ገብርኤል', HolidayKind.orthodox)),
  (5, 10, Holiday('Ketera (Timket Eve)', 'ከተራ', HolidayKind.orthodox)),
  (
    5,
    11,
    Holiday('Timket (Epiphany)', 'ጥምቀት', HolidayKind.national, dayOff: true),
  ),
  (5, 12, Holiday('Kana Zegelila', 'ቃና ዘገሊላ', HolidayKind.orthodox)),
  (
    6,
    23,
    Holiday(
      'Adwa Victory Day',
      'የዓድዋ ድል በዓል',
      HolidayKind.national,
      dayOff: true,
    ),
  ),
  (
    8,
    27,
    Holiday(
      'Patriots\' Victory Day',
      'የአርበኞች ቀን',
      HolidayKind.national,
      dayOff: true,
    ),
  ),
  (
    9,
    20,
    Holiday(
      'Downfall of the Derg',
      'ግንቦት 20',
      HolidayKind.national,
      dayOff: true,
    ),
  ),
  (12, 13, Holiday('Buhe (Debre Tabor)', 'ቡሄ (ደብረ ታቦር)', HolidayKind.orthodox)),
  (12, 16, Holiday('Filseta (Assumption)', 'ፍልሰታ ለማርያም', HolidayKind.orthodox)),
];

const _saints = <int, Holiday>{
  7: Holiday('Selassie', 'ሥላሴ', HolidayKind.saint),
  12: Holiday('Kidus Mikael', 'ቅዱስ ሚካኤል', HolidayKind.saint),
  16: Holiday('Kidane Mihret', 'ኪዳነ ምሕረት', HolidayKind.saint),
  19: Holiday('Kidus Gabriel', 'ቅዱስ ገብርኤል', HolidayKind.saint),
  21: Holiday('Kidist Mariam', 'ቅድስት ማርያም', HolidayKind.saint),
  23: Holiday('Kidus Giorgis', 'ቅዱስ ጊዮርጊስ', HolidayKind.saint),
  27: Holiday('Medhane Alem', 'መድኃኔ ዓለም', HolidayKind.saint),
  29: Holiday('Bale Wold', 'ባለ ወልድ', HolidayKind.saint),
};

const _genna = Holiday(
  'Genna (Christmas)',
  'ገና (ልደት)',
  HolidayKind.national,
  dayOff: true,
);
const _labour = Holiday(
  'Labour Day',
  'የሠራተኞች ቀን',
  HolidayKind.national,
  dayOff: true,
);

/// All holiday data for one Gregorian year, computed once and cached.
class _Year {
  _Year(this.year) {
    void add(DateTime d, Holiday h) {
      if (d.year == year) days.putIfAbsent(dayKey(d), () => []).add(h);
    }

    // Fixed Ethiopian dates from both Ethiopian years overlapping [year].
    for (final ey in [year - 8, year - 7]) {
      for (final (m, d, h) in _fixed) {
        add(fromEthiopian(ey, m, d), h);
      }
    }
    // Genna is 7 January in every year (Tahsas 29, or 28 after a leap year).
    add(DateTime(year, 1, 7), _genna);
    add(DateTime(year, 5, 1), _labour);

    // Movable feasts around Fasika.
    fasika = orthodoxEaster(year);
    final f = fasika;
    add(
      addDays(f, -28),
      const Holiday('Debre Zeit', 'ደብረ ዘይት', HolidayKind.orthodox),
    );
    add(
      addDays(f, -7),
      const Holiday('Hosanna (Palm Sunday)', 'ሆሣዕና', HolidayKind.orthodox),
    );
    add(
      addDays(f, -2),
      const Holiday(
        'Siklet (Good Friday)',
        'ስቅለት',
        HolidayKind.national,
        dayOff: true,
      ),
    );
    add(
      f,
      const Holiday(
        'Fasika (Easter)',
        'ፋሲካ (ትንሣኤ)',
        HolidayKind.national,
        dayOff: true,
      ),
    );
    add(
      addDays(f, 39),
      const Holiday('Erget (Ascension)', 'ዕርገት', HolidayKind.orthodox),
    );
    add(
      addDays(f, 49),
      const Holiday('Peraklitos (Pentecost)', 'ጰራቅሊጦስ', HolidayKind.orthodox),
    );

    // Islamic holidays (public holidays in Ethiopia).
    final approxHy = ((year - 622) * 33 / 32).floor();
    for (var hy = approxHy - 1; hy <= approxHy + 2; hy++) {
      add(
        _hijriToGregorian(hy, 3, 12),
        const Holiday(
          'Mawlid',
          'መውሊድ',
          HolidayKind.islamic,
          dayOff: true,
          approximate: true,
        ),
      );
      add(
        _hijriToGregorian(hy, 10, 1),
        const Holiday(
          'Eid al-Fitr',
          'ዒድ አል ፈጥር',
          HolidayKind.islamic,
          dayOff: true,
          approximate: true,
        ),
      );
      add(
        _hijriToGregorian(hy, 12, 10),
        const Holiday(
          'Eid al-Adha (Arafa)',
          'ዒድ አል አድሐ (አረፋ)',
          HolidayKind.islamic,
          dayOff: true,
          approximate: true,
        ),
      );
    }
  }

  final int year;
  late final DateTime fasika;
  final days = <String, List<Holiday>>{};
}

final _cache = <int, _Year>{};
_Year _yearOf(int y) => _cache.putIfAbsent(y, () => _Year(y));

/// Holidays falling on [day] (all kinds; filter by kind in the UI).
List<Holiday> holidaysOn(DateTime day, {bool saints = false}) {
  final list = [...?_yearOf(day.year).days[dayKey(day)]];
  if (saints) {
    final e = toEthiopian(day);
    final s = _saints[e.day];
    if (s != null && e.month != 13) list.add(s);
  }
  return list;
}

/// Ethiopian Orthodox fast on [day], or null for a non-fasting day.
FastDay? fastOn(DateTime day) {
  final d = dateOnly(day);
  final fasika = _yearOf(d.year).fasika;
  int diff(DateTime a, DateTime b) =>
      a.difference(b).inHours ~/ 24 +
      (a.difference(b).inHours % 24 > 12 ? 1 : 0);
  final rel = diff(d, fasika);
  final e = toEthiopian(d);

  // 50 days of joy after Fasika: no fasting at all (incl. Wed/Fri).
  if (rel >= 0 && rel <= 49) return null;
  // Genna (7 Jan) is a feast, never a fast — even when it is Tahsas 28.
  if (d.month == 1 && d.day == 7) return null;

  // Abiy Tsom: 55 days before Fasika.
  if (rel >= -55 && rel <= -1) {
    return FastDay(
      'Abiy Tsom (Great Lent)',
      'ዐቢይ ጾም',
      day: rel + 56,
      length: 55,
    );
  }
  // Fast of Nineveh: Monday–Wednesday, two weeks before Abiy Tsom.
  if (rel >= -69 && rel <= -67) {
    return FastDay('Tsome Nenewe', 'ጾመ ነነዌ', day: rel + 70, length: 3);
  }
  // Apostles' fast: Monday after Pentecost until Hamle 4.
  final hawaryatEnd = fromEthiopian(e.year, 11, 4);
  if (rel >= 50 && !d.isAfter(hawaryatEnd) && d.month < 9) {
    final len = diff(hawaryatEnd, addDays(fasika, 50)) + 1;
    return FastDay(
      'Tsome Hawaryat (Apostles\' Fast)',
      'ጾመ ሐዋርያት',
      day: rel - 49,
      length: len,
    );
  }
  // Filseta: Nehase 1–15.
  if (e.month == 12 && e.day <= 15) {
    return FastDay('Tsome Filseta', 'ጾመ ፍልሰታ', day: e.day, length: 15);
  }
  // Advent (Prophets' fast): Hidar 15 until the eve of Genna (6 Jan).
  if (e.month == 3 || e.month == 4) {
    final start = fromEthiopian(e.year, 3, 15);
    final end = DateTime(start.year + 1, 1, 6);
    if (!d.isBefore(start) && !d.isAfter(end)) {
      return FastDay(
        'Tsome Nebiyat (Advent)',
        'ጾመ ነቢያት',
        day: diff(d, start) + 1,
        length: diff(end, start) + 1,
      );
    }
  }
  // Gahad: eves of Genna and Timket.
  if ((d.month == 1 && d.day == 6) || (e.month == 5 && e.day == 10)) {
    return const FastDay('Tsome Gahad', 'ጾመ ገሃድ');
  }
  // Weekly fasts, except when Genna or Timket fall on them.
  if (d.weekday == DateTime.wednesday || d.weekday == DateTime.friday) {
    final isFeast =
        (d.month == 1 && d.day == 7) || (e.month == 5 && e.day == 11);
    if (!isFeast) {
      return d.weekday == DateTime.wednesday
          ? const FastDay('Wednesday fast', 'የረቡዕ ጾም')
          : const FastDay('Friday fast', 'የዓርብ ጾም');
    }
  }
  return null;
}
