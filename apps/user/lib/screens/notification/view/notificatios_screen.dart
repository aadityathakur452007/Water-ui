import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';

class _WaterNotification {
  final String title;
  final String body;
  final String time;

  const _WaterNotification(this.title, this.body, this.time);
}

// Local seed: the backend contract exposes no notification endpoint, so
// this list is illustrative copy (not live data) until one exists.
const _notifications = [
  _WaterNotification("Order confirmed",
      "Your 2 × 20L water jars order #WD-00124 is confirmed.", "7:30 AM"),
  _WaterNotification("Out for delivery",
      "Your 2 × 20L water jars are out for delivery.", "8:05 AM"),
  _WaterNotification("Delivered",
      "Your 10L water can was delivered. Enjoy!", "Yesterday"),
  _WaterNotification("Upcoming recurring delivery",
      "Tomorrow • 8:00 AM: 2 × 20L Water Jar.", "Yesterday"),
  _WaterNotification("Payment confirmation",
      "₹130 paid in cash for order #WD-00110.", "18 Sept"),
  _WaterNotification("Subscription paused",
      "Your daily 20L delivery is paused. Resume anytime.", "10 Sept"),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Notifications"),
          actions: [
            IconButton(
              tooltip: "Notification settings",
              onPressed: () {
                Navigator.pushNamed(
                    context, notificationOptionsScreenRoute);
              },
              icon: const Icon(Icons.settings_outlined),
            )
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(defaultPadding),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final n = _notifications[index];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: defaultPadding / 2),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF4FC),
                child:
                    Icon(Icons.water_drop, color: primaryColor, size: 20),
              ),
              title: Text(n.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text("${n.body}\n${n.time}",
                  style: Theme.of(context).textTheme.bodyMedium),
              isThreeLine: true,
            );
          },
        ));
  }
}
