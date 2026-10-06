import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/locale.dart';
import '../core/theme.dart';
import '../models/event_item.dart';
import '../services/calendar_repository.dart';
import '../widgets/motion.dart';
import 'event_editor.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key, required this.onOpenDay});
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final month = repo.focusedMonth;
    final daysInMonth = daysInMonthOf(month);
    final days = <DateTime>[
      for (var d = 1; d <= daysInMonth; d++)
        if (repo.hasEvents(addDays(month, d - 1)) ||
            sameDay(addDays(month, d - 1), repo.selectedDay))
          addDays(month, d - 1),
    ];

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 250) repo.shiftMonth(v < 0 ? 1 : -1);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
        children: [
          _MonthSwitcher(repo: repo),
          const SizedBox(height: 14),
          _MonthGrid(repo: repo),
          const SizedBox(height: 14),
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No events this month')),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Column(
                key: ValueKey('${dayKey(month)}-${dayKey(repo.selectedDay)}'),
                children: [
                  for (var i = 0; i < days.length; i++)
                    FadeSlideIn.stagger(
                      i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Pressable(
                          scale: .98,
                          child: DayCard(
                            day: days[i],
                            palette: paletteAt(dayNum(days[i])),
                            onOpenDay: onOpenDay,
                          ),
                        ),
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

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.repo});
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final m = repo.focusedMonth;
    final prev = shiftMonths(m, -1);
    final next = shiftMonths(m, 1);
    Widget ghost(DateTime d, int delta) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => repo.shiftMonth(delta),
        child: Center(
          child: Text(
            monthShort(d).toUpperCase(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: AppColors.ink.withValues(alpha: .22),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          ghost(prev, -1),
          IconButton(
            onPressed: () => repo.shiftMonth(-1),
            icon: const Icon(Icons.chevron_left, size: 22),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(m),
              children: [
                Text(
                  monthShort(m).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${yearNum(m)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => repo.shiftMonth(1),
            icon: const Icon(Icons.chevron_right, size: 22),
          ),
          ghost(next, 1),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.repo});
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final m = repo.focusedMonth;
    final first = m;
    final gridStart = startOfWeek(first, monday: repo.weekStartsMonday);
    final count = daysInMonthOf(m);
    final weeks = ((first.difference(gridStart).inDays + count) / 7).ceil();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayShort(addDays(gridStart, i), len: 1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var w = 0; w < weeks; w++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final d = addDays(gridStart, w * 7 + i);
                        final inMonth = sameMonth(d, m);
                        final sel = sameDay(d, repo.selectedDay);
                        final today = sameDay(d, DateTime.now());
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => repo.selectDay(d),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sel
                                        ? AppColors.ink
                                        : Colors.transparent,
                                    border: !sel && today
                                        ? Border.all(
                                            color: AppColors.ink,
                                            width: 1.3,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    '${dayNum(d)}',
                                    style: TextStyle(
                                      fontWeight: sel
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : inMonth
                                          ? AppColors.ink
                                          : AppColors.ink.withValues(
                                              alpha: .25,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: repo.hasEvents(d)
                                        ? paletteAt(dayNum(d)).chip
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A coloured day card with up to three hour columns, chips and "+" slots.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.day,
    required this.palette,
    required this.onOpenDay,
  });
  final DateTime day;
  final DayPalette palette;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final all = repo.eventsOn(day);
    final allDay = all.where((e) => e.allDay).toList();
    final reminders = all.where((e) => e.isReminder).toList();
    final timed = all.where((e) => !e.allDay && !e.isReminder).toList();

    final hours = <int>{...timed.map((e) => e.start.hour)}.toList()..sort();
    final shown = hours.take(3).toList();
    for (final h in const [9, 13, 17, 11, 15, 19]) {
      if (shown.length >= 3) break;
      if (!shown.contains(h)) shown.add(h);
    }
    shown.sort();
    final overflow = timed.where((e) => !shown.contains(e.start.hour)).toList();
    final selected = sameDay(day, repo.selectedDay);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(34),
        border: selected
            ? Border.all(color: palette.fg.withValues(alpha: .55), width: 1.6)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  repo.selectDay(day);
                  onOpenDay();
                },
                child: SizedBox(
                  width: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdayName(day),
                        style: TextStyle(
                          color: palette.fg,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${dayNum(day)}\n${monthShort(day).toUpperCase()}',
                          style: TextStyle(
                            color: palette.fg,
                            fontSize: 52,
                            height: .92,
                            letterSpacing: -2.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final h in shown)
                        Expanded(
                          child: _Slot(
                            hour: h,
                            palette: palette,
                            events: timed
                                .where((e) => e.start.hour == h)
                                .toList(),
                            onAdd: () =>
                                showEventEditor(context, day: day, hour: h),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (allDay.isNotEmpty ||
              reminders.isNotEmpty ||
              overflow.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in allDay)
                  _Chip(
                    event: e,
                    palette: palette,
                    prefix: '${t('All day')} · ',
                  ),
                if (overflow.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      repo.selectDay(day);
                      onOpenDay();
                    },
                    child: _ChipBox(
                      palette: palette,
                      text: '+${overflow.length} ${t('more')}',
                      outlined: true,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.hour,
    required this.palette,
    required this.events,
    required this.onAdd,
  });
  final int hour;
  final DayPalette palette;
  final List<EventItem> events;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: palette.fg.withValues(alpha: .45), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmtHour(hour),
            style: TextStyle(
              color: palette.fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          for (final e in events.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _Chip(event: e, palette: palette),
            ),
          if (events.length > 2)
            Text(
              '+${events.length - 2}',
              style: TextStyle(
                color: palette.fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Spacer(),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.fg.withValues(alpha: .6)),
              ),
              child: Icon(Icons.add, size: 15, color: palette.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.event, required this.palette, this.prefix = ''});
  final EventItem event;
  final DayPalette palette;
  final String prefix;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showEventEditor(context, existing: event),
    child: _ChipBox(palette: palette, text: '$prefix${event.title}'),
  );
}

class _ChipBox extends StatelessWidget {
  const _ChipBox({
    required this.palette,
    required this.text,
    this.outlined = false,
  });
  final DayPalette palette;
  final String text;
  final bool outlined;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: outlined ? Colors.transparent : palette.chip,
      borderRadius: BorderRadius.circular(12),
      border: outlined
          ? Border.all(color: palette.fg.withValues(alpha: .6))
          : null,
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: outlined ? palette.fg : Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
