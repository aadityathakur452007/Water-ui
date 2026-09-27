import 'package:flutter/material.dart';
import 'package:shop/constants.dart';

/// Help & Support: static in-app FAQ + contact entries. There is no
/// support backend, so everything here is bundled copy — nothing is
/// fetched and nothing leaves the device.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      q: "How do one-time orders work?",
      a: "Pick a product, choose One Time, confirm your address and place "
          "the order. One-time orders arrive in the selected slot "
          "(Today • 8:00 AM) and you pay on delivery.",
    ),
    (
      q: "How do regular deliveries work?",
      a: "Choose Regular, pick a schedule (Every Day, Alternate Days, "
          "Specific Days or Once a Week) with a start date and delivery "
          "time, then place the order. Manage pause, resume and Skip Next "
          "anytime in My Regular Deliveries.",
    ),
    (
      q: "What does delivery cost?",
      a: "Delivery fee is ₹10 per order, shown in the checkout total "
          "before you place the order.",
    ),
    (
      q: "How do I pay?",
      a: "Cash on Delivery or UPI — both are paid on delivery. Choose in "
          "checkout or anytime in Payment Methods.",
    ),
    (
      q: "How do I change my delivery address?",
      a: "Open Addresses from your Account tab to add a new address. "
          "In checkout you can pick any saved address per order.",
    ),
    (
      q: "Do I get order updates?",
      a: "Yes — order confirmations and status changes appear under "
          "Notifications (bell icon). Toggle each category in "
          "Notification Options.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          Text(
            "Frequently asked questions",
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final faq in _faqs)
            Container(
              margin:
                  const EdgeInsets.only(bottom: defaultPadding / 2),
              decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).dividerColor),
                borderRadius: const BorderRadius.all(
                    Radius.circular(defaultBorderRadious)),
              ),
              child: ExpansionTile(
                title: Text(
                  faq.q,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        defaultPadding, 0, defaultPadding, defaultPadding),
                    child: Text(
                      faq.a,
                      style:
                          Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: defaultPadding),
          Text(
            "Contact support",
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FC),
              borderRadius: BorderRadius.all(
                  Radius.circular(defaultBorderRadious)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _contactRow(context, Icons.call_outlined,
                    "1800-419-0000 (toll-free, 8 AM – 8 PM IST)"),
                const SizedBox(height: 8),
                _contactRow(context, Icons.mail_outlined,
                    "support@demo.local"),
                const SizedBox(height: 8),
                Text(
                  "Demo build: support details are static and replies "
                  "are illustrative — no message leaves this device.",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(fontSize: 12, color: blackColor60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: defaultPadding / 2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
