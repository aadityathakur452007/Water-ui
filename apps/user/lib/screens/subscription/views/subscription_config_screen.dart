import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';

/// Ordered Mon–Sun options for the "Specific Days" picker. Order matters:
/// [daysWireString] emits in this order regardless of tap order.
const weekDayOptions = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Wire value for the custom-days picker: comma string "Mon,Wed,Fri",
/// empty for every other frequency (contract: backend `days` key).
String daysWireString(Frequency frequency, Iterable<String> days) {
  if (frequency != Frequency.specificDays) return '';
  return weekDayOptions.where(days.contains).join(',');
}

String _specificDaysLabel(Iterable<String> days) {
  final wire = daysWireString(Frequency.specificDays, days);
  if (wire.isEmpty) return 'Specific days';
  return 'Every ${wire.replaceAll(',', ', ')}';
}

/// Live summary line, e.g. "Every Mon, Wed, Fri · from 12 Jun · 8:00 AM".
String scheduleSummary({
  required Frequency frequency,
  required Iterable<String> days,
  required String startLabel,
  required String timeLabel,
}) {
  final String freqPart = switch (frequency) {
    Frequency.everyDay => 'Every day',
    Frequency.alternateDays => 'Alternate days',
    Frequency.specificDays => _specificDaysLabel(days),
    Frequency.weekly || Frequency.onceAWeek => 'Once a week',
  };
  return '$freqPart · from $startLabel · $timeLabel';
}

const _months = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
];

const _shortMonths = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

String _dateLabel(DateTime d) => "${d.day} ${_months[d.month - 1]} ${d.year}";

String _shortDateLabel(DateTime d) => "${d.day} ${_shortMonths[d.month - 1]}";

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
  final _days = <String>{};
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

  bool get _daysValid =>
      _frequency != Frequency.specificDays || _days.isNotEmpty;

  void _continue() {
    if (!_daysValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pick at least one day for Specific Days."),
        ),
      );
      return;
    }
    Navigator.pushNamed(context, cartScreenRoute, arguments: {
      'productId': product.id,
      'qty': widget.qty,
      'orderType': 'regular',
      'frequency': frequencyToWire(_frequency),
      'startDate': _dateLabel(_start),
      'deliveryTime': _time.format(context),
      'days': daysWireString(_frequency, _days),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Regular Delivery")),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: ElevatedButton(
            onPressed: _continue,
            child: const Text("Continue"),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FC),
              borderRadius: BorderRadius.all(
                  Radius.circular(defaultBorderRadious)),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop,
                    color: primaryColor, size: 28),
                const SizedBox(width: defaultPadding / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your schedule",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scheduleSummary(
                          frequency: _frequency,
                          days: _days,
                          startLabel: _shortDateLabel(_start),
                          timeLabel: _time.format(context),
                        ),
                        style: const TextStyle(
                            color: blackColor60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultPadding),
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
          if (_frequency == Frequency.specificDays) ...[
            const SizedBox(height: defaultPadding / 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in weekDayOptions)
                  FilterChip(
                    label: Text(d),
                    selected: _days.contains(d),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _days.add(d);
                      } else {
                        _days.remove(d);
                      }
                    }),
                  ),
              ],
            ),
            if (_days.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Pick at least one day.",
                  style: TextStyle(color: errorColor, fontSize: 12),
                ),
              ),
          ],
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
