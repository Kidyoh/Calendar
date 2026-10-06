import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/locale.dart';

import 'package:provider/provider.dart';

import '../core/calendar_faces.dart';
import '../core/dates.dart';
import '../core/holidays.dart';
import '../services/calendar_repository.dart';
import 'common.dart';
import 'face_pager.dart';
import 'widget_skin.dart';
import '../core/theme.dart';

/// The calendar widget: Week / Month / Agenda views (saved per instance),
/// glass · dark · light styles, a swipeable calendar face and quick actions.
class GlassWeekWidget extends StatelessWidget {
  const GlassWeekWidget({
    super.key,
    this.instanceId = 'glass-1',
    required this.onSettings,
    required this.onAddReminder,
    required this.onNewEvent,
  });

  /// Widget instance (each keeps its own calendar, view and style).
  final String instanceId;

  /// ⚙ button: customize this widget.
  final VoidCallback onSettings;
  final VoidCallback onAddReminder;
  final VoidCallback onNewEvent;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final inst = repo.widgetById(instanceId);
    final style = inst?.style ?? 'glass';
    final views = inst?.views ?? widgetViews['glass']!;
    final view = inst?.view ?? views.first;
    final skin = WidgetSkin.forStyle(style);
    final face = repo.faceOf(instanceId);

    return SkinCard(
      style: style,
      radius: 40,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: PillToggle(
                  style: PillStyle.glass,
                  labels: [for (final v in views) viewLabel(v)],
                  index: views.indexOf(view).clamp(0, views.length - 1),
                  track: skin.chip,
                  thumb: skin.selBg,
                  text: skin.muted,
                  selectedText: skin.selFg,
                  onChanged: (i) {
                    HapticFeedback.selectionClick();
                    repo.customizeWidget(instanceId, view: views[i]);
                  },
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: Icons.tune_rounded,
                size: 48,
                background: skin.chip,
                foreground: skin.fg,
                tooltip: t('Customize'),
                onTap: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 18),
          FacePager(instanceId: instanceId, color: skin.fg),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: KeyedSubtree(
                key: ValueKey(view),
                child: switch (view) {
                  'month' => FaceMonthGrid(repo: repo, face: face),
                  'agenda' => AgendaList(repo: repo, max: 5),
                  _ => _week(repo, face),
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _action(
                    skin,
                    Icons.edit_calendar_outlined,
                    t('Add Reminder'),
                    onAddReminder,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _action(
                    skin,
                    Icons.add_rounded,
                    t('New Event'),
                    onNewEvent,
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(
    WidgetSkin skin,
    IconData icon,
    String label,
    VoidCallback onTap, {
    required bool filled,
  }) {
    final c = filled ? skin.fg : skin.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? skin.chip : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: c),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _week(CalendarRepository repo, CalFace face) {
    final start = startOfWeek(repo.selectedDay, monday: repo.weekStartsMonday);
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        repo.selectDay(addDays(repo.selectedDay, v < 0 ? 7 : -7));
      },
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: GlassDayCell(
                day: addDays(start, i),
                repo: repo,
                showLabel: true,
                face: face,
              ),
            ),
        ],
      ),
    );
  }
}

