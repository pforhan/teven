import 'package:flutter/material.dart';

/// Placeholder theme for Phase 0.
///
/// Values are carried over from the React app's Bootstrap theme so that screens
/// land visually close to the current implementation during the port. See
/// `frontend/src/index.css` (`#f8f9fa` body background) and the Bootstrap
/// primary (`#3174ad`). Task 3.10 replaces this with the full `ColorScheme`.
class TevenTheme {
  const TevenTheme._();

  /// Page background, from `frontend/src/index.css`.
  static const Color surface = Color(0xFFF8F9FA);

  /// Primary, from the Bootstrap primary used across the React app.
  static const Color primary = Color(0xFF3174AD);

  /// Today's date highlight, from `EventCalendar.tsx` `dayPropGetter`.
  static const Color todayHighlight = Color(0xFFE7F0F7);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
    );
  }
}
