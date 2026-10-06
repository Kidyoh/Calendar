import 'package:flutter/material.dart';

import '../core/locale.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/theme.dart';
import '../models/event_item.dart';
import '../services/calendar_repository.dart';
import '../widgets/common.dart';
import '../widgets/islands.dart';
import '../widgets/motion.dart';
import 'event_editor.dart';

class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final day = repo.selectedDay;
    final all = repo.eventsOn(day);
    final events = all.where((e) => !e.isReminder).toList();
    final reminders = all.where((e) => e.isReminder).toList();
    final isToday = sameDay(day, DateTime.now());

    return RefreshIndicator(
      onRefresh: repo.reload,
      child: LayoutBuilder(
        // Cream behind the header, white behind the task panel, so the panel
        // always reaches the bottom edge however few tasks there are.
        builder: (context, box) => DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.cream,
                AppColors.cream,
                Colors.white,
                Colors.white,
              ],
              stops: [0, .6, .6, 1],
            ),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(day: day, isToday: isToday),
                  const SizedBox(height: 14),
                  _WeekChips(repo: repo),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: box.maxHeight * .55),
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(38),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 0, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isToday
                                      ? t('Todays tasks')
                                      : AppLocale.am
                                      ? 'የ${weekdayName(day)} ተግባራት'
                                      : '${weekdayName(day)}\'s tasks',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _RemindersPill(
                                count: repo.reminders
                                    .where((r) => !r.done)
                                    .length,
                              ),
                            ],
                          ),
                        ),
                        if (!repo.hasDeviceAccess && repo.deviceSyncSupported)
                          const _ConnectBanner(),
                        if (events.isEmpty && reminders.isEmpty)
                          FadeSlideIn(
                            key: ValueKey('empty-${dayKey(day)}'),
                            child: _Empty(isToday: isToday),
                          ),
                        for (var i = 0; i < events.length; i++) ...[
                          FadeSlideIn.stagger(
                            i,
                            key: ValueKey('${dayKey(day)}-${events[i].id}'),
                            child: Pressable(
                              child: TaskCard(
                                event: events[i],
                                palette: paletteFor(events[i], i),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        for (var i = 0; i < reminders.length; i++)
                          FadeSlideIn.stagger(
                            events.length + i,
                            key: ValueKey('${dayKey(day)}-${reminders[i].id}'),
                            child: _ReminderTile(item: reminders[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DayPalette paletteFor(EventItem e, int i) => e.source == EventSource.local
    ? paletteAt(e.colorIndex)
    : paletteAt(e.colorIndex + i);

class _Header extends StatelessWidget {
  const _Header({required this.day, required this.isToday});
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RollingText(
                weekdayName(day),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              // Same day in the other calendar (Gregorian ⇄ Ethiopian).
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: RollingText(
                    fmtOtherCalendar(day),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mute,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RollingText(
                          '${dayNum(day).toString().padLeft(2, '0')}.${monthNum(day).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 84,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -4,
                            height: .95,
                            color: AppColors.ink,
                          ),
                        ),
                        RollingText(
                          monthShort(day).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 84,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -4,
                            height: .95,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1.2,
                  color: AppColors.ink.withValues(alpha: .7),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Ticker(
                    builder: (context, now) {
                      final local = _fmt(now);
                      String second = '--:--';
                      try {
                        final z = tz.TZDateTime.now(
                          tz.getLocation(repo.secondZone),
                        );
                        second = _fmt(z);
                      } catch (_) {}
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Clock(time: local, label: repo.localZoneLabel),
                          const SizedBox(height: 14),
                          _Clock(time: second, label: repo.secondZoneLabel),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime t) => fmtTime(t);
}

class _Clock extends StatelessWidget {
  const _Clock({required this.time, required this.label});
  final String time;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w500,
            letterSpacing: -.3,
          ),
        ),
      ),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5),
      ),
    ],
  );
}

class _WeekChips extends StatelessWidget {
  const _WeekChips({required this.repo});
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final start = startOfWeek(repo.selectedDay, monday: repo.weekStartsMonday);
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 200) {
          repo.selectDay(addDays(repo.selectedDay, v < 0 ? 7 : -7));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final d = addDays(start, i);
                    final sel = sameDay(d, repo.selectedDay);
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        repo.selectDay(d);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.ink : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekdayShort(d, len: 1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white70 : AppColors.mute,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dayNum(d)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: repo.hasEvents(d)
                                    ? (sel ? Colors.white : AppColors.ink)
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
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.event, required this.palette});
  final EventItem event;
  final DayPalette palette;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final fg = palette.fg;
    return Material(
      color: palette.bg,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: () => showEventEditor(context, existing: e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.8,
                        color: fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Badge(event: e, color: fg),
                ],
              ),
              if (e.location != null && e.location!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 15, color: fg),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        e.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if (e.allDay)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.chip,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t('All day'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: _Time(
                          label: t('Start'),
                          value: fmtTime(e.start),
                          color: fg,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: palette.chip,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            fmtDuration(e.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomRight,
                        child: _Time(
                          label: t('End'),
                          value: fmtTime(e.end),
                          color: fg,
                          end: true,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({
    required this.label,
    required this.value,
    required this.color,
    this.end = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool end;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: -.4,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: color.withValues(alpha: .85)),
      ),
    ],
  );
}

/// Overlapping avatar-style badge: account / calendar initial (device) or a
/// sync-off glyph (local).
class _Badge extends StatelessWidget {
  const _Badge({required this.event, required this.color});
  final EventItem event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final src = event.accountName ?? event.calendarName;
    final device = event.source == EventSource.device;
    final letter = (src != null && src.isNotEmpty)
        ? src[0].toUpperCase()
        : null;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .55),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: device && letter != null
          ? Text(
              letter,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            )
          : Icon(
              device ? Icons.sync : Icons.phone_iphone,
              size: 17,
              color: color,
            ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.item});
  final EventItem item;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onLongPress: () => showEventEditor(context, existing: item),
      onTap: () => repo.toggleDone(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey(item.done),
                color: item.done ? const Color(0xFF2E7D32) : AppColors.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? AppColors.mute : AppColors.ink,
                ),
              ),
            ),
            Text(
              fmtTime(item.start),
              style: const TextStyle(
                color: AppColors.mute,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemindersPill extends StatelessWidget {
  const _RemindersPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _showReminders(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Reminders'),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReminders(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: repo,
        child: Consumer<CalendarRepository>(
          builder: (ctx, repo, _) {
            final list = repo.reminders;
            return Material(
              color: AppColors.paper,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(36),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('Reminders'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        RoundIconButton(
                          icon: Icons.add,
                          onTap: () => showEventEditor(ctx, reminder: true),
                          tooltip: t('Add reminder'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (list.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          t('Nothing to remember. Tap + to add one.'),
                          style: TextStyle(color: AppColors.mute),
                        ),
                      ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final r in list)
                            Dismissible(
                              key: ValueKey(r.id),
                              background: Container(
                                color: Colors.red.withValues(alpha: .15),
                              ),
                              onDismissed: (_) => repo.deleteEvent(r),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Checkbox(
                                  shape: const CircleBorder(),
                                  value: r.done,
                                  onChanged: (_) => repo.toggleDone(r),
                                ),
                                title: Text(
                                  r.title,
                                  style: TextStyle(
                                    decoration: r.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${weekdayShort(r.start, len: 3)} ${dayNum(r.start)} ${monthShort(r.start)} · ${fmtTime(r.start)}',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConnectBanner extends StatelessWidget {
  const _ConnectBanner();
  @override
  Widget build(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              t('Sync Google, iCloud & Outlook events'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: repo.connectDeviceCalendars,
            child: Text(t('Connect')),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.isToday});
  final bool isToday;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.wb_twilight_rounded,
            size: 46,
            color: AppColors.ink.withValues(alpha: .25),
          ),
          const SizedBox(height: 10),
          Text(
            isToday ? t('A clear day. Enjoy it.') : t('Nothing planned.'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            t('Tap + to add an event'),
            style: TextStyle(color: AppColors.mute),
          ),
        ],
      ),
    ),
  );
}
