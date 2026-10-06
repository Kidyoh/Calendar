import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../services/calendar_repository.dart';
import 'common.dart';

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
  const IslandWeek({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final sel = repo.selectedDay;
    final start = startOfWeek(sel, monday: repo.weekStartsMonday);
    final n = repo.eventsOn(sel, includeReminders: false).length;
    return Island(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName(sel),
                style: const TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$n ${n == 1 ? 'event' : 'events'}',
                style: const TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayShort(addDays(start, i)),
                      style: const TextStyle(
                        color: Colors.white,
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
                            duration: const Duration(milliseconds: 220),
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s ? Colors.white : Colors.transparent,
                            ),
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                color: s ? Colors.black : Colors.white,
                                fontSize: 16,
                                fontWeight: s
                                    ? FontWeight.w800
                                    : FontWeight.w600,
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
    );
  }
}

/// Island 2: "Day 67%" with 24 hourly dots.
class IslandDayProgress extends StatelessWidget {
  const IslandDayProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Ticker(
      builder: (context, now) {
        final frac = (now.hour * 60 + now.minute) / 1440;
        final lit = frac * 24;
        return Island(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Day',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(frac * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (var r = 0; r < 2; r++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var c = 0; c < 12; c++)
                      _dot(((lit - (r * 12 + c)).clamp(0.0, 1.0))),
                  ],
                ),
                if (r == 0) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _dot(double fill) => Container(
    width: 17,
    height: 17,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.lerp(const Color(0xFF2E2E2E), Colors.white, fill),
    ),
  );
}

/// Island 3 (replaces the weather island): the next event with a countdown.
class IslandNextUp extends StatelessWidget {
  const IslandNextUp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    return Ticker(
      builder: (context, now) {
        final e = repo.nextUp;
        if (e == null) {
          return const Island(
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 30),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'All clear — nothing coming up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final started = !e.start.isAfter(now);
        final total = e.duration.inSeconds.clamp(1, 1 << 30);
        final progress = started
            ? (now.difference(e.start).inSeconds / total).clamp(0.0, 1.0)
            : 0.0;
        return Island(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Next up',
                    style: TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    started
                        ? 'happening now'
                        : fmtCountdown(e.start.difference(now)),
                    style: const TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${fmtTime(e.start)} – ${fmtTime(e.end)}',
                style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF2E2E2E),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
