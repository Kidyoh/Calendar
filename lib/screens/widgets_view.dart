import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/widget_sync.dart';
import '../widgets/common.dart';
import '../widgets/glass_widget.dart';
import '../widgets/islands.dart';
import '../widgets/motion.dart';
import 'event_editor.dart';
import 'settings_sheet.dart';

/// Showcase + live preview of the widget designs.
class WidgetsView extends StatelessWidget {
  const WidgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
      children: _stagger([
        _title('Glass'),
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              const Positioned.fill(child: LandscapeBackdrop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 70, 18, 60),
                child: Floating(
                  amplitude: 4,
                  period: 4200,
                  child: GlassWeekWidget(
                    onSettings: () => showSettingsSheet(context),
                    onAddReminder: () =>
                        showEventEditor(context, reminder: true),
                    onNewEvent: () => showEventEditor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _pinButton(context, 'Add glass widget to home screen', glassWidgetName),
        const SizedBox(height: 26),
        _title('Island'),
        const IslandWeek(),
        const SizedBox(height: 12),
        const IslandDayProgress(),
        const SizedBox(height: 12),
        const IslandNextUp(),
        const SizedBox(height: 12),
        _pinButton(
          context,
          'Add island widget to home screen',
          islandWidgetName,
        ),
      ]),
    );
  }

  List<Widget> _stagger(List<Widget> items) => [
    for (var i = 0; i < items.length; i++)
      FadeSlideIn.stagger(i, stepMs: 55, child: items[i]),
  ];

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 0, 10),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
      ),
    ),
  );

  Widget _pinButton(BuildContext context, String label, String cls) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(color: AppColors.ink.withValues(alpha: .3)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () async {
          final ok = await WidgetSync.pin(cls);
          if (!ok && context.mounted) {
            showSnack(
              context,
              'Long-press your home screen → Widgets → Glass Calendar',
            );
          }
        },
        icon: const Icon(Icons.add_to_home_screen),
        label: Text(label),
      );
}
