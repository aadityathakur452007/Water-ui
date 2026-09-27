import 'package:flutter/material.dart';

import 'vendor_settings_store.dart';

/// Vendor settings (4th tab). Device-local only: there is no settings
/// endpoint in the backend, so business profile / slots / working days /
/// notification toggles persist via shared_preferences on this device.
/// Support info is a static contact card.
class VendorSettingsScreen extends StatefulWidget {
  const VendorSettingsScreen({super.key, this.store = const VendorSettingsStore()});

  final VendorSettingsStore store;

  @override
  State<VendorSettingsScreen> createState() => _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends State<VendorSettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _hours = TextEditingController();
  Map<String, bool> _slots = {};
  Map<String, bool> _days = {};
  Map<String, bool> _notifs = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final profile = await widget.store.loadProfile();
    final slots = await widget.store.loadSlots();
    final days = await widget.store.loadDays();
    final notifs = await widget.store.loadNotifs();
    if (!mounted) return;
    setState(() {
      _name.text = profile['name'] ?? '';
      _phone.text = profile['phone'] ?? '';
      _address.text = profile['address'] ?? '';
      _hours.text = profile['hours'] ?? '';
      _slots = slots;
      _days = days;
      _notifs = notifs;
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    await widget.store.saveProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      hours: _hours.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business profile saved on this device.')),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading settings\u2026'),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Business profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: 'Business name')),
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                TextField(
                    controller: _address,
                    decoration:
                        const InputDecoration(labelText: 'Address')),
                TextField(
                    controller: _hours,
                    decoration: const InputDecoration(
                        labelText: 'Hours (e.g. 8 AM \u2013 8 PM)')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: Text(_saving ? 'Saving\u2026' : 'Save profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Delivery slots & working days',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Applies to this device until server slots land.',
          style: TextStyle(color: Color(0xFF6E6E73)),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final e in _slots.entries)
                SwitchListTile(
                  title: Text(e.key),
                  value: e.value,
                  onChanged: (v) async {
                    setState(() => _slots[e.key] = v);
                    await widget.store.saveSlot(e.key, v);
                    _toast('Saved on this device.');
                  },
                ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _days.entries)
                    FilterChip(
                      label: Text(e.key),
                      selected: e.value,
                      onSelected: (v) async {
                        setState(() => _days[e.key] = v);
                        await widget.store.saveDay(e.key, v);
                        _toast('Saved on this device.');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Notifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('New order alerts'),
                value: _notifs['newOrder'] ?? true,
                onChanged: (v) async {
                  setState(() => _notifs['newOrder'] = v);
                  await widget.store.saveNotif('newOrder', v);
                },
              ),
              SwitchListTile(
                title: const Text('Cancellation alerts'),
                value: _notifs['cancellation'] ?? true,
                onChanged: (v) async {
                  setState(() => _notifs['cancellation'] = v);
                  await widget.store.saveNotif('cancellation', v);
                },
              ),
              SwitchListTile(
                title: const Text('Daily summary'),
                value: _notifs['summary'] ?? false,
                onChanged: (v) async {
                  setState(() => _notifs['summary'] = v);
                  await widget.store.saveNotif('summary', v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Support',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading:
                Icon(Icons.support_agent, color: Color(0xFF1B7BD6)),
            title: Text('Shodasha Mineral Waters'),
            subtitle: Text('Care: 1800-000-000 \u2022 care@shodasha.local'),
          ),
        ),
      ],
    );
  }
}
