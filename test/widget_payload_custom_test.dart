import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_calendar/core/calendar_faces.dart';
import 'package:glass_calendar/core/holidays.dart';
import 'package:glass_calendar/models/event_item.dart';
import 'package:glass_calendar/services/calendar_repository.dart';
import 'package:glass_calendar/services/widget_sync.dart';

void main() {
  final now = DateTime(2026, 10, 6, 9);

  test('payload carries month grids, agenda, feasts and fasts', () {
    final p = buildWidgetPayload(
      [
        EventItem(
          id: 'a',
          title: 'Design review',
          start: DateTime(2026, 10, 6, 14),
          end: DateTime(2026, 10, 6, 15),
        ),
        EventItem(
          id: 'old',
          title: 'Yesterday',
          start: DateTime(2026, 10, 5, 14),
          end: DateTime(2026, 10, 5, 15),
        ),
      ],
      now,
      holidays: (d) => holidaysOn(d),
      fasts: fastOn,
    );
    final months = jsonDecode(p['face_months']!) as List;
    expect(months.length, CalFace.values.length);
    // Gregorian: October 2026 starts on the 1st and has 31 days.
    expect(
      (months[0] as List).any(
        (m) => m[0] == '20261001' && m[1] == 31 && m[2] == 'October 2026',
      ),
      isTrue,
    );
    // Ethiopian: Meskerem 2019 started on Sept 11, 2026.
    expect(
      (months[1] as List).any((m) => m[0] == '20260911' && m[1] == 30),
      isTrue,
    );
    final years = jsonDecode(p['face_years']!) as List;
    expect(years[0][0], '20260101');
    expect(years[1][3], 13);

    final agenda = jsonDecode(p['agenda']!) as List;
    expect(agenda.first[2], 'Design review');
    expect(agenda.any((a) => a[2] == 'Yesterday'), isFalse);

    final feasts = jsonDecode(p['feasts']!) as List;
    expect(feasts, isNotEmpty);
    expect(feasts.map((f) => f[1]), contains('Genna (Christmas)'));
    expect(p['hol_days'], contains('20260927')); // Meskel
    // face_days covers the month grids (−45…+80 days).
    expect(p['face_days'], contains('20260823:'));
    expect(p['face_days'], contains('20261225:'));
    expect(utf8.encode(p.values.join()).length, lessThan(60000));
  });

  test('widget instances keep their view and style; v1 lists upgrade', () {
    final w = WidgetInstance('glass-1', 'glass', CalFace.ethiopian);
    expect(w.view, 'week');
    expect(w.style, 'glass');
    final back = WidgetInstance.fromJson(
      jsonDecode(jsonEncode({...w.toJson(), 'view': 'month', 'style': 'light'}))
          as Map<String, dynamic>,
    );
    expect(back.view, 'month');
    expect(back.style, 'light');
    expect(back.face, CalFace.ethiopian);
    // Unknown values fall back to the type's defaults.
    final odd = WidgetInstance(
      'p',
      'progress',
      CalFace.gregorian,
      view: 'agenda',
      style: 'neon',
    );
    expect(odd.view, 'day');
    expect(odd.style, 'dark');
  });

  test('face months and years', () {
    final d = DateTime(2026, 10, 6);
    expect(faceMonth(CalFace.gregorian, d), (DateTime(2026, 10), 31));
    expect(faceMonth(CalFace.ethiopian, d).$1, DateTime(2026, 9, 11));
    // Pagume: 5 or 6 days.
    final pag = faceMonth(CalFace.ethiopian, DateTime(2026, 9, 8));
    expect(pag.$2, inInclusiveRange(5, 6));
    final next = shiftFaceMonth(CalFace.ethiopian, DateTime(2026, 9, 8), 1);
    expect(next, DateTime(2026, 9, 11));
    final prev = shiftFaceMonth(CalFace.islamic, d, -1);
    expect(faceMonth(CalFace.islamic, prev).$1, prev);
    expect(faceYear(CalFace.ethiopian, d).$1, DateTime(2026, 9, 11));
  });
}
