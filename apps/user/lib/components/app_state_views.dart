import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/app_tokens.dart';

// WHY: opacity-only entrance (never width/height/top/left), skipped entirely
// when the OS requests reduced motion.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return _FadeInBody(child: child);
  }
}

class _FadeInBody extends StatefulWidget {
  const _FadeInBody({required this.child});

  final Widget child;

  @override
  State<_FadeInBody> createState() => _FadeInBodyState();
}

class _FadeInBodyState extends State<_FadeInBody> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 150),
      curve: appMotionCurve,
      child: widget.child,
    );
  }
}

// WHY: every list needs loading/empty/error/retry (States.md quality gate:
// "every empty screen explains what to do next, every failure provides
// recovery"). One shared triple so vendor lists, orders and addresses all
// read the same. Icon + copy (never color-only) per the Toast/Banner rule.
// Loading intentionally reuses the existing Skeleton look (flat neutral
// bars) instead of inventing a second shimmer.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              semanticsLabel: 'Loading',
            ),
            const SizedBox(height: AppSpacing.gap),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: appSecondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.title,
    required this.guidance,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String guidance;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: _FadeIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 40, color: appSecondaryTextColor),
              const SizedBox(height: AppSpacing.gap),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                guidance,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: appSecondaryTextColor),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.s12),
                SizedBox(
                  height: AppSpacing.minTouch,
                  child: OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.title = 'Something went wrong.',
    required this.message,
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: _FadeIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: errorColor),
              const SizedBox(height: AppSpacing.gap),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: appSecondaryTextColor),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.s12),
                SizedBox(
                  height: AppSpacing.minTouch,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    child: Text(retryLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
