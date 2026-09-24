import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';

/// Water-blue design tokens. Flat surfaces only — no gradients, no glow.
abstract final class VendorTheme {
  static const Color primary = Color(0xFF1B7BD6);
  static const Color onPrimary = Colors.white;
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF6E6E73);
  static const Color border = Color(0xFFE1E4E8);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);

  static ThemeData material() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  /// UiTheme wrapper required by flutter_ui_collection dashboard widgets
  /// (UiStatCard/UiBarChart resolve colors via UiTheme.of — asserts non-null).
  /// Minimal preset: flat, no glow, no gradients — matches this app's tokens.
  static UiThemeData ui() {
    final base = MinimalTheme.light;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: onPrimary,
      ),
      useGlow: false,
      useGradients: false,
    );
  }
}
