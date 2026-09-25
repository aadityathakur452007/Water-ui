import 'package:flutter_ui_collection/flutter_ui_collection.dart';

import '../constants.dart';

/// Shared water-blue tokens for `flutter_ui_collection` widgets.
///
/// Hoisted from the former per-screen `_waterUiTheme()` copies (orders +
/// subscriptions). Flat, glow-free, gradient-free: satisfies `UiTheme.of`
/// with the app's Material palette. Provided once at the root in `main.dart`
/// so screens like `VendorDashboardScreen` never hit the release-mode
/// `widget!.data` null crash.
UiThemeData waterUiThemeData() {
  final base = MinimalTheme.light;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: primaryColor,
      success: successColor,
      error: errorColor,
    ),
    useGlow: false,
    useGradients: false,
    useShadows: false,
  );
}
