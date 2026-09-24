import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/skleton/skelton.dart';
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

/// Water-blue tokens scoped ONLY to the library stat/progress widgets.
UiThemeData _waterUiTheme() {
  final base = MinimalTheme.light;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: primaryColor,
      success: successColor,
      error: errorColor,
    ),
    useGlow: false,
    useGradients: false,
    useShadows: false,
  );
}

/// My Regular Deliveries: progress summary + per-subscription
/// pause / skip / modify. Local data over the repository
/// (no user-facing subscription endpoint in the frozen contract).
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _repo = const SubscriptionRepository();
  List<Subscription>? _subs;
  Future<List<Subscription>>? _future;
  final Set<String> _skipped = {};

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _repo.septemberProgress();
    return Scaffold(
      appBar: AppBar(title: const Text("My Regular Deliveries")),
      body: FutureBuilder<List<Subscription>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              _subs == null) {
            return ListView(
              padding: const EdgeInsets.all(defaultPadding),
              children: const [
                Skeleton(height: 140),
                SizedBox(height: defaultPadding),
                Skeleton(height: 160),
              ],
            );
          }
          if (snap.hasError && _subs == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding * 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Could not load deliveries.",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Check your connection and try again.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: defaultPadding),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => setState(
                          () => _future = _repo.fetchSubscriptions()),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.hasData && _subs == null) {
            _subs = List<Subscription>.from(snap.data!);
          }
          final subs = _subs ?? const <Subscription>[];
          return ListView(
            padding: const EdgeInsets.all(defaultPadding),
            children: [
              _ProgressCard(progress: progress),
              const SizedBox(height: defaultPadding),
              if (subs.isEmpty)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(defaultPadding * 2),
                  child: Text("No regular deliveries yet"),
                )),
              ...subs.map(_subCard),
            ],
          );
        },
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
                  final i = _subs!.indexOf(sub);
                  _subs![i] = sub.copyWith(
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
                      final i = _subs!.indexOf(sub);
                      _subs![i] =
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
    final done = progress.total == 0
        ? 0.0
        : progress.delivered / progress.total;
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
          // Library stat + progress displays (water-blue tokens above).
          UiTheme(
            data: _waterUiTheme(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    UiStat(
                        label: "Delivered",
                        value: "${progress.delivered}"),
                    UiStat(
                        label: "Scheduled",
                        value: "${progress.scheduled}"),
                    UiStat(
                        label: "Skipped", value: "${progress.skipped}"),
                  ],
                ),
                const SizedBox(height: 8),
                UiProgressBar(value: done, showLabel: true),
              ],
            ),
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
}
