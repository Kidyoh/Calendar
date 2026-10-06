import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Frosted-glass surface: blurs whatever is behind it, adds a luminous tint,
/// a gradient hairline border and a soft shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 36,
    this.blur = 26,
    this.padding = const EdgeInsets.all(20),
    this.tint = const Color(0xFF1E2A1A),
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsets padding;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            foregroundPainter: _GlassBorder(radius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    tint.withValues(alpha: 0.30),
                    tint.withValues(alpha: 0.42),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBorder extends CustomPainter {
  _GlassBorder(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.30),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlassBorder old) => old.radius != radius;
}

enum PillStyle { solid, glass }

/// Segmented pill control. `solid` = black/outlined pills (Today | Calendar),
/// `glass` = translucent track with a white thumb (Weekly | Monthly).
class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.style = PillStyle.solid,
    this.track,
    this.thumb,
    this.text,
    this.selectedText,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final PillStyle style;

  /// Glass style colours (widget skins); default to white-on-glass.
  final Color? track;
  final Color? thumb;
  final Color? text;
  final Color? selectedText;

  @override
  Widget build(BuildContext context) {
    final glass = style == PillStyle.glass;
    final items = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final sel = i == index;
      final Color bg = glass
          ? Colors.transparent
          : (sel ? AppColors.ink : Colors.transparent);
      final Color fg = glass
          ? (sel
                ? (selectedText ?? AppColors.ink)
                : (text ?? Colors.white.withValues(alpha: 0.75)))
          : (sel ? Colors.white : AppColors.ink);
      final pill = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: glass ? 18 : 16,
            vertical: glass ? 13 : 11,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(40),
            border: glass || sel
                ? null
                : Border.all(color: AppColors.ink.withValues(alpha: 0.25)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              labels[i],
              maxLines: 1,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
      items.add(glass ? Expanded(child: pill) : pill);
      if (!glass && i < labels.length - 1) items.add(const SizedBox(width: 6));
    }
    final row = Row(
      mainAxisSize: glass ? MainAxisSize.max : MainAxisSize.min,
      children: items,
    );
    if (!glass) return row;
    final n = labels.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track ?? Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Stack(
        children: [
          // Sliding white thumb behind the labels.
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 380),
              curve: const Cubic(0.2, 1.25, 0.4, 1),
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumb ?? Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          row,
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.background,
    this.foreground,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: background ?? Colors.black.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: foreground ?? AppColors.ink,
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// The black "Dynamic Island" style container.
class Island extends StatelessWidget {
  const Island({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 16, 22, 18),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Decorative mountain / mist / winding-road scene used behind the glass widget
/// so the blur has something rich to refract.
class LandscapeBackdrop extends StatelessWidget {
  const LandscapeBackdrop({super.key});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _LandscapePainter(), size: Size.infinite);
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9CFD8), Color(0xFFE3ECEA)],
        ).createShader(Offset.zero & s),
    );

    Path hill(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx * w, pts.first.dy * h);
      for (var i = 1; i < pts.length - 1; i += 2) {
        p.quadraticBezierTo(
          pts[i].dx * w,
          pts[i].dy * h,
          pts[i + 1].dx * w,
          pts[i + 1].dy * h,
        );
      }
      return p
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    // far ridge
    canvas.drawPath(
      hill(const [
        Offset(0, .30),
        Offset(.25, .08),
        Offset(.5, .22),
        Offset(.72, .02),
        Offset(1, .26),
      ]),
      Paint()..color = const Color(0xFF58785A),
    );
    // mist
    final mist = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .45, h * .22),
        width: w * .9,
        height: h * .16,
      ),
      mist,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .8, h * .1),
        width: w * .6,
        height: h * .12,
      ),
      mist,
    );
    // mid hills
    canvas.drawPath(
      hill(const [
        Offset(0, .42),
        Offset(.3, .26),
        Offset(.55, .40),
        Offset(.8, .30),
        Offset(1, .38),
      ]),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF78A646), Color(0xFF4F7F39)],
        ).createShader(Offset.zero & s),
    );
    // near slope
    canvas.drawPath(
      hill(const [
        Offset(0, .62),
        Offset(.35, .50),
        Offset(.7, .58),
        Offset(.9, .52),
        Offset(1, .56),
      ]),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9CCB4E), Color(0xFF5E8F2E)],
        ).createShader(Offset.zero & s),
    );
    // winding road
    final road = Path()
      ..moveTo(w * .12, h * .50)
      ..cubicTo(w * .10, h * .62, w * .55, h * .62, w * .42, h * .76)
      ..cubicTo(w * .30, h * .90, w * .80, h * .90, w * .95, h * 1.02);
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .075
        ..color = const Color(0xFF6C7476)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
    );
}
