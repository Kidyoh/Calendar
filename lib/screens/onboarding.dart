import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/locale.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/ethiopian.dart';
import '../core/theme.dart';
import '../services/calendar_repository.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'home_shell.dart';

class _Page {
  const _Page(this.bg, this.fg, this.kicker, this.title, this.body);
  final Color bg;
  final Color fg;
  final String kicker;
  final String title;
  final String body;
}

const _pages = [
  _Page(
    AppColors.cream,
    AppColors.ink,
    'WELCOME',
    'Your days,\nbeautifully.',
    'Tasks, meetings and reminders laid out in calm pastel cards.',
  ),
  _Page(
    Color(0xFF3E6233),
    Colors.white,
    'GLASS',
    'Frosted glass\nwidgets.',
    'A weekly glance that floats over your wallpaper. Pin it to your home screen.',
  ),
  _Page(
    Colors.black,
    Colors.white,
    'ISLAND',
    'Everything\nat a glance.',
    'Your week, how much of the day is left, and what\'s next. All in one black pill.',
  ),
  _Page(
    Color(0xFFF2EFE8),
    AppColors.ink,
    'SYNC',
    'Bring all your\ncalendars.',
    'Google, iCloud, Outlook. Anything on your phone shows up here, and stays in sync.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Survives the remount that happens when the language is switched.
  static int _resumePage = 0;
  late final _pc = PageController(initialPage: _resumePage);
  late double _page = _resumePage.toDouble();

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Color _lerp(Color Function(_Page) pick) {
    final i = _page.floor().clamp(0, _pages.length - 1);
    final j = (i + 1).clamp(0, _pages.length - 1);
    return Color.lerp(pick(_pages[i]), pick(_pages[j]), _page - i)!;
  }

  bool get _last => _page.round() == _pages.length - 1;

  void _next() {
    HapticFeedback.lightImpact();
    if (_last) {
      _finish();
    } else {
      _pc.nextPage(duration: Motion.slow, curve: Motion.ease);
    }
  }

  Future<void> _finish({bool connect = false}) async {
    final repo = context.read<CalendarRepository>();
    final nav = Navigator.of(context);
    if (connect) await repo.connectDeviceCalendars();
    _resumePage = 0;
    await repo.completeOnboarding();
    nav.pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const HomeShell(),
        transitionsBuilder: (_, anim, _, child) {
          final t = CurvedAnimation(parent: anim, curve: Motion.ease);
          return FadeTransition(
            opacity: t,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(t),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _lerp((p) => p.bg);
    final fg = _lerp((p) => p.fg);
    final dark = bg.computeLuminance() < .4;
    // Landscape fades in around page 1 only.
    final landscape = (1 - (_page - 1).abs()).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            if (landscape > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: landscape,
                  child: const DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC1E3318)],
                        stops: [.45, 1],
                      ),
                    ),
                    child: LandscapeBackdrop(),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Glass Calendar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -.2,
                            ),
                          ),
                        ),
                        _LangChip(fg: fg),
                        AnimatedOpacity(
                          duration: Motion.fast,
                          opacity: _last ? 0 : 1,
                          child: TextButton(
                            onPressed: _last ? null : () => _finish(),
                            child: Text(
                              t('Skip'),
                              style: TextStyle(
                                color: fg.withValues(alpha: .7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: _pages.length,
                      onPageChanged: (i) {
                        _resumePage = i;
                        HapticFeedback.selectionClick();
                      },
                      itemBuilder: (context, i) {
                        final delta = i - _page; // -1..1 while swiping
                        return _PageBody(
                          index: i,
                          page: _pages[i],
                          delta: delta,
                          fg: fg,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: Row(
                      children: [
                        _Dots(page: _page, count: _pages.length, color: fg),
                        const Spacer(),
                        _NextButton(last: _last, fg: fg, bg: bg, onTap: _next),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: Motion.medium,
                    curve: Motion.ease,
                    child: _last
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                            child: Column(
                              children: [
                                const _CalendarChoice(),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.ink,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                    ),
                                    onPressed: () => _finish(connect: true),
                                    icon: const Icon(Icons.sync),
                                    label: Text(
                                      t('Connect my calendars'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
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

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.index,
    required this.page,
    required this.delta,
    required this.fg,
  });
  final int index;
  final _Page page;
  final double delta;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final fade = (1 - delta.abs() * 1.4).clamp(0.0, 1.0);
    final art = switch (index) {
      0 => const _CardsArt(),
      1 => const _GlassArt(),
      2 => const _IslandArt(),
      _ => const _SyncArt(),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Transform.translate(
              // Illustration moves faster than the page: parallax.
              offset: Offset(delta * 120, 0),
              child: Opacity(
                opacity: fade,
                child: Center(child: art),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(delta * 50, 0),
            child: Opacity(
              opacity: fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(page.kicker),
                    style: TextStyle(
                      color: fg.withValues(alpha: .55),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t(page.title),
                    style: TextStyle(
                      color: fg,
                      fontSize: 40,
                      height: 1.02,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t(page.body),
                    style: TextStyle(
                      color: fg.withValues(alpha: .72),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.count, required this.color});
  final double page;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Builder(
            builder: (_) {
              final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: 8 + 22 * t,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .25 + .75 * t),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.last,
    required this.fg,
    required this.bg,
    required this.onTap,
  });
  final bool last;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.spring,
          height: 60,
          width: last ? 150 : 60,
          decoration: BoxDecoration(
            color: fg,
            borderRadius: BorderRadius.circular(40),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: last
                ? Text(
                    t('Maybe later'),
                    key: const ValueKey('l'),
                    maxLines: 1,
                    style: TextStyle(
                      color: bg,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                : Icon(
                    Icons.arrow_forward_rounded,
                    key: const ValueKey('n'),
                    color: bg,
                  ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ illustrations

class _CardsArt extends StatelessWidget {
  const _CardsArt();

  Widget _card(
    DayPalette p,
    String title,
    String from,
    String to,
    String dur,
  ) => Container(
    width: 270,
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      color: p.bg,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .10),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: p.fg,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(from, style: TextStyle(color: p.fg, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.chip,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                dur,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(to, style: TextStyle(color: p.fg, fontSize: 16)),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 330,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Floating(
              phase: .0,
              child: Transform.rotate(
                angle: -.08,
                child: _card(
                  palettes[0],
                  t('Design review'),
                  '10:00',
                  '11:00',
                  fmtDuration(const Duration(hours: 1)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 105,
            child: Floating(
              phase: .33,
              child: Transform.rotate(
                angle: .05,
                child: _card(
                  palettes[4],
                  t('You have\na meeting'),
                  '3:00',
                  '3:30',
                  fmtDuration(const Duration(minutes: 30)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 225,
            child: Floating(
              phase: .66,
              child: Transform.rotate(
                angle: -.03,
                child: _card(
                  palettes[2],
                  t('Call Wiz'),
                  '4:20',
                  '4:45',
                  fmtDuration(const Duration(minutes: 25)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassArt extends StatelessWidget {
  const _GlassArt();
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = startOfWeek(now, monday: false);
    return Floating(
      amplitude: 10,
      child: SizedBox(
        width: 320,
        child: GlassCard(
          radius: 34,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                t('Weekly'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                t('Monthly'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        monthName(now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${dayNum(now)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          final d = addDays(start, i);
                          final sel = sameDay(d, now);
                          return Column(
                            children: [
                              Text(
                                weekdayShort(d, len: 1),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${dayNum(d)}',
                                  style: TextStyle(
                                    color: sel ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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

class _IslandArt extends StatefulWidget {
  const _IslandArt();
  @override
  State<_IslandArt> createState() => _IslandArtState();
}

class _IslandArtState extends State<_IslandArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grey = const Color(0xFF2E2E2E);
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Floating(
            amplitude: 5,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final lit = Curves.easeInOut.transform(_c.value) * 24;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            t('Day'),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(lit / 24 * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (var r = 0; r < 2; r++)
                        Padding(
                          padding: EdgeInsets.only(bottom: r == 0 ? 8 : 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var c = 0; c < 12; c++)
                                Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color.lerp(
                                      grey,
                                      Colors.white,
                                      (lit - (r * 12 + c)).clamp(0.0, 1.0),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Floating(
            amplitude: 5,
            phase: .5,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t('Next up')} · ${fmtCountdown(const Duration(minutes: 25))}',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          t('Design review'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncArt extends StatefulWidget {
  const _SyncArt();
  @override
  State<_SyncArt> createState() => _SyncArtState();
}

class _SyncArtState extends State<_SyncArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  static const _sources = [
    ('G', Color(0xFF4285F4), 'Google'),
    ('', Color(0xFF111111), 'iCloud'),
    ('O', Color(0xFF0F6CBD), 'Outlook'),
    ('S', Color(0xFF1428A0), 'Samsung'),
    ('P', Color(0xFF7E57C2), 'Proton'),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 300.0;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final children = <Widget>[
            // orbit rings
            for (final r in const [120.0, 80.0])
              Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink.withValues(alpha: .08),
                    width: 1.4,
                  ),
                ),
              ),
            // center app tile
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthShort(DateTime.now()).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE6BA6E),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${dayNum(DateTime.now())}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ];
          for (var i = 0; i < _sources.length; i++) {
            final (letter, color, _) = _sources[i];
            final radius = i.isEven ? 120.0 : 80.0;
            final a =
                (_c.value * 2 * math.pi) * (i.isEven ? 1 : -1.4) +
                i * (2 * math.pi / _sources.length);
            children.add(
              Transform.translate(
                offset: Offset(math.cos(a) * radius, math.sin(a) * radius),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: letter.isEmpty
                      ? Icon(Icons.cloud_rounded, color: color, size: 24)
                      : Text(
                          letter,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                ),
              ),
            );
          }
          return Stack(alignment: Alignment.center, children: children);
        },
      ),
    );
  }
}

/// Compact EN / አማ switch in the onboarding top bar.
class _LangChip extends StatelessWidget {
  const _LangChip({required this.fg});
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final am = repo.language == 'am';
    Widget seg(String label, bool sel, String lang) => GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        repo.setLanguage(lang);
      },
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? fg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel
                ? (fg.computeLuminance() > .5 ? Colors.black : Colors.white)
                : fg.withValues(alpha: .7),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: fg.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('EN', !am, 'en'), seg('አማ', am, 'am')],
      ),
    );
  }
}

/// Gregorian / Ethiopian choice on the last onboarding page.
class _CalendarChoice extends StatelessWidget {
  const _CalendarChoice();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final now = DateTime.now();
    final eth = toEthiopian(now);
    Widget option(bool ethiopian, String title, String sample) {
      final sel = repo.ethiopian == ethiopian;
      return Expanded(
        child: Pressable(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              repo.setEthiopian(ethiopian);
            },
            child: AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.ease,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: sel ? AppColors.ink : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.ink.withValues(alpha: sel ? 1 : .12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: sel ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sample,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sel ? Colors.white70 : AppColors.mute,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final gregSample =
        '${AppLocale.am ? _gregAm[now.month - 1] : monthNames[now.month - 1].substring(0, 3)} ${now.day}, ${now.year}';
    final ethSample =
        '${AppLocale.am ? ethMonthsAm[eth.month - 1] : ethMonthsEn[eth.month - 1]} ${eth.day}, ${eth.year}';
    return Row(
      children: [
        option(false, t('Gregorian'), gregSample),
        const SizedBox(width: 10),
        option(true, t('Ethiopian'), ethSample),
      ],
    );
  }
}

const _gregAm = [
  'ጃንዩወሪ',
  'ፌብሩወሪ',
  'ማርች',
  'ኤፕሪል',
  'ሜይ',
  'ጁን',
  'ጁላይ',
  'ኦገስት',
  'ሴፕቴምበር',
  'ኦክቶበር',
  'ኖቬምበር',
  'ዲሴምበር',
];
