import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/dates.dart';
import 'package:glass_calendar/core/ethiopian.dart';
import 'package:glass_calendar/core/locale.dart';

void main() {
  tearDown(() {
    AppLocale.lang = 'en';
    AppLocale.ethiopian = false;
  });

  test('known dates convert both ways', () {
    final cases = {
      DateTime(2026, 10, 6): const EthDate(2019, 1, 26),
      DateTime(2026, 9, 11): const EthDate(2019, 1, 1), // Enkutatash
      DateTime(2023, 9, 12): const EthDate(
        2016,
        1,
        1,
      ), // before Greg. leap year
      DateTime(2026, 1, 7): const EthDate(2018, 4, 29), // Genna
      DateTime(2026, 1, 19): const EthDate(2018, 5, 11), // Timket
      DateTime(2027, 9, 11): const EthDate(2019, 13, 6), // Pagume 6
      DateTime(1896, 3, 1): const EthDate(1888, 6, 23), // Adwa
    };
    cases.forEach((g, e) {
      expect(toEthiopian(g), e, reason: '$g');
      expect(fromEthiopian(e.year, e.month, e.day), g, reason: '$e');
    });
  });

  test('round trip is exact across 40 years', () {
    for (var d = DateTime(1990, 1, 1); d.year < 2030; d = addDays(d, 1)) {
      final e = toEthiopian(d);
      expect(e.day <= ethDaysInMonth(e.year, e.month), isTrue);
      expect(fromEthiopian(e.year, e.month, e.day), d);
    }
  });

  test('month arithmetic follows the Ethiopian calendar', () {
    AppLocale.ethiopian = true;
    final oct6 = DateTime(2026, 10, 6);
    expect(monthStart(oct6), DateTime(2026, 9, 11)); // Meskerem 1
    expect(daysInMonthOf(oct6), 30);
    // Nehase 2019 -> Pagume 2019 (6 days, leap) -> Meskerem 2020
    final nehase = fromEthiopian(2019, 12, 1);
    final pagume = shiftMonths(nehase, 1);
    expect(toEthiopian(pagume), const EthDate(2019, 13, 1));
    expect(daysInMonthOf(pagume), 6);
    expect(toEthiopian(shiftMonths(pagume, 1)), const EthDate(2020, 1, 1));
    expect(
      toEthiopian(shiftMonths(fromEthiopian(2019, 1, 1), -1)),
      const EthDate(2018, 13, 1),
    );
    expect(dayNum(oct6), 26);
    expect(monthName(oct6), 'Meskerem');
    AppLocale.lang = 'am';
    expect(monthName(oct6), 'መስከረም');
    expect(weekdayName(oct6), 'ማክሰኞ');
    expect(fmtOtherCalendar(oct6), 'ኦክቶበር 6, 2026');
  });

  test('Amharic strings and time formatting', () {
    AppLocale.lang = 'am';
    expect(t('Today'), 'ዛሬ');
    expect(t('Not translated yet'), 'Not translated yet');
    expect(fmtTime(DateTime(2026, 1, 1, 15, 5)), '3:05 ከሰዓት');
    expect(fmtDuration(const Duration(minutes: 30)), '30 ደቂቃ');
    AppLocale.lang = 'en';
    expect(fmtTime(DateTime(2026, 1, 1, 9, 0)), '9:00 AM');
    expect(fmtOtherCalendar(DateTime(2026, 10, 6)), 'Meskerem 26, 2019');
  });
}
