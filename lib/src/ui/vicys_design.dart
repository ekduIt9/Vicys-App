import 'package:flutter/material.dart';

abstract final class VicysColors {
  static const background = Color(0xff131313);
  static const surfaceLowest = Color(0xff0e0e0e);
  static const surfaceLow = Color(0xff1c1b1b);
  static const surface = Color(0xff201f1f);
  static const surfaceHigh = Color(0xff2a2a2a);
  static const surfaceHighest = Color(0xff353534);
  static const primary = Color(0xffc0c1ff);
  static const onPrimary = Color(0xff1000a9);
  static const secondary = Color(0xffffb0cd);
  static const tertiary = Color(0xff4edea3);
  static const onSurface = Color(0xffe5e2e1);
  static const onSurfaceVariant = Color(0xffc7c4d7);
  static const outline = Color(0xff908fa0);
  static const outlineVariant = Color(0xff464554);
}

abstract final class VicysTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: VicysColors.primary,
      onPrimary: VicysColors.onPrimary,
      secondary: VicysColors.secondary,
      tertiary: VicysColors.tertiary,
      surface: VicysColors.surface,
      onSurface: VicysColors.onSurface,
      outline: VicysColors.outline,
      error: Color(0xffffb4ab),
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: VicysColors.background,
      useMaterial3: true,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: VicysColors.onSurface,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: VicysColors.surfaceLow.withValues(alpha: .96),
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: states.contains(WidgetState.selected)
                  ? VicysColors.primary
                  : VicysColors.outline,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 27,
              color: states.contains(WidgetState.selected)
                  ? VicysColors.primary
                  : VicysColors.outline,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VicysColors.surfaceLow,
        hintStyle: const TextStyle(color: VicysColors.outline),
        prefixIconColor: VicysColors.outline,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: VicysColors.surfaceLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x12ffffff)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: VicysColors.primary,
        inactiveTrackColor: VicysColors.outlineVariant,
        thumbColor: VicysColors.primary,
        overlayColor: Color(0x24c0c1ff),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VicysColors.primary,
          foregroundColor: VicysColors.onPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class VicysWordmark extends StatelessWidget {
  const VicysWordmark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Text(
        'VICYS',
        style: TextStyle(
          fontSize: compact ? 24 : 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          color: VicysColors.onSurface,
        ),
      );
}

class MonoLabel extends StatelessWidget {
  const MonoLabel(
    this.text, {
    super.key,
    this.color = VicysColors.onSurfaceVariant,
    this.fontSize = 11,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          letterSpacing: 1.2,
          color: color,
        ),
      );
}
