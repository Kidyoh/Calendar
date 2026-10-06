import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../core/locale.dart';

import '../core/calendar_faces.dart';
import '../services/calendar_repository.dart';
import '../widgets/face_pager.dart';
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
    final repo = context.watch<CalendarRepository>();
    final glass = repo.widgets.where((w) => w.type == 'glass').toList();
    final islands = repo.widgets.where((w) => w.type == 'island').toList();

    Widget header(WidgetInstance w, int n) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
      child: Row(
        children: [
          Text(
            '${w.type == 'glass' ? t('Glass') : t('Island')} $n',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: Motion.fast,
            child: Container(
              key: ValueKey(w.face),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(faceIcon(w.face), size: 13, color: AppColors.mute),
                  const SizedBox(width: 4),
                  Text(
                    faceLabel(w.face),
                    style: const TextStyle(
                      color: AppColors.mute,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: t('Remove'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.mute,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final messenger = ScaffoldMessenger.of(context);
              final removed = await repo.removeWidget(w.id);
              if (removed == null) return;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.ink,
                    content: Text(t('Widget removed')),
                    action: SnackBarAction(
                      label: t('Undo'),
                      onPressed: () =>
                          repo.restoreWidget(removed.$1, removed.$2),
                    ),
                  ),
                );
            },
          ),
        ],
      ),
    );

    final items = <Widget>[
      _title(t('Glass')),
      for (final (i, w) in glass.indexed) ...[
        FadeSlideIn(key: ValueKey('h-${w.id}'), child: header(w, i + 1)),
        FadeSlideIn(
          key: ValueKey('w-${w.id}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                const Positioned.fill(child: LandscapeBackdrop()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 56, 18, 48),
                  child: Floating(
                    amplitude: 4,
                    period: 4200,
                    child: GlassWeekWidget(
                      key: ValueKey('gw-${w.id}'),
                      instanceId: w.id,
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
        ),
        const SizedBox(height: 18),
      ],
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.swipe_rounded, size: 18, color: AppColors.mute),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${t('Swipe to switch calendars')} · ${t('Each widget keeps its own calendar.')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mute,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      _pinButton(
        context,
        t('Add glass widget to home screen'),
        glassWidgetName,
      ),
      const SizedBox(height: 26),
      _title(t('Island')),
      for (final (i, w) in islands.indexed) ...[
        FadeSlideIn(key: ValueKey('h-${w.id}'), child: header(w, i + 1)),
        FadeSlideIn(
          key: ValueKey('w-${w.id}'),
          child: IslandWeek(key: ValueKey('iw-${w.id}'), instanceId: w.id),
        ),
        const SizedBox(height: 14),
      ],
      const IslandDayProgress(),
      const SizedBox(height: 12),
      const IslandNextUp(),
      const SizedBox(height: 12),
      _pinButton(
        context,
        t('Add island widget to home screen'),
        islandWidgetName,
      ),
      const SizedBox(height: 20),
      Pressable(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () => _showAddWidget(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            t('Add widget'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
      children: items,
    );
  }

  void _showAddWidget(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: repo,
        child: const _AddWidgetSheet(),
      ),
    );
  }

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
              t('Long-press your home screen → Widgets → Glass Calendar'),
            );
          }
        },
        icon: const Icon(Icons.add_to_home_screen),
        label: Text(label),
      );
}

class _AddWidgetSheet extends StatefulWidget {
  const _AddWidgetSheet();
  @override
  State<_AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends State<_AddWidgetSheet> {
  String _type = 'glass';
  late CalFace _face = context.read<CalendarRepository>().widgetFace;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    Widget option(String type, String label, Widget preview) {
      final sel = _type == type;
      return Expanded(
        child: Pressable(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _type = type);
            },
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: sel ? AppColors.ink : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Expanded(child: Center(child: preview)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('Add widget'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                option(
                  'glass',
                  t('Glass widget'),
                  Container(
                    width: 110,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9DBBC8), Color(0xFF6E9E48)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 84,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                option(
                  'island',
                  t('Island widget'),
                  Container(
                    width: 110,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < 5; i++)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 1 ? Colors.white : Colors.white24,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              t('Starts on'),
              style: const TextStyle(
                color: AppColors.mute,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in CalFace.values)
                  ChoiceChip(
                    avatar: Icon(
                      faceIcon(f),
                      size: 16,
                      color: _face == f ? Colors.white : AppColors.ink,
                    ),
                    label: Text(faceLabel(f)),
                    selected: _face == f,
                    showCheckmark: false,
                    selectedColor: AppColors.ink,
                    labelStyle: TextStyle(
                      color: _face == f ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _face = f),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final nav = Navigator.of(context);
                  await repo.addWidget(_type, face: _face);
                  nav.pop();
                },
                child: Text(
                  t('Add widget'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
