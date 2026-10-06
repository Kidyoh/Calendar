import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/holidays.dart';

List<String> names(DateTime d, {bool saints = false}) =>
    holidaysOn(d, saints: saints).map((h) => h.en).toList();

void main() {
  test('Fasika matches published Orthodox Easter dates', () {
    expect(orthodoxEaster(2024), DateTime(2024, 5, 5));
    expect(orthodoxEaster(2025), DateTime(2025, 4, 20));
    expect(orthodoxEaster(2026), DateTime(2026, 4, 12));
    expect(orthodoxEaster(2027), DateTime(2027, 5, 2));
    expect(orthodoxEaster(2028), DateTime(2028, 4, 16));
  });

  test('fixed public holidays land on the right Gregorian days', () {
    expect(names(DateTime(2026, 9, 11)), contains('Enkutatash (New Year)'));
    expect(
      names(DateTime(2027, 9, 12)),
      contains('Enkutatash (New Year)'),
    ); // after Pagume 6
    expect(names(DateTime(2026, 9, 27)), contains('Meskel'));
    expect(names(DateTime(2026, 1, 7)), contains('Genna (Christmas)'));
    expect(names(DateTime(2026, 1, 19)), contains('Timket (Epiphany)'));
    expect(
      names(DateTime(2028, 1, 20)),
      contains('Timket (Epiphany)'),
    ); // leap-year shift
    expect(names(DateTime(2026, 3, 2)), contains('Adwa Victory Day'));
    expect(names(DateTime(2026, 5, 5)), contains('Patriots\' Victory Day'));
    expect(names(DateTime(2026, 5, 28)), contains('Downfall of the Derg'));
    expect(names(DateTime(2026, 5, 1)), contains('Labour Day'));
    expect(names(DateTime(2026, 4, 10)), contains('Siklet (Good Friday)'));
  });

  test('Islamic holidays are within a day of the observed dates', () {
    bool near(String name, DateTime d) => [
      -1,
      0,
      1,
    ].any((o) => names(DateTime(d.year, d.month, d.day + o)).contains(name));
    expect(near('Eid al-Fitr', DateTime(2025, 3, 30)), isTrue);
    expect(near('Eid al-Adha (Arafa)', DateTime(2025, 6, 6)), isTrue);
    expect(near('Mawlid', DateTime(2025, 9, 4)), isTrue);
    expect(near('Eid al-Fitr', DateTime(2026, 3, 20)), isTrue);
    expect(near('Eid al-Adha (Arafa)', DateTime(2026, 5, 27)), isTrue);
  });

  test('fasting seasons', () {
    // 2026: Fasika 12 Apr -> Abiy Tsom 16 Feb .. 11 Apr, Nenewe 2-4 Feb.
    expect(fastOn(DateTime(2026, 2, 16))!.en, startsWith('Abiy Tsom'));
    expect(fastOn(DateTime(2026, 2, 16))!.day, 1);
    expect(fastOn(DateTime(2026, 4, 11))!.day, 55);
    expect(fastOn(DateTime(2026, 2, 2))!.en, 'Tsome Nenewe');
    expect(fastOn(DateTime(2026, 2, 4))!.day, 3);
    // 50 days after Fasika: even Wednesdays and Fridays are free.
    expect(fastOn(DateTime(2026, 4, 15)), isNull); // a Wednesday
    expect(
      fastOn(DateTime(2026, 5, 29)),
      isNull,
    ); // Friday before Pentecost (31 May)
    // Apostles' fast starts the Monday after Pentecost and ends Hamle 4 (11 July).
    expect(fastOn(DateTime(2026, 6, 1))!.en, startsWith('Tsome Hawaryat'));
    expect(fastOn(DateTime(2026, 7, 11))!.en, startsWith('Tsome Hawaryat'));
    expect(
      fastOn(DateTime(2026, 7, 12))?.en ?? '',
      isNot(startsWith('Tsome Hawaryat')),
    );
    // Filseta: Nehase 1-15 = 7-21 Aug 2026.
    expect(fastOn(DateTime(2026, 8, 7))!.en, 'Tsome Filseta');
    expect(fastOn(DateTime(2026, 8, 21))!.day, 15);
    // Advent: Hidar 15 (24 Nov 2026) .. Tahsas 28 (6 Jan 2027).
    expect(fastOn(DateTime(2026, 11, 24))!.en, startsWith('Tsome Nebiyat'));
    expect(fastOn(DateTime(2026, 11, 24))!.day, 1);
    expect(fastOn(DateTime(2027, 1, 6))!.en, startsWith('Tsome Nebiyat'));
    // Ordinary Wednesday / Friday, and no fast when Genna is on a Wednesday.
    expect(fastOn(DateTime(2026, 10, 7))!.en, 'Wednesday fast');
    expect(fastOn(DateTime(2026, 10, 9))!.en, 'Friday fast');
    expect(fastOn(DateTime(2026, 10, 6)), isNull); // Tuesday
    expect(
      fastOn(DateTime(2025, 1, 7)),
      isNull,
    ); // Genna 2025 was a Tuesday anyway
    expect(fastOn(DateTime(2032, 1, 7)), isNull); // Genna on a Wednesday
  });

  test('Orthodox feasts that are days off are labelled as both', () {
    Holiday find(DateTime d, String en) =>
        holidaysOn(d).firstWhere((h) => h.en == en);
    for (final (d, en) in [
      (DateTime(2026, 4, 12), 'Fasika (Easter)'),
      (DateTime(2026, 4, 10), 'Siklet (Good Friday)'),
      (DateTime(2026, 1, 7), 'Genna (Christmas)'),
      (DateTime(2026, 1, 19), 'Timket (Epiphany)'),
      (DateTime(2026, 9, 27), 'Meskel'),
    ]) {
      final h = find(d, en);
      expect(h.kind, HolidayKind.orthodox, reason: en);
      expect(h.dayOff, isTrue, reason: en);
    }
    expect(
      find(DateTime(2026, 3, 2), 'Adwa Victory Day').kind,
      HolidayKind.national,
    );
    expect(
      find(DateTime(2026, 9, 11), 'Enkutatash (New Year)').kind,
      HolidayKind.national,
    );
  });

  test('monthly saints only when enabled', () {
    final mikael = DateTime(2026, 9, 22); // Meskerem 12
    expect(names(mikael), isNot(contains('Kidus Mikael')));
    expect(names(mikael, saints: true), contains('Kidus Mikael'));
  });
}
