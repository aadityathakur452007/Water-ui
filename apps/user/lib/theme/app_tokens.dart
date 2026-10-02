import 'package:flutter/material.dart';

import '../constants.dart';

// WHY: one 8pt scale (4/8/12/16/24) kills the random 17px/23px drift the
// guardrails forbid; spec fixes screen=16, card=12, gaps=8 for this build
// (premium-design asks 24px section padding on marketing pages, but the
// approved vendor-missing spec §5 pins 16/12/8 for app screens).
abstract final class AppSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s24 = 24.0;

  /// Screen-level padding (spec §5).
  static const double screen = s16;

  /// Default card padding (spec §5) — matches ui-checklist Card spacing.
  static const double card = s12;

  /// Standard gap between tappable / stacked elements (spec §5).
  static const double gap = s8;

  /// Minimum touch target edge (Apple HIG + Material + guardrails).
  static const double minTouch = 44.0;

  /// Minimum gap between adjacent touch targets.
  static const double touchGap = s8;
}

// WHY: contrast tokens that provably pass WCAG AA 4.5:1, replacing the
// hardcoded low-contrast grays found in the audit:
// - blackColor40 #A2A2A5 ≈ 2.6:1 on white  -> FAIL (was bodyMedium + checkbox)
// - greyColor #B8B5C3    ≈ 2.0:1 on white  -> FAIL (was light hint)
// - whileColor40 #666    ≈ 2.9:1 on #1C1C25 -> FAIL (was dark hint)
// Replacements below are existing theme tokens (no new hues, 60-30-10 kept):
// - blackColor80 #45454B ≈ 9.5:1 on white, ≈ 9:1 on lightGrey fill -> PASS
// - whileColor80 #CCC     ≈ 10.5:1 on darkGrey fill                 -> PASS
// - primary 700 #1664B2  ≈ 6.0:1 on white (base primary ≈ 4.3:1,
//   just under AA, so tinted-price text uses the 700 step)          -> PASS
const Color appBodyTextColor = blackColor;
const Color appSecondaryTextColor = blackColor80;
const Color appHintColor = blackColor80;
const Color appDarkHintColor = whileColor80;

/// Price/brand tint for light backgrounds. Same hue family as primaryColor
/// (primaryMaterialColor 700 step), darkened to clear 4.5:1.
const Color appPriceColor = Color(0xFF1664B2);

/// WHY: Modern Minimalist motion — opacity only, 150-200ms, standard ease,
/// and dead when the OS asks for reduced motion (States.md accessibility).
Duration appMotionDuration(BuildContext context) {
  final reduce = MediaQuery.of(context).disableAnimations;
  return reduce ? Duration.zero : const Duration(milliseconds: 150);
}

const Curve appMotionCurve = Curves.easeInOut;
