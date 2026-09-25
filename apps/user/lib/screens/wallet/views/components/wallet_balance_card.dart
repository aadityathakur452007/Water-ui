import 'package:flutter/material.dart';

import '../../../../constants.dart';
import '../../../../models/cart_model.dart' show inr;

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.onTabChargeBalance,
  });

  final double balance;
  final VoidCallback onTabChargeBalance;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(defaultPadding),
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(defaultBorderRadious),
                  topRight: Radius.circular(defaultBorderRadious),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Your current balance",
                    style: TextStyle(
                        color: whileColor80,
                        fontWeight: FontWeight.w500,
                        fontSize: 12),
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  Text(
                    inr(balance),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: Colors.white),
                  )
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onTabChargeBalance,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(defaultBorderRadious),
                  bottomRight: Radius.circular(defaultBorderRadious),
                ),
              ),
            ),
            child: const Text("+ Charge Balance"),
          )
        ],
      ),
    );
  }
}
