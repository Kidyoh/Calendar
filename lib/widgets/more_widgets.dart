import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calendar_faces.dart';
import '../core/dates.dart';
import '../core/ethiopian.dart';
import '../core/hijri.dart';
import '../core/holidays.dart';
import '../core/locale.dart';
import '../services/calendar_repository.dart';
import 'face_pager.dart';
import 'glass_widget.dart';
import 'holiday_views.dart';
import 'islands.dart';
import 'motion.dart';
import 'widget_skin.dart';

String _yearTitle(CalFace f, DateTime d) => switch (f) {
  CalFace.gregorian => '${d.year}',
  CalFace.ethiopian ||
  CalFace.orthodox => '${toEthiopian(d).year} ${AppLocale.am ? 'ዓ.ም' : 'E.C.'}',
  CalFace.islamic => '${toHijri(d).year} ${AppLocale.am ? '' : 'AH'}'.trim(),
};

String _daysLeft(int n) => AppLocale.am ? '$n ቀናት ቀርተዋል' : '$n days left';

/// Header row shared by the small widgets: icon + title … trailing.
class _Head extends StatelessWidget {
  const _Head({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final skin = WidgetSkin.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: skin.muted),
        const SizedBox(width: 6),
        Expanded(
          child: RollingText(
            title,
            style: TextStyle(
              color: skin.fg,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: skin.fg,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

/// Swipe sideways on a widget to switch its calendar face.
class _FaceSwipe extends StatelessWidget {
  const _FaceSwipe({required this.instanceId, required this.child});
  final String instanceId;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragEnd: (d) {
      final v = d.primaryVelocity ?? 0;
      if (v.abs() > 150) {
        HapticFeedback.selectionClick();
        context.read<CalendarRepository>().cycleFaceFor(
          instanceId,
          v < 0 ? 1 : -1,
        );
      }
    },
    child: child,
  );
}

// ------------------------------------------------------------- progress
/// "Day 67%" with hourly dots — or how far through the week, month or year
/// (month and year follow the widget's calendar).
class ProgressWidget extends StatelessWidget {
  const ProgressWidget({super.key, this.instanceId = 'progress-1'});
  final String instanceId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final inst = repo.widgetById(instanceId);
    final style = inst?.style ?? 'dark';
    final view = inst?.view ?? 'day';
    final face = repo.faceOf(instanceId);
    return _FaceSwipe(
      instanceId: instanceId,
      child: Ticker(
        builder: (context, now) {
          final today = dateOnly(now);
          late String title;
          late double frac; // 0..1 of the period gone
          late int units; // dots
          late String left;
          List<String>? labels; // under the dots (week)
          var icon = Icons.today_rounded;
          switch (view) {
            case 'week':
              final s = startOfWeek(today, monday: repo.weekStartsMonday);
              frac = now.difference(s).inMinutes / (7 * 1440);
              units = 7;
              title = '${t('Week')} ${isoWeek(today)}';
              left = _daysLeft(7 - today.difference(s).inDays - 1);
              labels = [
                for (var i = 0; i < 7; i++) weekdayShort(addDays(s, i), len: 1),
              ];
              icon = Icons.view_week_rounded;
            case 'month':
              final (s, len) = faceMonth(face, today);
              frac = now.difference(s).inMinutes / (len * 1440);
              units = len;
              title = faceView(face, today).title;
              left = _daysLeft(len - today.difference(s).inDays - 1);
              icon = Icons.calendar_view_month_rounded;
            case 'year':
              final (s, e) = faceYear(face, today);
              final days = e.difference(s).inDays;
              frac = now.difference(s).inMinutes / (days * 1440);
              // One dot per month (13 in the Ethiopian year).
              units = face == CalFace.ethiopian || face == CalFace.orthodox
                  ? 13
                  : 12;
              title = _yearTitle(face, today);
              left = _daysLeft(e.difference(today).inDays - 1);
              icon = Icons.calendar_today_rounded;
            default:
              frac = (now.hour * 60 + now.minute) / 1440;
              units = 24;
              title = t('Day');
              left =
                  '${fmtDuration(Duration(minutes: 1440 - now.hour * 60 - now.minute))} ${AppLocale.am ? 'ቀርቷል' : 'left'}';
          }
          frac = frac.clamp(0.0, 1.0);
          return SkinCard(
            style: style,
            child: Builder(
              builder: (context) {
                final skin = WidgetSkin.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Head(
                      icon: icon,
                      title: title,
                      trailing: '${(frac * 100).round()}%',
                    ),
                    const SizedBox(height: 14),
                    _Dots(
                      units: units,
                      lit: frac * units,
                      perRow: units == 24
                          ? 12
                          : units > 16
                          ? (units / 2).ceil()
                          : units,
                      labels: labels,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      left,
                      style: TextStyle(
                        color: skin.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.units,
    required this.lit,
    required this.perRow,
    this.labels,
  });
  final int units;
  final double lit;
  final int perRow;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final skin = WidgetSkin.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final size = ((c.maxWidth - (perRow - 1) * 4) / perRow).clamp(
          6.0,
          17.0,
        );
        final rows = (units / perRow).ceil();
        return Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              Row(
                mainAxisAlignment: perRow * (size + 4) > c.maxWidth * .6
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  for (var i = r * perRow; i < (r + 1) * perRow; i++)
                    if (i < units)
                      Padding(
                        padding: EdgeInsets.only(
                          right: perRow * (size + 4) > c.maxWidth * .6 ? 0 : 4,
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: Motion.medium,
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.lerp(
                                  skin.track,
                                  skin.fg,
                                  (lit - i).clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                            if (labels != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                labels![i],
                                style: TextStyle(
                                  color: skin.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                ],
              ),
              if (r < rows - 1) SizedBox(height: size < 12 ? 6 : 10),
            ],
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------- next up
/// The next event with a countdown — or the next few as an agenda.
class NextUpWidget extends StatelessWidget {
  const NextUpWidget({super.key, this.instanceId = 'next-1'});
  final String instanceId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final inst = repo.widgetById(instanceId);
    final style = inst?.style ?? 'dark';
    final agenda = inst?.view == 'agenda';
    return Ticker(
      builder: (context, now) => SkinCard(
        style: style,
        child: Builder(
          builder: (context) {
            final skin = WidgetSkin.of(context);
            if (agenda) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Head(icon: Icons.view_agenda_rounded, title: t('Agenda')),
                  const SizedBox(height: 10),
                  AgendaList(repo: repo, max: 4),
                ],
              );
            }
            final e = repo.nextUp;
            if (e == null) {
              return Row(
                children: [
                  Icon(Icons.check_circle_outline, color: skin.fg, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t('All clear — nothing coming up'),
                      style: TextStyle(
                        color: skin.fg,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }
            final started = !e.start.isAfter(now);
            final total = e.duration.inSeconds.clamp(1, 1 << 30);
            final progress = started
                ? (now.difference(e.start).inSeconds / total).clamp(0.0, 1.0)
                : 0.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('Next up'),
                      style: TextStyle(
                        color: skin.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      started
                          ? t('happening now')
                          : fmtCountdown(e.start.difference(now)),
                      style: TextStyle(
                        color: skin.muted,
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
                  style: TextStyle(
                    color: skin.fg,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmtTime(e.start)} – ${fmtTime(e.end)}',
                  style: TextStyle(color: skin.muted, fontSize: 15),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: skin.track,
                    valueColor: AlwaysStoppedAnimation(skin.fg),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- date tile
/// A big date in the widget's calendar, with what matters today.
class DateTileWidget extends StatelessWidget {
  const DateTileWidget({super.key, this.instanceId = 'date-1'});
  final String instanceId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final inst = repo.widgetById(instanceId);
    final style = inst?.style ?? 'glass';
    final face = repo.faceOf(instanceId);
    return _FaceSwipe(
      instanceId: instanceId,
      child: Ticker(
        interval: const Duration(minutes: 1),
        builder: (context, now) {
          final today = dateOnly(now);
          final v = faceView(face, today);
          final hol = repo.holidaysFor(today);
          return SkinCard(
            style: style,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Builder(
              builder: (context) {
                final skin = WidgetSkin.of(context);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          weekdayShort(today, len: 3).toUpperCase(),
                          style: TextStyle(
                            color: hol.any((h) => h.dayOff)
                                ? const Color(0xFFE08A84)
                                : skin.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: Motion.medium,
                          child: Text(
                            v.day,
                            key: ValueKey('${face.index}-${v.day}'),
                            style: TextStyle(
                              color: skin.fg,
                              fontSize: 64,
                              fontWeight: FontWeight.w300,
                              height: 1.05,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(faceIcon(face), size: 14, color: skin.muted),
                              const SizedBox(width: 5),
                              Text(
                                v.label,
                                style: TextStyle(
                                  color: skin.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RollingText(
                            v.title,
                            style: TextStyle(
                              color: skin.fg,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hol.isNotEmpty
                                ? hol.map((h) => h.name).join(' · ')
                                : v.line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: skin.fg.withValues(alpha: .85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (v.line2.isNotEmpty)
                            Text(
                              v.line2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: skin.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------- feasts & fasts
/// Upcoming feasts and holidays plus today's fast.
class FeastsWidget extends StatelessWidget {
  const FeastsWidget({super.key, this.instanceId = 'feasts-1'});
  final String instanceId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final inst = repo.widgetById(instanceId);
    final style = inst?.style ?? 'light';
    final today = dateOnly(DateTime.now());
    final items = upcomingHolidays(repo, today, max: 4);
    final fast = repo.fastFor(today);
    return SkinCard(
      style: style,
      child: Builder(
        builder: (context) {
          final skin = WidgetSkin.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Head(icon: Icons.church_rounded, title: t('Feasts & fasts')),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: skin.fast.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.eco_rounded, size: 18, color: skin.fast),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fast == null
                            ? t('No fast today')
                            : '${fast.name}${fast.progress == null ? '' : ' · ${fast.progress}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: skin.fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text(t('No holidays'), style: TextStyle(color: skin.muted)),
              for (final (h, d) in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        holidayIcon(h.kind),
                        size: 18,
                        color: h.kind == HolidayKind.islamic
                            ? skin.islamic
                            : h.dayOff
                            ? const Color(0xFFE08A84)
                            : skin.feast,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          h.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: skin.fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        inDays(d.difference(today).inDays),
                        style: TextStyle(
                          color: skin.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The next [max] holidays (honouring the holiday filters) from [from] on.
List<(Holiday, DateTime)> upcomingHolidays(
  CalendarRepository repo,
  DateTime from, {
  int max = 4,
  int days = 200,
}) {
  final out = <(Holiday, DateTime)>[];
  for (var i = 0; i < days && out.length < max; i++) {
    final d = addDays(from, i);
    for (final h in repo.holidaysFor(d)) {
      out.add((h, d));
    }
  }
  return out.take(max).toList();
}
