import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';

import 'components/wallet_balance_card.dart';
import 'components/wallet_history_card.dart';
import 'empty_wallet_screen.dart';

/// Wallet. There is no wallet endpoint in the backend contract, so the
/// history below is local seed data — when it is empty the dedicated
/// [EmptyWalletScreen] shows instead of a blank list.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const _balance = 384.90;

  static List<Map<String, Object>> _history() => [
        {
          'isReturn': false,
          'date': "JUN 12, 2020",
          'amount': 129.0,
          'products': [demoPopularProducts[0], demoPopularProducts[2]],
        },
        {
          'isReturn': true,
          'date': "JUN 10, 2020",
          'amount': 60.0,
          'products': [demoPopularProducts[0]],
        },
        {
          'isReturn': false,
          'date': "JUN 5, 2020",
          'amount': 129.0,
          'products': [demoPopularProducts[0], demoPopularProducts[2]],
        },
        {
          'isReturn': false,
          'date': "JUN 1, 2020",
          'amount': 90.0,
          'products': [demoPopularProducts[4]],
        },
      ];

  @override
  Widget build(BuildContext context) {
    final history = _history();
    if (history.isEmpty) return const EmptyWalletScreen();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: defaultPadding),
                sliver: SliverToBoxAdapter(
                  child: WalletBalanceCard(
                    balance: _balance,
                    onTabChargeBalance: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Top-ups are not available yet. Pay cash or UPI on delivery."),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: defaultPadding / 2),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    "Wallet history",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = history[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: defaultPadding),
                      child: WalletHistoryCard(
                        isReturn: entry['isReturn'] as bool,
                        date: entry['date'] as String,
                        amount: entry['amount'] as double,
                        products: entry['products'] as List,
                      ),
                    );
                  },
                  childCount: history.length,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
