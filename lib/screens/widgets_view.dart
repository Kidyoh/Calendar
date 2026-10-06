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
import '../widgets/more_widgets.dart';
import '../widgets/widget_skin.dart';
import 'event_editor.dart';

/// What each widget type is called, and its home-screen twin.
class WidgetKind {
  const WidgetKind(this.type, this.icon, this.name, this.blurb, this.android);
  final String type;
  final IconData icon;
  final String name;
  final String blurb;
  final String android; // AppWidgetProvider class

  /// Does the calendar face matter for this widget?
  bool get usesFace => type != 'next' && type != 'feasts';
}

List<WidgetKind> get widgetKinds => [
  WidgetKind(
    'glass',
    Icons.calendar_month_rounded,
    t('Calendar'),
    t('Week, month or agenda'),
    glassWidgetName,
  ),
  WidgetKind(
    'island',
    Icons.view_week_rounded,
    t('Week strip'),
    t('A black pill with your week'),
    islandWidgetName,
  ),
  WidgetKind(
    'date',
    Icons.today_rounded,
    t('Date tile'),
    t('Today, big and bold'),
    dateWidgetName,
  ),
  WidgetKind(
    'progress',
    Icons.donut_large_rounded,
    t('Progress'),
    t('Day, week, month or year'),
    progressWidgetName,
  ),
  WidgetKind(
    'next',
    Icons.upcoming_rounded,
    t('Next up'),
    t('Countdown to your next event'),
    nextWidgetName,
  ),
  WidgetKind(
    'feasts',
    Icons.church_rounded,
    t('Feasts & fasts'),
    t('Holidays and fasting days'),
    feastsWidgetName,
  ),
];

WidgetKind kindOf(String type) => widgetKinds.firstWhere(
  (k) => k.type == type,
  orElse: () => widgetKinds.first,
);

/// The live widget for an instance.
Widget buildInstanceWidget(BuildContext context, WidgetInstance w) =>
    switch (w.type) {
      'glass' => GlassWeekWidget(
        key: ValueKey('gw-${w.id}'),
        instanceId: w.id,
        onSettings: () => showWidgetCustomizer(context, w.id),
        onAddReminder: () => showEventEditor(context, reminder: true),
        onNewEvent: () => showEventEditor(context),
      ),
      'island' => IslandWeek(key: ValueKey('iw-${w.id}'), instanceId: w.id),
      'date' => DateTileWidget(key: ValueKey('dw-${w.id}'), instanceId: w.id),
      'progress' => ProgressWidget(
        key: ValueKey('pw-${w.id}'),
        instanceId: w.id,
      ),
      'next' => NextUpWidget(key: ValueKey('nw-${w.id}'), instanceId: w.id),
      _ => FeastsWidget(key: ValueKey('fw-${w.id}'), instanceId: w.id),
    };

/// Showcase + live preview of the widgets; each one is customizable.
class WidgetsView extends StatelessWidget {
  const WidgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();

    Widget chip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.mute),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mute,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    Widget header(WidgetInstance w, int n) {
      final kind = kindOf(w.type);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '${kind.name} $n',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (kind.usesFace || w.views.length > 1)
              AnimatedSwitcher(
                duration: Motion.fast,
                child: KeyedSubtree(
                  key: ValueKey('${w.face}-${w.view}-${w.style}'),
                  child: kind.usesFace
                      ? chip(faceIcon(w.face), faceLabel(w.face))
                      : chip(viewIcon(w.view), viewLabel(w.view)),
                ),
              ),
            const Spacer(),
            IconButton(
              tooltip: t('Customize'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: AppColors.mute,
              ),
              onPressed: () => showWidgetCustomizer(context, w.id),
            ),
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
    }

    final counts = <String, int>{};
    final items = <Widget>[
      _title(t('Your widgets')),
      if (repo.widgets.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Text(
              t('No widgets yet'),
              style: const TextStyle(color: AppColors.mute),
            ),
          ),
        ),
      for (final w in repo.widgets) ...[
        FadeSlideIn(
          key: ValueKey('h-${w.id}'),
          child: header(w, counts[w.type] = (counts[w.type] ?? 0) + 1),
        ),
        FadeSlideIn(
          key: ValueKey('w-${w.id}'),
          child: WidgetBackdrop(
            style: w.style,
            padding: w.type == 'glass'
                ? const EdgeInsets.fromLTRB(18, 56, 18, 48)
                : const EdgeInsets.fromLTRB(16, 30, 16, 30),
            child: w.type == 'glass'
                ? Floating(
                    amplitude: 4,
                    period: 4200,
                    child: buildInstanceWidget(context, w),
                  )
                : buildInstanceWidget(context, w),
          ),
        ),
        const SizedBox(height: 18),
      ],
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
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
      const SizedBox(height: 28),
      _title(t('Home screen')),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Text(
          t(
            'Every home-screen widget picks its own calendar, view and style. Make the calendar widget taller and it opens up into a month.',
          ),
          style: const TextStyle(color: AppColors.mute, height: 1.35),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final k in widgetKinds)
            _pinButton(context, k.icon, k.name, k.android),
        ],
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
      children: items,
    );
  }

  void _showAddWidget(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: repo,
        child: const _AddWidgetSheet(),
      ),
    ).then((id) {
      if (id != null && context.mounted) showWidgetCustomizer(context, id);
    });
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

  Widget _pinButton(
    BuildContext context,
    IconData icon,
    String label,
    String cls,
  ) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      side: BorderSide(color: AppColors.ink.withValues(alpha: .3)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

/// Bottom sheet with a live preview: view, style and calendar of one widget.
void showWidgetCustomizer(BuildContext context, String id) {
  final repo = context.read<CalendarRepository>();
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: repo,
      child: _CustomizeSheet(id: id),
    ),
  );
}

