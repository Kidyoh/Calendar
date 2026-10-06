import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/calendar_repository.dart';
import '../widgets/common.dart';
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
      repo.refreshPermission().then((_) => repo.reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final views = [
      const TodayView(),
      CalendarView(onOpenDay: () => setState(() => _tab = 0)),
      const WidgetsView(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: PillToggle(
                        labels: const ['Today', 'Calendar', 'Widgets'],
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                    ),
                  ),
                  if (repo.loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  RoundIconButton(
                    icon: Icons.tune_rounded,
                    size: 44,
                    tooltip: 'Settings',
                    onTap: () => showSettingsSheet(context),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.add_rounded,
                    size: 48,
                    background: AppColors.ink,
                    foreground: Colors.white,
                    tooltip: 'New event',
                    onTap: () => showEventEditor(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .02),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(_tab), child: views[_tab]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
