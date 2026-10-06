/// Ethiopian (Ge'ez) calendar conversion via Julian Day Numbers.
///
/// 12 months of 30 days plus Pagume (5 days, 6 in the year before a
/// Gregorian leap year, i.e. when `year % 4 == 3`). New year (Enkutatash)
/// is Meskerem 1, which falls on 11 or 12 September.
class EthDate {
  const EthDate(this.year, this.month, this.day);
  final int year;
  final int month; // 1..13
  final int day;

  @override
  bool operator ==(Object other) =>
      other is EthDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}

const _epoch = 1723856; // JDN of Meskerem 1, year 1 (Amete Mihret) minus offset

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
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return DateTime(year, month, day);
}

EthDate toEthiopian(DateTime g) {
  final jdn = _gregToJdn(g.year, g.month, g.day);
  final r = (jdn - _epoch) % 1461;
  final n = r % 365 + 365 * (r ~/ 1460);
  final year = 4 * ((jdn - _epoch) ~/ 1461) + r ~/ 365 - r ~/ 1460;
  return EthDate(year, n ~/ 30 + 1, n % 30 + 1);
}

DateTime fromEthiopian(int year, int month, int day) => _jdnToGreg(
  _epoch + 365 + 365 * (year - 1) + year ~/ 4 + 30 * month + day - 31,
);

int ethDaysInMonth(int year, int month) =>
    month < 13 ? 30 : (year % 4 == 3 ? 6 : 5);

const ethMonthsAm = [
  'መስከረም',
  'ጥቅምት',
  'ኅዳር',
  'ታኅሣሥ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜ',
];
const ethMonthsEn = [
  'Meskerem',
  'Tikimt',
  'Hidar',
  'Tahsas',
  'Tir',
  'Yekatit',
  'Megabit',
  'Miyazya',
  'Ginbot',
  'Sene',
  'Hamle',
  'Nehase',
  'Pagume',
];