Widget _sheetFrame(List<Widget> children) => Material(
  color: AppColors.paper,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
  clipBehavior: Clip.antiAlias,
  child: SingleChildScrollView(
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
        ...children,
      ],
    ),
  ),
);

Widget _sheetTitle(String s) => Text(
  s,
  style: const TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -.6,
  ),
);

Widget _section(String s) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: Text(
    s,
    style: const TextStyle(color: AppColors.mute, fontWeight: FontWeight.w700),
  ),
);

Widget _choice({
  required IconData icon,
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) => ChoiceChip(
  avatar: Icon(icon, size: 16, color: selected ? Colors.white : AppColors.ink),
  label: Text(label),
  selected: selected,
  showCheckmark: false,
  selectedColor: AppColors.ink,
  backgroundColor: Colors.white,
  side: BorderSide.none,
  labelStyle: TextStyle(
    color: selected ? Colors.white : AppColors.ink,
    fontWeight: FontWeight.w700,
  ),
  shape: const StadiumBorder(),
  onSelected: (_) {
    HapticFeedback.selectionClick();
    onTap();
  },
);

class _CustomizeSheet extends StatelessWidget {
  const _CustomizeSheet({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final w = repo.widgetById(id);
    if (w == null) return const SizedBox.shrink();
    final kind = kindOf(w.type);

    Widget swatch(String style) {
      final sel = w.style == style;
      final skin = WidgetSkin.forStyle(style);
      return Expanded(
        child: Pressable(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              repo.customizeWidget(id, style: style);
            },
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: sel ? AppColors.ink : Colors.transparent,
                  width: 2.4,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (style == 'glass') const LandscapeBackdrop(),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: switch (style) {
                            'glass' => Colors.white.withValues(alpha: .32),
                            'dark' => Colors.black,
                            _ => Colors.white,
                          },
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: style == 'light'
                                ? Colors.black12
                                : Colors.white38,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(styleIcon(style), size: 18, color: skin.fg),
                            const SizedBox(height: 2),
                            Text(
                              styleLabel(style),
                              style: TextStyle(
                                color: skin.fg,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _sheetFrame([
      Row(
        children: [
          Icon(kind.icon, color: AppColors.ink),
          const SizedBox(width: 8),
          Expanded(child: _sheetTitle(t('Customize'))),
        ],
      ),
      const SizedBox(height: 4),
      Text(kind.name, style: const TextStyle(color: AppColors.mute)),
      const SizedBox(height: 14),
      // Live preview: every change shows up right away.
      AnimatedSize(
        duration: Motion.medium,
        curve: Motion.ease,
        child: IgnorePointer(
          ignoring: w.type == 'glass',
          child: WidgetBackdrop(
            style: w.style,
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
            child: buildInstanceWidget(context, w),
          ),
        ),
      ),
      if (w.views.length > 1) ...[
        _section(t('Show')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in w.views)
              _choice(
                icon: viewIcon(v),
                label: viewLabel(v),
                selected: w.view == v,
                onTap: () => repo.customizeWidget(id, view: v),
              ),
          ],
        ),
      ],
      _section(t('Style')),
      Row(
        children: [
          for (final (i, s) in widgetStyles.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            swatch(s),
          ],
        ],
      ),
      if (kind.usesFace) ...[
        _section(t('Calendar')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in CalFace.values)
              _choice(
                icon: faceIcon(f),
                label: faceLabel(f),
                selected: w.face == f,
                onTap: () => repo.setFaceFor(id, f),
              ),
          ],
        ),
      ],
      const SizedBox(height: 22),
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t('Done'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    ]);
  }
}

class _AddWidgetSheet extends StatelessWidget {
  const _AddWidgetSheet();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CalendarRepository>();
    Widget tile(WidgetKind k) => Pressable(
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final nav = Navigator.of(context);
          final id = await repo.addWidget(k.type);
          nav.pop(id);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: switch (defaultStyleOf(k.type)) {
                    'dark' => Colors.black,
                    'light' => AppColors.cream,
                    _ => const Color(0xFF8FB0BD),
                  },
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  k.icon,
                  size: 22,
                  color: defaultStyleOf(k.type) == 'light'
                      ? AppColors.ink
                      : Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                k.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                k.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.mute, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );

    final kinds = widgetKinds;
    return _sheetFrame([
      _sheetTitle(t('Add widget')),
      const SizedBox(height: 4),
      Text(
        t('Pick one, then make it yours.'),
        style: const TextStyle(color: AppColors.mute),
      ),
      const SizedBox(height: 14),
      for (var r = 0; r < kinds.length; r += 2) ...[
        SizedBox(
          height: 136,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tile(kinds[r])),
              const SizedBox(width: 10),
              Expanded(
                child: r + 1 < kinds.length
                    ? tile(kinds[r + 1])
                    : const SizedBox(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }
}
