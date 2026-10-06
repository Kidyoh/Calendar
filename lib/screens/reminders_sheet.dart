import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/locale.dart';
import '../core/theme.dart';
import '../models/event_item.dart';
import '../services/calendar_repository.dart';
import '../services/notification_service.dart';
import '../widgets/cal_date_picker.dart';
import '../widgets/motion.dart';

Future<void> showRemindersSheet(BuildContext context) {
  final repo = context.read<CalendarRepository>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: repo,
      child: const _RemindersSheet(),
    ),
  );
}

class _RemindersSheet extends StatefulWidget {
  const _RemindersSheet();
  @override
  State<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends State<_RemindersSheet> {
  final _text = TextEditingController();
  int _when = 0; // 0 in 1h · 1 this evening · 2 tomorrow 9:00 · 3 picked
  DateTime? _picked;
  Repeat _repeat = Repeat.none;
  bool _showDone = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  DateTime _resolve() {
    final now = DateTime.now();
    switch (_when) {
      case 0:
        return DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        ).add(const Duration(hours: 1));
      case 1:
        final eve = DateTime(now.year, now.month, now.day, 18);
        return eve.isAfter(now.add(const Duration(minutes: 30)))
            ? eve
            : DateTime(now.year, now.month, now.day, now.hour + 3);
      case 2:
        final t = addDays(dateOnly(now), 1);
        return DateTime(t.year, t.month, t.day, 9);
      default:
        return _picked ?? now.add(const Duration(hours: 1));
    }
  }

