import 'package:flutter/material.dart';
import 'package:shop/constants.dart';

/// Payment methods for water delivery: Cash on Delivery + UPI.
/// (Card rails arrive with the backend; no dead routes here.)
///
/// CONTRACT for checkout (Agent A): when opened for selection, this screen
/// pops a `String` result — `'cod'` or `'upi'` — so checkout can sync the
/// chosen method. A plain back navigation pops `null` (no change).
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, this.initial});

  /// Currently selected method code (`'cod'` | `'upi'`), if any.
  final String? initial;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  static const _methods = [
    (
      code: 'cod',
      title: 'Cash on Delivery',
      subtitle: 'Pay at your doorstep',
      icon: Icons.payments_outlined,
    ),
    (
      code: 'upi',
      title: 'UPI',
      subtitle: 'Pay instantly on delivery',
      icon: Icons.qr_code_2_outlined,
    ),
  ];

  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected =
        _methods.any((m) => m.code == widget.initial) ? widget.initial! : 'cod';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Methods")),
      body: RadioGroup<String>(
        groupValue: _selected,
        onChanged: (v) {
          if (v != null) setState(() => _selected = v);
        },
        child: ListView(
          children: [
            for (final m in _methods)
              RadioListTile<String>(
                value: m.code,
                activeColor: primaryColor,
                secondary: Icon(m.icon, color: primaryColor),
                title: Text(m.title),
                subtitle: Text(m.subtitle),
              ),
            const Padding(
              padding: EdgeInsets.all(defaultPadding),
              child: Text(
                "Card payments will be added with online checkout.",
                style: TextStyle(color: blackColor60, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text("Use this payment method"),
          ),
        ),
      ),
    );
  }
}
