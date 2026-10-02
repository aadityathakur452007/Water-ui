import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';

/// Prompt screen leading into the in-app notification options.
/// Requests the OS notification permission first, then routes onward —
/// the options screen reflects the real grant state instead of assuming it.
class EnableNotificationScreen extends StatefulWidget {
  const EnableNotificationScreen({super.key});

  @override
  State<EnableNotificationScreen> createState() =>
      _EnableNotificationScreenState();
}

class _EnableNotificationScreenState extends State<EnableNotificationScreen> {
  bool _requesting = false;

  /// Requests the OS permission, then routes to the options screen.
  /// Always routes (even on denial/plugin failure) so the user is never
  /// stuck; denial is surfaced honestly via SnackBar + the options screen.
  Future<void> _enableAndContinue() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final status = await Permission.notification.request();
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notifications are blocked. You can allow them in Settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                try {
                  openAppSettings();
                } catch (_) {
                  // Settings opener unavailable — options screen still shows.
                }
              },
            ),
          ),
        );
      } else if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications stay off until you allow them.',
            ),
          ),
        );
      }
    } catch (_) {
      // Plugin missing/failed (e.g. tests, desktop): route onward honestly
      // instead of trapping the user on this screen.
    }
    if (!mounted) return;
    setState(() => _requesting = false);
    Navigator.pushNamed(context, notificationOptionsScreenRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding * 1.5),
          child: Column(
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFEAF4FC),
                child: Icon(
                  Icons.notifications_outlined,
                  color: primaryColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: defaultPadding),
              Text(
                "Stay updated",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: defaultPadding / 2),
              Text(
                "Get order confirmations, delivery alerts and regular delivery reminders.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _enableAndContinue,
                  child: _requesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Enable notifications"),
                ),
              ),
              TextButton(
                onPressed: _requesting ? null : () => Navigator.pop(context),
                child: const Text("Not now"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
