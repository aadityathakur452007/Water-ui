import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/screens/profile/views/components/profile_menu_item_list_tile.dart';

/// Payment methods for water delivery: Cash on Delivery + UPI.
/// (Card rails arrive with the backend; no dead routes here.)
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Methods")),
      body: ListView(
        children: [
          _method(
            index: 0,
            text: "Cash on Delivery",
            svgSrc: "assets/icons/Cash.svg",
            subtitle: "Pay at your doorstep",
          ),
          _method(
            index: 1,
            text: "UPI",
            svgSrc: "assets/icons/card.svg",
            subtitle: "Pay instantly on delivery",
            isShowDivider: false,
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
    );
  }

  Widget _method({
    required int index,
    required String text,
    required String svgSrc,
    required String subtitle,
    bool isShowDivider = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileMenuListTile(
          text: _selected == index ? "$text ✓" : text,
          svgSrc: svgSrc,
          isShowDivider: isShowDivider,
          press: () => setState(() => _selected = index),
        ),
        Padding(
          padding: const EdgeInsets.only(
              left: defaultPadding + 36, bottom: defaultPadding / 2),
          child: Text(subtitle,
              style:
                  const TextStyle(color: blackColor60, fontSize: 12)),
        ),
      ],
    );
  }
}
