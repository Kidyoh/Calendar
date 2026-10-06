import 'package:flutter/material.dart';

import '../core/locale.dart';
import 'common.dart';

/// Colours of one widget style: frosted glass, black island or light paper.
class WidgetSkin {
  const WidgetSkin._(
    this.style, {
    required this.fg,
    required this.muted,
    required this.selBg,
    required this.selFg,
    required this.chip,
    required this.track,
    required this.feast,
    required this.fast,
    required this.islamic,
  });

  final String style;
  final Color fg; // main text
  final Color muted; // secondary text
  final Color selBg; // selected day / filled pill
  final Color selFg;
  final Color chip; // translucent chip / button background
  final Color track; // progress track, empty dots
  final Color feast; // Orthodox feast / saint dot
  final Color fast; // fasting dot
  final Color islamic; // Islamic holiday dot

  bool get light => style == 'light';

  static const glass = WidgetSkin._(
    'glass',
    fg: Colors.white,
    muted: Color(0xB3FFFFFF),
    selBg: Colors.white,
    selFg: Colors.black,
    chip: Color(0x29FFFFFF),
    track: Color(0x40FFFFFF),
    feast: Color(0xFFF5C98A),
    fast: Color(0xFFC5CE9B),
    islamic: Color(0xFF9ECBC7),
  );
  static const dark = WidgetSkin._(
    'dark',
    fg: Colors.white,
    muted: Color(0xFF9A9A9A),
    selBg: Colors.white,
    selFg: Colors.black,
    chip: Color(0xFF1F1F1F),
    track: Color(0xFF2E2E2E),
    feast: Color(0xFFF5C98A),
    fast: Color(0xFFC5CE9B),
    islamic: Color(0xFF9ECBC7),
  );
  static const paper = WidgetSkin._(
    'light',
    fg: Color(0xFF111111),
    muted: Color(0xFF8A8A8A),
    selBg: Color(0xFF111111),
    selFg: Colors.white,
    chip: Color(0xFFF1EFEA),
    track: Color(0xFFE6E3DC),
    feast: Color(0xFFC98A2B),
    fast: Color(0xFF7D8A3E),
    islamic: Color(0xFF3F8C86),
  );

  static WidgetSkin forStyle(String style) => switch (style) {
    'dark' => dark,
    'light' => paper,
    _ => glass,
  };

  static WidgetSkin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin ?? glass;
}

String styleLabel(String s) => switch (s) {
  'dark' => t('Dark'),
  'light' => t('Light'),
  _ => t('Glass'),
};

IconData styleIcon(String s) => switch (s) {
  'dark' => Icons.dark_mode_rounded,
  'light' => Icons.light_mode_rounded,
  _ => Icons.blur_on_rounded,
};

String viewLabel(String v) => switch (v) {
  'week' => t('Week'),
  'month' => t('Month'),
  'agenda' => t('Agenda'),
  'day' => t('Day'),
  'year' => t('Year'),
  'next' => t('Next up'),
  _ => t(v),
};

IconData viewIcon(String v) => switch (v) {
  'week' => Icons.view_week_rounded,
  'month' => Icons.calendar_view_month_rounded,
  'agenda' => Icons.view_agenda_rounded,
  'day' => Icons.today_rounded,
  'year' => Icons.calendar_today_rounded,
  'next' => Icons.upcoming_rounded,
  _ => Icons.widgets_rounded,
};

class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});
  final WidgetSkin skin;
  @override
  bool updateShouldNotify(SkinScope old) => old.skin != skin;
}

/// The widget's card in its style; children read colours via [WidgetSkin.of].
class SkinCard extends StatelessWidget {
  const SkinCard({
    super.key,
    required this.style,
    required this.child,
    this.radius = 34,
    this.padding = const EdgeInsets.fromLTRB(22, 16, 22, 18),
  });

  final String style;
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final skin = WidgetSkin.forStyle(style);
    final scoped = SkinScope(skin: skin, child: child);
    final Widget card = switch (style) {
      'glass' => GlassCard(radius: radius, padding: padding, child: scoped),
      _ => AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: padding,
        decoration: BoxDecoration(
          color: skin.light ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(radius),
          border: skin.light
              ? Border.all(color: Colors.black.withValues(alpha: .05))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: skin.light ? .10 : .25),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: scoped,
      ),
    };
    return card;
  }
}

/// Glass needs something to refract: in the app preview a glass widget sits
/// on the landscape "wallpaper"; dark / light widgets sit on the page.
class WidgetBackdrop extends StatelessWidget {
  const WidgetBackdrop({
    super.key,
    required this.style,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 40, 18, 40),
  });
  final String style;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (style != 'glass') return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: Stack(
        children: [
          const Positioned.fill(child: LandscapeBackdrop()),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
