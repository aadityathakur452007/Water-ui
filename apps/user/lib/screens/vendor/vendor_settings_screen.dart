import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_settings_store.dart';

/// Vendor settings (4th tab). Device-local only: there is no settings
/// endpoint in the backend, so business profile / slots / working days /
/// notification toggles persist via shared_preferences on this device.
/// Support info is a static contact card.
///
/// Live branch (Slice 1, `!AppConfig.demoMode`): business profile and
/// delivery slots sync through `VendorService` (GET on open with
/// skeleton/error/retry, PATCH/PUT on save with dirty/disabled + loading
/// + toast, rollback notice on 409/NETWORK). Working days + notification
/// toggles stay device-local in both modes (no server endpoint).
class VendorSettingsScreen extends StatefulWidget {
  const VendorSettingsScreen(
      {super.key,
      this.store = const VendorSettingsStore(),
      this.service = const VendorService()});

  final VendorSettingsStore store;
  final VendorService service;

  @override
  State<VendorSettingsScreen> createState() => _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends State<VendorSettingsScreen> {
  // Slice 1: live mode talks to the server; demo keeps the exact
  // device-local behavior below byte-intact.
  static bool get _live => !AppConfig.demoMode;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _hours = TextEditingController();
  Map<String, bool> _slots = {};
  Map<String, bool> _days = {};
  Map<String, bool> _notifs = {};
  bool _loading = true;
  bool _saving = false;

  // Live-only state.
  String? _loadError;
  String? _saveError;
  String? _nameError;
  String? _phoneError;
  bool _dirty = false;
  Map<String, String> _snapshot = const {};

  @override
  void initState() {
    super.initState();
    if (_live) {
      for (final c in [_name, _phone, _address, _hours]) {
        c.addListener(_markDirty);
      }
    }
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

  void _markDirty() {
    if (!_live || !mounted) return;
    final dirty = _name.text.trim() != (_snapshot['name'] ?? '') ||
        _phone.text.trim() != (_snapshot['phone'] ?? '') ||
        _address.text.trim() != (_snapshot['address'] ?? '') ||
        _hours.text.trim() != (_snapshot['hours'] ?? '');
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  void _applyProfile(VendorProfile p) {
    _name.text = p.name;
    _phone.text = p.phone;
    _address.text = p.address;
    _hours.text = p.hours;
    _snapshot = p.toJson();
  }

  Future<void> _restore() async {
    if (!_live) {
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
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await widget.service.fetchProfile();
      var slots = await widget.service.fetchSlots();
      final days = await widget.store.loadDays();
      final notifs = await widget.store.loadNotifs();
      if (!mounted) return;
      if (slots.isEmpty) {
        // Server has no slots yet: seed the toggle labels locally so
        // the vendor can switch them on (first save persists them).
        slots = {
          for (final s in VendorSettingsStore.defaultSlots) s: true,
        };
      }
      setState(() {
        _applyProfile(profile);
        _slots = slots;
        _days = days;
        _notifs = notifs;
        _dirty = false;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      if (_isExpired(e)) {
        await const AuthService().handleUnauthorized();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (_) => false,
        );
        return;
      }
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  bool _isExpired(AppException e) =>
      e.code == 'UNAUTHENTICATED' || e.status == 401;

  Future<void> _saveProfile() async {
    if (!_live) {
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
      return;
    }
    final errors = validateVendorProfile(
      name: _name.text,
      phone: _phone.text,
    );
    setState(() {
      _nameError = errors['name'];
      _phoneError = errors['phone'];
    });
    if (errors.isNotEmpty) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final previous = Map<String, String>.from(_snapshot);
    try {
      final saved = await widget.service.saveProfile(VendorProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        hours: _hours.text.trim(),
      ));
      if (!mounted) return;
      setState(() {
        _applyProfile(saved);
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business profile synced.')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      if (_isExpired(e)) {
        await const AuthService().handleUnauthorized();
        if (!mounted) return;
        setState(() => _saving = false);
        Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (_) => false,
        );
        return;
      }
      // Roll back the snapshot compare so Save re-enables honestly;
      // typed values stay on screen (no data loss).
      setState(() {
        _snapshot = previous;
        _dirty = true;
        _saving = false;
        _saveError = e.code == 'CONFLICT'
            ? 'Someone else updated this profile. Review and save again.'
            : '${e.message} Your changes are kept — try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _snapshot = previous;
        _dirty = true;
        _saving = false;
        _saveError = '$e Your changes are kept — try again.';
      });
    }
  }

  Future<void> _saveSlotLive(String key, bool value) async {
    final previous = Map<String, bool>.from(_slots);
    setState(() => _slots[key] = value);
    try {
      await widget.service.saveSlots(_slots);
      _toast('Slot synced.');
    } on AppException catch (e) {
      if (!mounted) return;
      if (_isExpired(e)) {
        await const AuthService().handleUnauthorized();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (_) => false,
        );
        return;
      }
      setState(() => _slots = previous);
      _toast('${e.message} Change reverted — try again.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Live: skeleton mirrors the profile card structure; demo keeps
      // the original spinner (device-local loads are instant).
      if (!_live) {
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
        children: const [
          _SkeletonLine(width: 160),
          SizedBox(height: 8),
          _SkeletonCard(lines: 4),
          SizedBox(height: 16),
          _SkeletonLine(width: 200),
          SizedBox(height: 8),
          _SkeletonCard(lines: 3),
        ],
      );
    }
    if (_live && _loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load settings.'),
              const SizedBox(height: 4),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6E6E73)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _restore,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Business profile',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            // WHY: honest sync label — live flips Synced/Unsaved, demo
            // stays device-local (byte-intact copy below).
            if (_live)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (_dirty
                          ? const Color(0xFFEF6C00)
                          : const Color(0xFF2E7D32))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _dirty ? 'Unsaved changes' : 'Synced to server',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _dirty
                        ? const Color(0xFFEF6C00)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'Business name',
                    errorText: _live ? _nameError : null,
                  ),
                ),
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      errorText: _live ? _phoneError : null,
                    )),
                TextField(
                    controller: _address,
                    decoration:
                        const InputDecoration(labelText: 'Address')),
                TextField(
                    controller: _hours,
                    decoration: const InputDecoration(
                        labelText: 'Hours (e.g. 8 AM \u2013 8 PM)')),
                if (_live && _saveError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _saveError!,
                    style: const TextStyle(color: Color(0xFFD32F2F)),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // WHY: ui-checklist Saving Changes — disabled until
                    // dirty in live mode; demo keeps always-on behavior.
                    onPressed: (_saving || (_live && !_dirty))
                        ? null
                        : _saveProfile,
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
        Text(
          _live
              ? 'Slots sync to the server. Days stay on this device.'
              : 'Applies to this device until server slots land.',
          style: const TextStyle(color: Color(0xFF6E6E73)),
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
                    if (!_live) {
                      setState(() => _slots[e.key] = v);
                      await widget.store.saveSlot(e.key, v);
                      _toast('Saved on this device.');
                      return;
                    }
                    await _saveSlotLive(e.key, v);
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
        Card(
          child: Column(
            children: [
              const ListTile(
                leading:
                    Icon(Icons.support_agent, color: Color(0xFF1B7BD6)),
                title: Text('Shodasha Mineral Waters'),
                subtitle:
                    Text('Care: 1800-000-000 \u2022 care@shodasha.local'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.forum, color: Color(0xFF1B7BD6)),
                title: const Text('Support tickets'),
                subtitle: Text(_live
                    ? 'Open a ticket, track replies. Avg response: 1 business day.'
                    : 'Available on the live server — care contact above works in demo.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                    context, vendorTicketsScreenRoute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton placeholder: flat neutral boxes mirroring content layout
/// (ui-checklist Skeleton: match structure, subtle shape, no shimmer
/// dependency).
class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < lines; i++) ...[
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              if (i != lines - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
