import 'package:flutter/material.dart';

import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_order.dart';

/// Order detail + status advance. Only valid contract transitions are
/// offered: next step forward, plus cancel (any non-final state).
/// After PATCH the list refreshes (returns true to the caller).
class VendorOrderDetailScreen extends StatefulWidget {
  const VendorOrderDetailScreen(
      {super.key, required this.service, required this.initial});

  final VendorService service;
  final VendorOrder initial;

  @override
  State<VendorOrderDetailScreen> createState() =>
      _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState
    extends State<VendorOrderDetailScreen> {
  late VendorOrder _order;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.initial;
  }

  bool get _final =>
      _order.status == 'delivered' || _order.status == 'cancelled';

  /// Capitalizes a wire value for display ('one-time' → 'One-time').
  static String _display(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Destructive action: confirm before cancelling.
  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
            'The customer will not receive this delivery. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Cancel order',
                style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
    if (ok == true) _advance('cancelled');
  }

  Future<void> _advance(String status) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.updateStatus(_order.id, status);
      if (!mounted) return;
      // Pop the new status; the caller shows the SnackBar (its context
      // is still mounted, ours is not).
      Navigator.of(context).pop(status);
    } on AppException catch (e) {
      final expired =
          e.code == 'UNAUTHENTICATED' || e.status == 401;
      if (expired) {
        await const AuthService().handleUnauthorized();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (_) => false,
        );
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = nextStatus(_order.status);
    return Scaffold(
      appBar: AppBar(title: Text('Order #${_order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${_order.status.replaceAll('_', ' ')}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      'Type: ${_display(_order.type)} \u00B7 Slot: ${_order.slot}'),
                  if (_order.hasCustomer) ...[
                    const SizedBox(height: 8),
                    const Text('Customer',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    if (_order.customerName.isNotEmpty)
                      Text(_order.customerName),
                    if (_order.customerPhone.isNotEmpty)
                      Text(_order.customerPhone),
                    if (_order.customerEmail.isNotEmpty)
                      Text(_order.customerEmail),
                  ],
                  const SizedBox(height: 8),
                  const Text('Deliver to',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      '${_order.addressLabel}\n${_order.addressLine}, ${_order.addressCity}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final item in _order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                          '${item.name} \u00D7${item.qty} \u2014 \u20B9${item.price}'),
                    ),
                  const Divider(),
                  Text('Total: \u20B9${_order.total}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFD32F2F))),
          ],
          const SizedBox(height: 16),
          if (!_final && next != null)
            ElevatedButton(
              onPressed: _busy ? null : () => _advance(next),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(nextStatusLabel(_order.status)),
            ),
          if (!_final) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _confirmCancel,
              child: const Text('Cancel order'),
            ),
          ],
        ],
      ),
    );
  }
}
