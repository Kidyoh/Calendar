import 'dart:async';

import 'package:flutter/material.dart';

/// Shared motion language: soft, springy, never longer than ~600ms.
class Motion {
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 620);
  static const ease = Curves.easeOutCubic;
  static const spring = Cubic(0.2, 1.35, 0.4, 1); // gentle overshoot
}

/// Fades + slides its child in once, after [delay]. Re-runs when [key] changes.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 0.12),
    this.scale = 0.98,
  });

  /// Staggered helper for list items.
  factory FadeSlideIn.stagger(
    int index, {
    Key? key,
    required Widget child,
    int stepMs = 60,
  }) => FadeSlideIn(
    key: key,
    delay: Duration(milliseconds: (index.clamp(0, 10)) * stepMs),
    child: child,
  );

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scale;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Motion.ease,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: FractionalTranslation(
            translation: Offset(
              widget.offset.dx * (1 - v),
              widget.offset.dy * (1 - v),
            ),
            child: Transform.scale(
              scale: widget.scale + (1 - widget.scale) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Squishes slightly while pressed. Doesn't consume the gesture, so it can
/// wrap InkWells / GestureDetectors.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.965});
  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : Motion.medium,
        curve: _down ? Curves.easeOut : Motion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Text that rolls vertically when its value changes (odometer feel).
class RollingText extends StatelessWidget {
  const RollingText(
    this.text, {
    super.key,
    required this.style,
    this.up = true,
  });
  final String text;
  final TextStyle style;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.ease,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(text);
        final dy = (up ? 0.45 : -0.45) * (incoming ? 1 : -1);
        return ClipRect(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: Offset(0, dy),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
        );
      },
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

/// A slow, endless float (used by onboarding illustrations).
class Floating extends StatefulWidget {
  const Floating({
    super.key,
    required this.child,
    this.amplitude = 8,
    this.period = 3200,
    this.phase = 0,
  });
  final Widget child;
  final double amplitude;
  final int period;
  final double phase;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.period),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeInOutSine.transform((_c.value + widget.phase) % 1.0);
      return Transform.translate(
        offset: Offset(0, (t - .5) * 2 * widget.amplitude),
        child: child,
      );
    },
  );
}
