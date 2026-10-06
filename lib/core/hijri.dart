/// Tabular (arithmetic) Islamic calendar. Real observance follows the moon
/// sighting and can be a day earlier or later.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);
  final int year;
  final int month; // 1..12
  final int day;

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}

int _gregToJdn(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  return d +
      (153 * mm + 2) ~/ 5 +
      365 * yy +
      yy ~/ 4 -
      yy ~/ 100 +
      yy ~/ 400 -
      32045;
}

DateTime _jdnToGreg(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - 146097 * b ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - 1461 * d ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  return DateTime(
    100 * b + d - 4800 + m ~/ 10,
    m + 3 - 12 * (m ~/ 10),
    e - (153 * m + 2) ~/ 5 + 1,
  );
}

int _hijriToJdn(int y, int m, int d) =>
    d +
    (29.5 * (m - 1)).ceil() +
    (y - 1) * 354 +
    ((3 + 11 * y) / 30).floor() +
    1948439 -
    1 +
    1;

DateTime hijriToGregorian(int y, int m, int d) =>
    _jdnToGreg(_hijriToJdn(y, m, d));

HijriDate toHijri(DateTime g) {
  final jdn = _gregToJdn(g.year, g.month, g.day);
  var y = ((30 * (jdn - 1948439) + 10646) / 10631).floor();
  // The estimate can be off by one right at a new year: settle it exactly.
  while (jdn < _hijriToJdn(y, 1, 1)) {
    y--;
  }
  while (jdn >= _hijriToJdn(y + 1, 1, 1)) {
    y++;
  }
  var m = 1;
  while (m < 12 && jdn >= _hijriToJdn(y, m + 1, 1)) {
    m++;
  }
  return HijriDate(y, m, jdn - _hijriToJdn(y, m, 1) + 1);
}

int hijriMonthLength(int y, int m) =>
    _hijriToJdn(m == 12 ? y + 1 : y, m == 12 ? 1 : m + 1, 1) -
    _hijriToJdn(y, m, 1);

const hijriMonthsEn = [
  'Muharram',
  'Safar',
  'Rabiʿ al-Awwal',
  'Rabiʿ al-Thani',
  'Jumada al-Ula',
  'Jumada al-Akhira',
  'Rajab',
  'Shaʿban',
  'Ramadan',
  'Shawwal',
  'Dhu al-Qaʿda',
  'Dhu al-Hijja',
];
const hijriMonthsAr = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];
const hijriMonthsAm = [
  'ሙሐረም',
  'ሰፈር',
  'ረቢዑል አወል',
  'ረቢዑል አኺር',
  'ጀማደል ኡላ',
  'ጀማደል አኺር',
  'ረጀብ',
  'ሻዕባን',
  'ረመዳን',
  'ሸዋል',
  'ዙል ቃዕዳ',
  'ዙል ሒጃ',
];
