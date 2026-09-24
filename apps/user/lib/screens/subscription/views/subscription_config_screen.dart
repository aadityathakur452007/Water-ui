import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';

const _months = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
];

String _dateLabel(DateTime d) => "${d.day} ${_months[d.month - 1]} ${d.year}";

/// Compact regular-delivery setup. Reached from order-type with
/// `{productId, qty}`; Continue lands on checkout preselected to regular.
class SubscriptionConfigScreen extends StatefulWidget {
  const SubscriptionConfigScreen(
      {super.key, required this.productId, this.qty = 1});

  final String productId;
  final int qty;

  @override
  State<SubscriptionConfigScreen> createState() =>
      _SubscriptionConfigScreenState();
}

class _SubscriptionConfigScreenState extends State<SubscriptionConfigScreen> {
  Frequency _frequency = Frequency.everyDay;
  late DateTime _start =
      DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  late final ProductModel product =
      const ProductRepository().byId(widget.productId);

  static const _options = [
    (Frequency.everyDay, "Every Day"),
    (Frequency.alternateDays, "Alternate Days"),
    (Frequency.specificDays, "Specific Days"),
    (Frequency.weekly, "Once a Week"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Regular Delivery")),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, cartScreenRoute, arguments: {
                'productId': product.id,
                'qty': widget.qty,
                'orderType': 'regular',
              });
            },
            child: const Text("Continue"),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          Text(
            "${widget.qty} × ${product.title}",
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            "${inr(product.price * widget.qty)} / delivery",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: defaultPadding),
          RadioGroup<Frequency>(
            groupValue: _frequency,
            onChanged: (v) => setState(() => _frequency = v!),
            child: Column(
              children: _options
                  .map((o) => RadioListTile<Frequency>(
                        value: o.$1,
                        title: Text(o.$2),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: defaultPadding * 2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Start Date"),
            subtitle: Text(_dateLabel(_start)),
            trailing: const Icon(Icons.calendar_today, size: 20),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _start = picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Delivery Time"),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.access_time, size: 20),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null) setState(() => _time = picked);
            },
          ),
        ],
      ),
    );
  }
}
