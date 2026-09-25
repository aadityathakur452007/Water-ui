import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';

/// Prompt screen leading into the in-app notification options.
/// Local-only: the app has no push-permission backend to confirm against,
/// so this screen explains the benefit and routes onward honestly.
class EnableNotificationScreen extends StatelessWidget {
  const EnableNotificationScreen({super.key});

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
                  onPressed: () {
                    Navigator.pushNamed(
                        context, notificationOptionsScreenRoute);
                  },
                  child: const Text("Enable notifications"),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Not now"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
