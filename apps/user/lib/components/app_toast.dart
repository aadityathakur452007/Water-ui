import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/app_tokens.dart';

// WHY: one toast helper so success/error feedback reads the same everywhere
// (ui-checklist Toast: clear copy, corner-ish placement via floating margin,
// icon + copy so color is never the sole signal, dismissable, long enough
// to read aloud). Contrast-safe on purpose: white text + tinted icons on a
// near-black bar (≈ 9-15:1, never the failing 2-3:1 grays).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration? duration,
}) {
  final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
  final tint = isError ? errorColor : successColor;
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: blackColor,
      behavior: SnackBarBehavior.floating,
      // WHY: 16/12/8 scale, pill radius matches inputs.
      margin: const EdgeInsets.all(AppSpacing.screen),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.s12,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(defaultBorderRadious)),
      ),
      duration: duration ??
          Duration(seconds: isError ? 4 : 3),
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ),
  );
}

/// Saving-changes companion: loading spinner inside the feedback itself so
/// the Saving Changes flow (disabled save -> spinner -> saved toast) has a
/// shared "in progress" voice. Caller dismisses via the returned controller.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSaving(
  BuildContext context,
  String message,
) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: blackColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppSpacing.screen),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.s12,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(defaultBorderRadious)),
      ),
      duration: const Duration(minutes: 5),
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ),
  );
}