  Future<void> _pick() async {
    final repo = context.read<CalendarRepository>();
    final d = await showCalDatePicker(
      context,
      initial: _picked ?? DateTime.now(),
      weekStartsMonday: repo.weekStartsMonday,
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _picked ?? DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    if (tm == null) return;
    setState(() {
      _picked = DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
      _when = 3;
    });
  }

  Future<void> _add() async {
    final title = _text.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.mediumImpact();
    final repo = context.read<CalendarRepository>();
    await repo.addReminder(
      title,
      _resolve(),
      repeat: _repeat,
      colorIndex: (repo.reminders.length + 4) % palettes.length,
    );
    await NotificationService.requestPermission();
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final now = DateTime.now();
    final today = dateOnly(now), tomorrow = addDays(today, 1);
    final all = repo.reminders;
    final open = all.where((r) => !r.done).toList();
    final overdue = open
        .where((r) => r.start.isBefore(now) && !sameDay(r.start, today))
        .toList();
    final todays = open.where((r) => sameDay(r.start, today)).toList();
    final tomorrows = open.where((r) => sameDay(r.start, tomorrow)).toList();
    final later = open
        .where(
          (r) => r.start.isAfter(
            addDays(tomorrow, 1).subtract(const Duration(seconds: 1)),
          ),
        )
        .toList();
    final done = all.where((r) => r.done).toList();
    final todayAll = all.where((r) => sameDay(r.start, today)).toList();
    final todayDone = todayAll.where((r) => r.done).length;

    Widget section(String title, List<EventItem> items, {Color? accent}) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent ?? AppColors.mute,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: (accent ?? AppColors.mute).withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: accent ?? AppColors.mute,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            FadeSlideIn.stagger(
              i,
              key: ValueKey('r-${items[i].id}-${items[i].start}'),
              child: _ReminderCard(item: items[i], overdue: accent != null),
            ),
        ],
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .5,
      maxChildSize: .96,
      builder: (context, controller) => Material(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            30 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Reminders'),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        todayAll.isEmpty
                            ? t('Nothing to remember. Tap + to add one.')
                            : '$todayDone/${todayAll.length} ${t('of today done')}',
                        style: const TextStyle(
                          color: AppColors.mute,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _ProgressRing(
                  value: todayAll.isEmpty ? 0 : todayDone / todayAll.length,
                  label: '$todayDone/${todayAll.length}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ---- quick add
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: Color(0xFFB7791F),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _add(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: t('Remind me to…'),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Pressable(
                        scale: .85,
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _text.text.trim().isEmpty
                                ? Colors.black12
                                : AppColors.ink,
                          ),
                          child: IconButton(
                            tooltip: t('Add reminder'),
                            onPressed: _text.text.trim().isEmpty ? null : _add,
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (i, label) in [
                          t('In 1 hour'),
                          t('This evening'),
                          t('Tomorrow 9:00'),
                          _when == 3 && _picked != null
                              ? '${monthShort(_picked!)} ${dayNum(_picked!)} · ${fmtTime(_picked!)}'
                              : t('Pick time'),
                        ].indexed)
                          _Chip(
                            label: label,
                            icon: i == 3
                                ? Icons.event_outlined
                                : Icons.schedule_rounded,
                            selected: _when == i,
                            onTap: () =>
                                i == 3 ? _pick() : setState(() => _when = i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    children: [
                      for (final (r, label) in [
                        (Repeat.none, t('Once')),
                        (Repeat.daily, t('Daily')),
                        (Repeat.weekly, t('Weekly')),
                      ])
                        _Chip(
                          label: label,
                          icon: r == Repeat.none
                              ? Icons.looks_one_outlined
                              : Icons.repeat_rounded,
                          selected: _repeat == r,
                          small: true,
                          onTap: () => setState(() => _repeat = r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            section(t('Overdue'), overdue, accent: const Color(0xFFB4413C)),
            section(t('Today'), todays),
            section(t('Tomorrow'), tomorrows),
            section(t('Later'), later),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setState(() => _showDone = !_showDone),
                child: Row(
                  children: [
                    Text(
                      '${t('Completed').toUpperCase()}  ${done.length}',
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _showDone ? .5 : 0,
                      duration: Motion.fast,
                      child: const Icon(
                        Icons.expand_more,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: Motion.medium,
                curve: Motion.ease,
                child: _showDone
                    ? Column(
                        children: [
                          for (final r in done)
                            _ReminderCard(item: r, overdue: false),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Floating(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: AppColors.ink.withValues(alpha: .2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('Nothing to remember. Tap + to add one.'),
                      style: const TextStyle(color: AppColors.mute),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.small = false,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6),
      child: Pressable(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: EdgeInsets.symmetric(
              horizontal: small ? 11 : 13,
              vertical: small ? 7 : 9,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.cream,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: small ? 14 : 16,
                  color: selected ? Colors.white : AppColors.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: small ? 12.5 : 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.item, required this.overdue});
  final EventItem item;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    final p = paletteAt(item.colorIndex);
    final r = item;
    final when = sameDay(r.start, DateTime.now())
        ? fmtTime(r.start)
        : '${weekdayShort(r.start, len: 3)} ${dayNum(r.start)} · ${fmtTime(r.start)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('d-${r.id}'),
        background: _swipeBg(
          Alignment.centerLeft,
          const Color(0xFFC5CE9B),
          Icons.check_rounded,
        ),
        secondaryBackground: _swipeBg(
          Alignment.centerRight,
          const Color(0xFFD09BA6),
          Icons.delete_outline_rounded,
        ),
        confirmDismiss: (dir) async {
          HapticFeedback.mediumImpact();
          if (dir == DismissDirection.startToEnd) {
            await repo.toggleDone(r);
            return false; // stays in the list, moves to Completed / next occurrence
          }
          return true;
        },
        onDismissed: (_) => repo.deleteEvent(r),
        child: AnimatedOpacity(
          duration: Motion.medium,
          opacity: r.done ? .55 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: r.done ? Colors.white : p.bg.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(24),
              border: overdue
                  ? Border.all(
                      color: const Color(0xFFB4413C).withValues(alpha: .4),
                      width: 1.4,
                    )
                  : null,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    repo.toggleDone(r);
                  },
                  icon: AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: (c, a) => ScaleTransition(
                      scale: CurvedAnimation(parent: a, curve: Motion.spring),
                      child: c,
                    ),
                    child: Icon(
                      r.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(r.done),
                      size: 28,
                      color: r.done ? const Color(0xFF55661B) : p.fg,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Motion.medium,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: r.done ? AppColors.mute : AppColors.ink,
                          decoration: r.done
                              ? TextDecoration.lineThrough
                              : null,
                          letterSpacing: -.2,
                        ),
                        child: Text(
                          r.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _tag(
                            Icons.notifications_none_rounded,
                            when,
                            overdue ? const Color(0xFFB4413C) : p.fg,
                          ),
                          if (r.repeat != Repeat.none)
                            _tag(
                              Icons.repeat_rounded,
                              r.repeat == Repeat.daily
                                  ? t('Daily')
                                  : t('Weekly'),
                              p.fg,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!r.done)
                  IconButton(
                    tooltip: t('Snooze'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      repo.snoozeReminder(r, const Duration(hours: 1));
                    },
                    icon: Icon(
                      Icons.snooze_rounded,
                      color: p.fg.withValues(alpha: .8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _swipeBg(Alignment a, Color c, IconData icon) => Container(
    alignment: a,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Icon(icon, color: AppColors.ink),
  );
}

/// Today's completion ring.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.label});
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: Motion.slow,
      curve: Motion.ease,
      builder: (_, v, _) => SizedBox(
        width: 62,
        height: 62,
        child: CustomPaint(
          painter: _RingPainter(v),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(4, 4, s.width - 8, s.height - 8);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = const Color(0x22141414),
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [Color(0xFFE6BA6E), Color(0xFF9ECBC7), Color(0xFFE6BA6E)],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}
