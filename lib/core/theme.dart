import 'package:flutter/material.dart';

class AppColors {
  static const cream = Color(0xFFE9E8E3);
  static const paper = Color(0xFFF7F6F2);
  static const ink = Color(0xFF141414);
  static const mute = Color(0xFF8A8A86);
}

/// A soft pastel card palette (lavender, rose, teal, sage, amber, slate).
class DayPalette {
  const DayPalette(this.bg, this.fg, this.chip);
  final Color bg;
  final Color fg;
  final Color chip;
}

const palettes = <DayPalette>[
  DayPalette(Color(0xFFBDB4D4), Color(0xFF4B4170), Color(0xFF4B4170)),
  DayPalette(Color(0xFFD09BA6), Color(0xFF5E2A36), Color(0xFF5E2A36)),
  DayPalette(Color(0xFF9ECBC7), Color(0xFF0F5A57), Color(0xFF11635F)),
  DayPalette(Color(0xFFC5CE9B), Color(0xFF485418), Color(0xFF55661B)),
  DayPalette(Color(0xFFE6BA6E), Color(0xFF5E4310), Color(0xFF6B4A10)),
  DayPalette(Color(0xFFB1BDBB), Color(0xFF34423F), Color(0xFF3F524E)),
];

DayPalette paletteAt(int i) => palettes[i.abs() % palettes.length];

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.light,
      surface: AppColors.paper,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
