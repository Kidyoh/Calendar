import 'package:flutter/material.dart';

import '../core/locale.dart';

import 'package:provider/provider.dart';

import '../core/calendar_faces.dart';
import '../core/dates.dart';
import '../core/holidays.dart';
import '../services/calendar_repository.dart';
import 'common.dart';
import 'face_pager.dart';

/// The glassmorphism calendar widget: Weekly / Monthly toggle, settings,
/// big month + day, a day strip with event dots and quick actions.
class GlassWeekWidget extends StatefulWidget {
  const GlassWeekWidget({
    super.key,
    this.instanceId = 'glass-1',
    required this.onSettings,
    required this.onAddReminder,
    required this.onNewEvent,
  });

  /// Widget instance (each glass widget swipes its own calendar).
  final String instanceId;
  final VoidCallback onSettings;
  final VoidCallback onAddReminder;
  final VoidCallback onNewEvent;

  @override
  State<GlassWeekWidget> createState() => _GlassWeekWidgetState();
}

class _GlassWeekWidgetState extends State<GlassWeekWidget> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    const white = Colors.white;

    return GlassCard(
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
                  labels: [t('Weekly'), t('Monthly')],
                  index: _mode,
                  onChanged: (i) => setState(() => _mode = i),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: Icons.settings_outlined,
                size: 48,
                background: white.withValues(alpha: 0.16),
                foreground: white,
                tooltip: t('Settings'),
                onTap: widget.onSettings,
              ),
            ],
          ),
          const SizedBox(height: 18),
          FacePager(instanceId: widget.instanceId),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _mode == 0 ? _week(repo) : _month(repo),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _action(
                    Icons.edit_calendar_outlined,
                    t('Add Reminder'),
                    widget.onAddReminder,
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
                    Icons.add_rounded,
                    t('New Event'),
                    widget.onNewEvent,
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
    IconData icon,
    String label,
    VoidCallback onTap, {
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: Colors.white.withValues(alpha: filled ? 1 : 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: filled ? 1 : 0.7),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _week(CalendarRepository repo) {
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
                face: repo.faceOf(widget.instanceId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _month(CalendarRepository repo) {
    final first = monthStart(repo.selectedDay);
    final gridStart = startOfWeek(first, monday: repo.weekStartsMonday);
    final weeks =
        ((first.difference(gridStart).inDays + daysInMonthOf(first)) / 7)
            .ceil();
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        repo.shiftMonth(v < 0 ? 1 : -1);
      },
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayShort(addDays(gridStart, i), len: 1),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
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
                          dim: !sameMonth(day, first),
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

class GlassDayCell extends StatelessWidget {
  const GlassDayCell({
    super.key,
    required this.day,
    required this.repo,
    required this.showLabel,
    this.dim = false,
    this.face,
  });

  /// Week strip: numbers (and dots) follow the swiped calendar face.
  final CalFace? face;

  final DateTime day;
  final CalendarRepository repo;
  final bool showLabel;
  final bool dim;

  @override
  Widget build(BuildContext context) {
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
        dot = const Color(0xFFF5C98A);
      } else if (fastOn(day) != null) {
        dot = const Color(0xFFC5CE9B);
      }
    } else if (face == CalFace.islamic &&
        holidaysOn(day).any((h) => h.kind == HolidayKind.islamic)) {
      dot = const Color(0xFF9ECBC7);
    }
    if (dot == Colors.transparent && has) {
      dot = Colors.white.withValues(alpha: alpha * .75);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => repo.selectDay(day),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              Text(
                weekdayShort(day, len: 1),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .65),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                border: !selected && today
                    ? Border.all(
                        color: Colors.white.withValues(alpha: .7),
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
                        ? Colors.black
                        : Colors.white.withValues(alpha: alpha),
                    fontSize: 17,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
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
