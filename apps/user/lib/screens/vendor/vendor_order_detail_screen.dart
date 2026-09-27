import 'package:flutter/material.dart';

import '../../components/network_image_with_loader.dart';
import '../../models/cart_model.dart';
import '../../repositories/product_repository.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_order.dart';

/// Order detail + status advance. Only valid contract transitions are
/// offered: next step forward, plus cancel (any non-final state).
/// After PATCH the list refreshes (returns true to the caller).
/// Totals already include the server-owned ₹10 fee (labeled, not re-added).
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
  final _products = const ProductRepository();

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
      // is still mounted, ours is not). The shared store/DB is the sync
      // path back to the user app (refresh-on-pop) — no push channel.
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
    // Days are not on orders today — show only when the backend provides
    // them (or a frequency for regular orders); otherwise show nothing.
    final daysLine = _order.daysLabel.isNotEmpty
        ? _order.daysLabel
        : _order.frequency.isNotEmpty
            ? _order.frequency
            : '';
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
                  if (daysLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Days: $daysLine',
                        style: const TextStyle(
                            color: Color(0xFF1B7BD6),
                            fontWeight: FontWeight.w500)),
                  ],
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
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: item.productId.isEmpty
                                ? const Icon(Icons.water_drop,
                                    color: Color(0xFF1B7BD6))
                                : NetworkImageWithLoader(
                                    _products
                                        .byId(item.productId)
                                        .image,
                                    radius: 8),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                '${item.qty} \u00D7 ${item.name}'),
                          ),
                          Text(inr(item.price.toDouble())),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text('Total: ${inr(_order.total.toDouble())}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('incl. ${inr(10)} delivery fee',
                      style:
                          const TextStyle(color: Color(0xFF6E6E73))),
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
