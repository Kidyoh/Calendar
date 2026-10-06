import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/locale.dart';

import 'package:provider/provider.dart';

import '../core/calendar_faces.dart';
import '../core/dates.dart';
import '../services/calendar_repository.dart';
import 'motion.dart';
import 'face_pager.dart';
import 'glass_widget.dart';
import 'widget_skin.dart';

/// Rebuilds [builder] every [interval] so clocks and progress stay live.
class Ticker extends StatefulWidget {
  const Ticker({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 30),
  });
  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration interval;

  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  late DateTime _now = DateTime.now();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// Island 1: month, event count and a Mo..Su strip.
class IslandWeek extends StatelessWidget {
  const IslandWeek({super.key, this.instanceId = 'island-1'});

  /// Widget instance (each island swipes its own calendar).
  final String instanceId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final sel = repo.selectedDay;
    final start = startOfWeek(sel, monday: repo.weekStartsMonday);
    final n = repo.eventsOn(sel, includeReminders: false).length;
    final face = repo.faceOf(instanceId);
    final view = faceView(face, sel);
    final inst = repo.widgetById(instanceId);
    final style = inst?.style ?? 'dark';
    final month = inst?.view == 'month';
    final skin = WidgetSkin.forStyle(style);
    // Swipe sideways to switch Gregorian · Ethiopian · Islamic · Orthodox.
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 150 && !month) {
          HapticFeedback.selectionClick();
          repo.cycleFaceFor(instanceId, v < 0 ? 1 : -1);
        }
      },
      child: SkinCard(
        style: style,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(faceIcon(face), size: 15, color: skin.muted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: RollingText(
                          view.title,
                          style: TextStyle(
                            color: skin.muted,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: Motion.fast,
                        margin: const EdgeInsets.only(right: 3),
                        width: i == face.index ? 12 : 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: skin.fg.withValues(
                            alpha: i == face.index ? .9 : .3,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '$n ${n == 1 ? t('event') : t('events')}',
                      style: TextStyle(
                        color: skin.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: Motion.medium,
              curve: Motion.ease,
              alignment: Alignment.topCenter,
              child: month
                  ? FaceMonthGrid(repo: repo, face: face, compact: true)
                  : Column(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    weekdayShort(addDays(start, i)),
                                    style: TextStyle(
                                      color: skin.fg,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Builder(
                                  builder: (_) {
                                    final d = addDays(start, i);
                                    final s = sameDay(d, sel);
                                    return GestureDetector(
                                      onTap: () => repo.selectDay(d),
                                      child: Center(
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          width: 34,
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: s
                                                ? skin.selBg
                                                : Colors.transparent,
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 280,
                                            ),
                                            transitionBuilder: (c, a) =>
                                                FadeTransition(
                                                  opacity: a,
                                                  child: SlideTransition(
                                                    position: Tween(
                                                      begin: const Offset(
                                                        0,
                                                        .5,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(a),
                                                    child: c,
                                                  ),
                                                ),
                                            child: Text(
                                              '${faceDay(face, d)}',
                                              key: ValueKey(
                                                '${faceDay(face, d)}-${face.index}',
                                              ),
                                              style: TextStyle(
                                                color: s ? skin.selFg : skin.fg,
                                                fontSize: 16,
                                                fontWeight: s
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
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
            ),
          ],
        ),
      ),
    );
  }
}
