import 'package:flutter/material.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/repositories/subscription_repository.dart';
import 'package:shop/screens/product/views/components/product_quantity.dart';

const _freqLabels = {
  Frequency.everyDay: "Every Day",
  Frequency.alternateDays: "Alternate Days",
  Frequency.specificDays: "Specific Days",
  Frequency.weekly: "Once a Week",
};

/// My Regular Deliveries: progress summary + per-subscription
/// pause / skip / modify. Local state over mock repository data
/// (backend owns this once integrated).
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _repo = const SubscriptionRepository();
  final List<Subscription> _subs =
      const SubscriptionRepository().subscriptions();
  final Set<String> _skipped = {};

  @override
  Widget build(BuildContext context) {
    final progress = _repo.septemberProgress();
    return Scaffold(
      appBar: AppBar(title: const Text("My Regular Deliveries")),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          _ProgressCard(progress: progress),
          const SizedBox(height: defaultPadding),
          if (_subs.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(defaultPadding * 2),
              child: Text("No regular deliveries yet"),
            )),
          ..._subs.map(_subCard),
        ],
      ),
    );
  }

  Widget _subCard(Subscription sub) {
    final bool paused = sub.status == SubscriptionStatus.paused;
    final bool skipped = _skipped.contains(sub.id);
    return Container(
      margin: const EdgeInsets.only(bottom: defaultPadding),
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius:
            const BorderRadius.all(Radius.circular(defaultBorderRadious)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(sub.productName,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              _StatusChip(
                  label: paused
                      ? "Paused"
                      : skipped
                          ? "Next skipped"
                          : "Active",
                  ok: !paused),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${sub.quantity} ${sub.quantity == 1 ? 'jar' : 'jars'} / delivery\n${sub.frequencyLabel} · ${sub.deliveryTime}\nNext: ${skipped ? 'after next' : sub.nextDelivery}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _openModify(sub),
                child: const Text("Modify"),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  final i = _subs.indexOf(sub);
                  _subs[i] = sub.copyWith(
                    status: paused
                        ? SubscriptionStatus.active
                        : SubscriptionStatus.paused,
                  );
                }),
                child: Text(paused ? "Resume" : "Pause"),
              ),
              if (!paused)
                TextButton(
                  onPressed: () => setState(() {
                    skipped
                        ? _skipped.remove(sub.id)
                        : _skipped.add(sub.id);
                  }),
                  child: Text(skipped ? "Unskip" : "Skip Next"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openModify(Subscription sub) {
    int qty = sub.quantity;
    Frequency freq = sub.frequency;
    customModalBottomSheet(
      context,
      child: StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(defaultPadding * 1.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Modify delivery",
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: defaultPadding),
              ProductQuantity(
                numOfItem: qty,
                onIncrement: () => setSheet(() => qty++),
                onDecrement: () =>
                    setSheet(() => qty = qty > 1 ? qty - 1 : 1),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Frequency>(
                initialValue: freq,
                decoration: const InputDecoration(labelText: "Frequency"),
                items: Frequency.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(_freqLabels[f]!),
                        ))
                    .toList(),
                onChanged: (v) => setSheet(() => freq = v ?? freq),
              ),
              const SizedBox(height: defaultPadding),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      final i = _subs.indexOf(sub);
                      _subs[i] =
                          sub.copyWith(quantity: qty, frequency: freq);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding / 2, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFEAF4FC) : blackColor5,
        borderRadius:
            const BorderRadius.all(Radius.circular(defaultBorderRadious)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ok ? primaryColor : blackColor60)),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final DeliveryProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4FC),
        borderRadius:
            BorderRadius.all(Radius.circular(defaultBorderRadious)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("September Delivery",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(context, "Delivered", "${progress.delivered}"),
              _stat(context, "Scheduled", "${progress.scheduled}"),
              _stat(context, "Skipped", "${progress.skipped}"),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Total deliveries: ${progress.total} · Amount paid: ${inr(progress.amountPaid)}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
