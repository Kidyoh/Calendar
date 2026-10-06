import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates.dart';
import '../core/locale.dart';
import '../core/theme.dart';
import 'motion.dart';

/// Date picker that follows the active calendar (Gregorian or Ethiopian,
/// incl. the 5/6-day Pagume month) and language.
Future<DateTime?> showCalDatePicker(
  BuildContext context, {
  required DateTime initial,
  bool weekStartsMonday = true,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) =>
        _CalDatePicker(initial: dateOnly(initial), monday: weekStartsMonday),
  );
}

class _CalDatePicker extends StatefulWidget {
  const _CalDatePicker({required this.initial, required this.monday});
  final DateTime initial;
  final bool monday;

  @override
  State<_CalDatePicker> createState() => _CalDatePickerState();
}

class _CalDatePickerState extends State<_CalDatePicker> {
  late DateTime _sel = widget.initial;
  late DateTime _month = monthStart(widget.initial);
  int _dir = 1;

  void _shift(int d) {
    HapticFeedback.selectionClick();
    setState(() {
      _dir = d;
      _month = shiftMonths(_month, d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gridStart = startOfWeek(_month, monday: widget.monday);
    final count = daysInMonthOf(_month);
    final weeks = ((_month.difference(gridStart).inDays + count) / 7).ceil();

    return Dialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${yearNum(_sel)}',
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RollingText(
                            '${weekdayShort(_sel, len: 3)}, ${monthShort(_sel)} ${dayNum(_sel)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.8,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          fmtOtherCalendar(_sel),
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: RollingText(
                      '${monthName(_month)} ${yearNum(_month)}',
                      up: _dir > 0,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekdayShort(addDays(gridStart, i), len: 1),
                        style: const TextStyle(
                          color: AppColors.mute,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(.15 * _dir, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: c,
                ),
              ),
              child: Column(
                key: ValueKey(_month),
                children: [
                  for (var w = 0; w < weeks; w++)
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(child: _cell(addDays(gridStart, w * 7 + i))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('Cancel')),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                  onPressed: () => Navigator.pop(context, _sel),
                  child: Text(t('OK')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(DateTime d) {
    final inMonth = sameMonth(d, _month);
    final sel = sameDay(d, _sel);
    final today = sameDay(d, DateTime.now());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _sel = d;
          if (!inMonth) {
            _dir = d.isAfter(_month) ? 1 : -1;
            _month = monthStart(d);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: AnimatedContainer(
            duration: Motion.fast,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? AppColors.ink : Colors.transparent,
              border: !sel && today
                  ? Border.all(color: AppColors.ink, width: 1.2)
                  : null,
            ),
            child: Text(
              '${dayNum(d)}',
              style: TextStyle(
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: sel
                    ? Colors.white
                    : inMonth
                    ? AppColors.ink
                    : AppColors.ink.withValues(alpha: .25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