/// Month grid in the widget's own calendar (Gregorian / Ethiopian / Hijri
/// months); swipe sideways for the previous / next month.
class FaceMonthGrid extends StatelessWidget {
  const FaceMonthGrid({
    super.key,
    required this.repo,
    required this.face,
    this.compact = false,
    this.showTitle = false,
  });
  final CalendarRepository repo;
  final CalFace face;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final skin = WidgetSkin.of(context);
    final (first, len) = faceMonth(face, repo.selectedDay);
    final gridStart = startOfWeek(first, monday: repo.weekStartsMonday);
    final weeks = ((first.difference(gridStart).inDays + len) / 7).ceil();
    final last = addDays(first, len - 1);
    void go(int delta) {
      final target = shiftFaceMonth(face, repo.selectedDay, delta);
      final today = dateOnly(DateTime.now());
      final (s, l) = faceMonth(face, target);
      // Land on today when it is in that month, else on day 1.
      repo.selectDay(
        !today.isBefore(s) && today.isBefore(addDays(s, l)) ? today : target,
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        HapticFeedback.selectionClick();
        go(v < 0 ? 1 : -1);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faceView(face, first).title,
                      style: TextStyle(
                        color: skin.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${faceDay(face, first)}–${faceDay(face, last)}',
                    style: TextStyle(color: skin.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayShort(addDays(gridStart, i), len: 1),
                      style: TextStyle(
                        color: skin.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                        final day = addDays(gridStart, w * 7 + i);
                        return GlassDayCell(
                          day: day,
                          repo: repo,
                          showLabel: false,
                          face: face,
                          compact: compact,
                          dim: day.isBefore(first) || day.isAfter(last),
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

/// One line of the agenda: a holiday or an event.
class AgendaEntry {
  const AgendaEntry(this.day, this.time, this.title, this.color);
  final DateTime day;
  final String time;
  final String title;
  final Color color;
}

/// Upcoming events (and holidays) from the selected day on.
List<AgendaEntry> agendaEntries(
  CalendarRepository repo, {
  int max = 5,
  int days = 30,
}) {
  final now = DateTime.now();
  final from = repo.selectedDay;
  final out = <AgendaEntry>[];
  for (var i = 0; i < days && out.length < max; i++) {
    final day = addDays(from, i);
    for (final h in repo.holidaysFor(day)) {
      out.add(AgendaEntry(day, '★', h.name, const Color(0xFFE08A84)));
    }
    for (final e in repo.eventsOn(day, includeReminders: false)) {
      if (!e.allDay && e.end.isBefore(now)) continue;
      out.add(
        AgendaEntry(
          day,
          e.allDay ? t('All day') : fmtTime(e.start),
          e.title,
          paletteAt(e.colorIndex).bg,
        ),
      );
    }
  }
  return out.take(max).toList();
}

class AgendaList extends StatelessWidget {
  const AgendaList({super.key, required this.repo, this.max = 5});
  final CalendarRepository repo;
  final int max;

  String _dayLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    if (sameDay(d, today)) return t('Today');
    if (sameDay(d, addDays(today, 1))) return t('Tomorrow');
    return '${weekdayShort(d, len: 3)} ${dayNum(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final skin = WidgetSkin.of(context);
    final items = agendaEntries(repo, max: max);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: skin.muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('All clear — nothing coming up'),
                style: TextStyle(color: skin.fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final e in items) {
      if (lastDay == null || !sameDay(lastDay, e.day)) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: lastDay == null ? 0 : 8, bottom: 4),
            child: Text(
              _dayLabel(e.day),
              style: TextStyle(
                color: skin.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .3,
              ),
            ),
          ),
        );
        lastDay = e.day;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: e.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 62,
                child: Text(
                  e.time,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: skin.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: skin.fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class GlassDayCell extends StatelessWidget {
  const GlassDayCell({
    super.key,
    required this.day,
    required this.repo,
    required this.showLabel,
    this.dim = false,
    this.face,
    this.compact = false,
  });

  /// Smaller cells (island month view).
  final bool compact;

  /// Week strip: numbers (and dots) follow the swiped calendar face.
  final CalFace? face;

  final DateTime day;
  final CalendarRepository repo;
  final bool showLabel;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final skin = WidgetSkin.of(context);
    final size = compact ? 28.0 : 38.0;
    final selected = sameDay(day, repo.selectedDay);
    final today = sameDay(day, DateTime.now());
    final has = repo.hasEvents(day);
    final alpha = dim ? 0.35 : 1.0;
    final number = face == null ? dayNum(day) : faceDay(face!, day);
    // Orthodox face: gold = feast/saint, green = fast. Islamic: teal = holiday.
    Color dot = Colors.transparent;
    if (face == CalFace.orthodox) {
      final hs = holidaysOn(day, saints: true);
      if (hs.any(
        (h) => h.kind == HolidayKind.orthodox || h.kind == HolidayKind.saint,
      )) {
        dot = skin.feast;
      } else if (fastOn(day) != null) {
        dot = skin.fast;
      }
    } else if (face == CalFace.islamic &&
        holidaysOn(day).any((h) => h.kind == HolidayKind.islamic)) {
      dot = skin.islamic;
    }
    if (dot == Colors.transparent && has) {
      dot = skin.fg.withValues(alpha: alpha * .75);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => repo.selectDay(day),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 1 : 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              Text(
                weekdayShort(day, len: 1),
                style: TextStyle(
                  color: skin.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? skin.selBg : Colors.transparent,
                borderRadius: BorderRadius.circular(size / 3),
                border: !selected && today
                    ? Border.all(
                        color: skin.fg.withValues(alpha: .7),
                        width: 1.3,
                      )
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .5),
                      end: Offset.zero,
                    ).animate(a),
                    child: c,
                  ),
                ),
                child: Text(
                  '$number',
                  key: ValueKey('$number-${face?.index}'),
                  style: TextStyle(
                    color: selected
                        ? skin.selFg
                        : skin.fg.withValues(alpha: alpha),
                    fontSize: compact ? 13 : 17,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
          ],
        ),
      ),
    );
  }
}
