import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/holidays.dart';
import '../core/locale.dart';
import '../core/theme.dart';
import '../services/calendar_repository.dart';
import 'motion.dart';

/// Warm red for public holidays; sage for fasting.
const holidayRed = Color(0xFFB4413C);
const fastSage = Color(0xFF55661B);

IconData holidayIcon(HolidayKind k) => switch (k) {
  HolidayKind.national => Icons.flag_rounded,
  HolidayKind.orthodox => Icons.church_rounded,
  HolidayKind.islamic => Icons.mosque_rounded,
  HolidayKind.saint => Icons.auto_awesome_rounded,
};

String holidayKindLabel(Holiday h) {
  final base = switch (h.kind) {
    HolidayKind.national => t('Public holiday'),
    HolidayKind.orthodox => t('Orthodox feast'),
    HolidayKind.islamic => t('Islamic holiday'),
    HolidayKind.saint => t('Saint\'s day'),
  };
  return [
    base,
    if (h.kind != HolidayKind.national && h.dayOff) t('Public holiday'),
    if (h.approximate) t('may shift a day'),
  ].join(' · ');
}

DayPalette _paletteFor(Holiday h) => switch (h.kind) {
  HolidayKind.national => const DayPalette(
    AppColors.ink,
    Colors.white,
    Color(0xFFE6BA6E),
  ),
  HolidayKind.orthodox => palettes[4],
  HolidayKind.islamic => palettes[2],
  HolidayKind.saint => palettes[0],
};

/// Big card on the Today screen for each holiday.
class HolidayBanner extends StatelessWidget {
  const HolidayBanner({super.key, required this.holiday});
  final Holiday holiday;

  @override
  Widget build(BuildContext context) {
    final p = _paletteFor(holiday);
    final dark = holiday.kind == HolidayKind.national;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(28),
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E1E), Color(0xFF0B0B0B)],
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? p.chip.withValues(alpha: .18)
                  : Colors.white.withValues(alpha: .55),
            ),
            child: Icon(
              holidayIcon(holiday.kind),
              color: dark ? p.chip : p.fg,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: TextStyle(
                    color: p.fg,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holidayKindLabel(holiday),
                  style: TextStyle(
                    color: dark ? p.chip : p.fg.withValues(alpha: .8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fasting tile on the Today screen (with season progress when available).
class FastBanner extends StatelessWidget {
  const FastBanner({super.key, required this.fast});
  final FastDay fast;

  @override
  Widget build(BuildContext context) {
    const p = DayPalette(Color(0xFFE3E8CF), fastSage, fastSage);
    final progress = fast.progress;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: fastSage, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${t('Fasting day')} · ${fast.name}',
                  style: const TextStyle(
                    color: fastSage,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (progress != null)
                Text(
                  progress,
                  style: TextStyle(
                    color: fastSage.withValues(alpha: .8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (fast.day != null && fast.length != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fast.day! / fast.length!),
                duration: Motion.slow,
                curve: Motion.ease,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: fastSage.withValues(alpha: .15),
                  valueColor: const AlwaysStoppedAnimation(fastSage),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Holidays & fasts" list for the focused month on the Calendar tab.
class MonthHolidaysCard extends StatelessWidget {
  const MonthHolidaysCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final m = repo.focusedMonth;
    final n = daysInMonthOf(m);

    final rows = <Widget>[];
    // Fasting seasons: name + first/last day inside this month.
    final seasons = <String, (DateTime, DateTime, FastDay)>{};
    var weekly = 0;
    for (var i = 0; i < n; i++) {
      final d = addDays(m, i);
      for (final h in repo.holidaysFor(d)) {
        rows.add(
          _row(
            context,
            d,
            holidayIcon(h.kind),
            h.name,
            holidayKindLabel(h),
            h.dayOff ? holidayRed : AppColors.ink,
          ),
        );
      }
      final f = repo.fastFor(d);
      if (f == null) continue;
      if (f.length == null) {
        weekly++;
      } else {
        final prev = seasons[f.en];
        seasons[f.en] = (prev?.$1 ?? d, d, f);
      }
    }
    for (final (from, to, f) in seasons.values) {
      rows.add(
        _row(
          context,
          from,
          Icons.eco_rounded,
          f.name,
          '${monthShort(from)} ${dayNum(from)} – ${monthShort(to)} ${dayNum(to)}',
          fastSage,
          range: true,
        ),
      );
    }
    if (weekly > 0) {
      rows.add(
        _row(
          context,
          null,
          Icons.eco_outlined,
          t('Wednesdays & Fridays'),
          t('Fasting day'),
          fastSage,
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Holidays & fasts').toUpperCase(),
              style: const TextStyle(
                color: AppColors.mute,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  t('Nothing this month'),
                  style: const TextStyle(color: AppColors.mute),
                ),
              ),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    DateTime? d,
    IconData icon,
    String title,
    String sub,
    Color color, {
    bool range = false,
  }) {
    final repo = context.read<CalendarRepository>();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: d == null ? null : () => repo.selectDay(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: d == null || range
                  ? Icon(icon, color: color, size: 22)
                  : Column(
                      children: [
                        Text(
                          '${dayNum(d)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1,
                          ),
                        ),
                        Text(
                          weekdayShort(d, len: 3),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mute,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: AppColors.mute,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!range && d != null)
              Icon(icon, size: 18, color: color.withValues(alpha: .7)),
          ],
        ),
      ),
    );
  }
}
