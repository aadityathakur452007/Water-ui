import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification preferences. Device-only toggles persisted via
/// shared_preferences — there is no notification-preference endpoint
/// in the backend.
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
  void initState() {
    super.initState();
    _restore();
  }

  String _key(String name) =>
      'notif_${name.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '_')}';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final name in _options.keys) {
        final saved = prefs.getBool(_key(name));
        if (saved != null) _options[name] = saved;
      }
    });
  }

  Future<void> _save(String name, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(name), value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved."), showCloseIcon: true),
    );
  }

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
            onChanged: (v) {
              setState(() => _options[entry.key] = v);
              _save(entry.key, v);
            },
          );
        },
      ),
    );
  }
}
