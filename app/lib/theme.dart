import 'package:flutter/material.dart';

/// Megrim's themes. Both are built from the same purple seed; the app follows the OS light/dark
/// setting (`ThemeMode.system`, wired in `app.dart`). The chart card surface is pinned per mode
/// (dark `#1E1E1E`, light `#FCFCFB`) so the validated chart palettes in `analytics_screen.dart`
/// have a known background to sit on.

/// Chart/card surfaces the analytics palettes were validated against — exported so there's one
/// source of truth shared between the theme and the palette choices.
const Color kDarkCardSurface = Color(0xFF1E1E1E);
const Color kLightCardSurface = Color(0xFFFCFCFB);

ThemeData megrimDarkTheme() => _theme(Brightness.dark);
ThemeData megrimLightTheme() => _theme(Brightness.light);

ThemeData _theme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.purple,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF121212) : const Color(0xFFF7F5FA),
    cardColor: isDark ? kDarkCardSurface : kLightCardSurface,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
  );
}
