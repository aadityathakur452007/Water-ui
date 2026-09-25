import 'package:flutter/material.dart';

/// Notification preferences. In-app toggles with local state —
/// there is no notification-preference endpoint in the backend.
class NotificationOptionsScreen extends StatefulWidget {
  const NotificationOptionsScreen({super.key});

  @override
  State<NotificationOptionsScreen> createState() =>
      _NotificationOptionsScreenState();
}

class _NotificationOptionsScreenState
    extends State<NotificationOptionsScreen> {
  final _options = <String, bool>{
    "Order updates": true,
    "Delivery alerts": true,
    "Subscription reminders": true,
    "Offers": false,
  };

  static const _hints = {
    "Order updates": "Confirmations and status changes for your orders.",
    "Delivery alerts": "Out-for-delivery and delivered alerts.",
    "Subscription reminders": "Upcoming regular delivery reminders.",
    "Offers": "Discounts and new product announcements.",
  };

  @override
  Widget build(BuildContext context) {
    final entries = _options.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Notification Options")),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return SwitchListTile(
            title: Text(entry.key),
            subtitle: Text(_hints[entry.key]!),
            value: entry.value,
            onChanged: (v) =>
                setState(() => _options[entry.key] = v),
          );
        },
      ),
    );
  }
}
