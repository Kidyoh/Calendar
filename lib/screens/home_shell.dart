import 'dart:async';

import 'package:flutter/material.dart';

import '../core/locale.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/calendar_repository.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'calendar_view.dart';
import 'event_editor.dart';
import 'settings_sheet.dart';
import 'today_view.dart';
import 'widgets_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pull in changes made in Google Calendar / other apps while we were away.
    if (state == AppLifecycleState.resumed) {
      final repo = context.read<CalendarRepository>();
      repo
          .syncFaceFromHomeWidget()
          .then((_) => repo.refreshPermission())
          .then((_) => repo.reload());
    }
  }

  void _go(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dir = i > _tab ? 1 : -1;
      _tab = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final views = [
      const TodayView(),
      CalendarView(onOpenDay: () => _go(0)),
      const WidgetsView(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FadeSlideIn(
              offset: const Offset(0, -.4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PillToggle(
                          labels: [t('Today'), t('Calendar'), t('Widgets')],
                          index: _tab,
                          onChanged: _go,
                        ),
                      ),
                    ),
                    // Syncing shows as a quiet ring around the settings
                    // button: no layout shift, nothing for quick loads.
                    _SyncRing(
                      active: repo.loading,
                      child: Pressable(
                        scale: .88,
                        child: RoundIconButton(
                          icon: Icons.tune_rounded,
                          size: 44,
                          tooltip: t('Settings'),
                          onTap: () => showSettingsSheet(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      scale: .88,
                      child: RoundIconButton(
                        icon: Icons.add_rounded,
                        size: 48,
                        background: AppColors.ink,
                        foreground: Colors.white,
                        tooltip: t('New event'),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showEventEditor(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.ease,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(_tab);
                  final dx = (incoming ? .08 : -.08) * _dir;
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_tab), child: views[_tab]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress ring that fades in around [child] only when loading lasts
/// longer than [delay], so fast syncs never flash anything.
class _SyncRing extends StatefulWidget {
  const _SyncRing({required this.active, required this.child});
  final bool active;
  final Widget child;
  static const delay = Duration(milliseconds: 500);

  @override
  State<_SyncRing> createState() => _SyncRingState();
}

class _SyncRingState extends State<_SyncRing> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_SyncRing old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (widget.active) {
      _timer = Timer(_SyncRing.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    } else if (_visible) {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: -3,
          top: -3,
          right: -3,
          bottom: -3,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: Motion.medium,
              child: _visible
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      strokeCap: StrokeCap.round,
                      color: AppColors.ink,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
