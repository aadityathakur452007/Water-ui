import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/app_tokens.dart';

// WHY: one base style for every card (ui-checklist Card: consistency +
// 8pt-divisible padding). Flat 1px border, no glow/gradient/shadow per
// premium-design Minimalist + water_ui_theme (useGlow/useShadows false).
// WHY: ConstrainedBox min 44px keeps tappable cards inside the touch-target
// rule without every caller remembering it.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;

  /// Padding level off the 8pt scale — 8, 12 (default, spec §5), or 16.
  final double padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      constraints: onTap != null
          ? const BoxConstraints(minHeight: AppSpacing.minTouch)
          : null,
      padding: EdgeInsets.all(padding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.all(Radius.circular(defaultBorderRadious)),
        border: Border.fromBorderSide(BorderSide(color: blackColor10)),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        borderRadius:
            const BorderRadius.all(Radius.circular(defaultBorderRadious)),
        onTap: onTap,
        child: body,
      ),
    );
  }
}
