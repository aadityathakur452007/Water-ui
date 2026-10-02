import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 is flutter_map's own coordinate type (not re-exported by
// flutter_map 8.x). The picker agent owns pubspec.yaml — promoting
// latlong2 to a direct dep there lets the trailing ignore go away.
import 'package:latlong2/latlong.dart';
import 'package:shop/components/app_state_views.dart';
import 'package:shop/components/order_process.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart' show inr;
import 'package:shop/models/order_model.dart';

/// Slice 3 order tracking (KEYLESS revision): flutter_map + OpenStreetMap
/// tiles — no API key, no billing. Static customer pin + reused
/// [OrderProgress] timeline; no fake courier polyline.
///
/// States.md: the order arrives via constructor (no async gap, so no
/// app-level loading state); null lat/lng → honest empty (never a 0,0
/// pin); tile failures → error chip with retry.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _tileFailed = false;
  int _tileBust = 0;

  bool get _hasCoords =>
      widget.order.address.lat != null && widget.order.address.lng != null;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Track order #${order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          _HeaderCard(order: order),
          const SizedBox(height: defaultPadding),
          if (_hasCoords)
            _MapCard(
              lat: order.address.lat!,
              lng: order.address.lng!,
              addressLine:
                  '${order.address.displayLine}, ${order.address.city}',
              tileFailed: _tileFailed,
              tileBust: _tileBust,
              onTileError: () {
                if (!_tileFailed && mounted) {
                  setState(() => _tileFailed = true);
                }
              },
              onRetry: () => setState(() {
                _tileFailed = false;
                _tileBust++;
              }),
            )
          else
            const AppEmptyView(
              title: 'No location saved for this order',
              guidance:
                  'This order was placed before location saving. '
                  'Your delivery still goes to the address above.',
              icon: Icons.location_off_outlined,
            ),
          const SizedBox(height: defaultPadding),
          _TimelineCard(status: order.status),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.displayLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              order.itemsSummary,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 2),
            Text(
              '${inr(order.totalAmount)} · ${order.deliverySlot}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${order.address.label}: '
              '${order.address.displayLine}, ${order.address.city}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.lat,
    required this.lng,
    required this.addressLine,
    required this.tileFailed,
    required this.tileBust,
    required this.onTileError,
    required this.onRetry,
  });

  final double lat;
  final double lng;
  final String addressLine;
  final bool tileFailed;
  final int tileBust;
  final VoidCallback onTileError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      // Key bump forces a refetch on manual retry.
                      key: ValueKey('osm-$tileBust'),
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // OSM tile policy requires identifying the app.
                      userAgentPackageName: 'com.waterdelivery.app',
                      errorTileCallback: (tile, error, stackTrace) =>
                          onTileError(),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: primaryColor,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: _AttributionChip(),
                ),
              ],
            ),
          ),
          if (tileFailed)
            _TileErrorChip(onRetry: onRetry),
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Text(
              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} · '
              '$addressLine',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributionChip extends StatelessWidget {
  const _AttributionChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 10, color: Colors.black87),
      ),
    );
  }
}

class _TileErrorChip extends StatelessWidget {
  const _TileErrorChip({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDECEC),
      padding: const EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: 8,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Map tiles failed to load. Check your connection.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: errorColor),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery status',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: defaultPadding),
            orderTrackingProgress(status),
          ],
        ),
      ),
    );
  }
}

/// Pure state-machine mapping: user [OrderStatus] → the reused
/// [OrderProgress] steps. Cancelled/not-delivered take the timeline's
/// dedicated canceled branch.
OrderProgress orderTrackingProgress(OrderStatus status) {
  const done = OrderProcessStatus.done;
  const busy = OrderProcessStatus.processing;
  const todo = OrderProcessStatus.notDoneYeat;
  switch (status) {
    case OrderStatus.delivered:
      return const OrderProgress(
        orderStatus: done,
        processingStatus: done,
        packedStatus: done,
        shippedStatus: done,
        deliveredStatus: done,
      );
    case OrderStatus.outForDelivery:
    case OrderStatus.active:
      return const OrderProgress(
        orderStatus: done,
        processingStatus: done,
        packedStatus: done,
        shippedStatus: busy,
        deliveredStatus: todo,
      );
    case OrderStatus.preparing:
      return const OrderProgress(
        orderStatus: done,
        processingStatus: done,
        packedStatus: busy,
        shippedStatus: todo,
        deliveredStatus: todo,
      );
    case OrderStatus.cancelled:
    case OrderStatus.notDelivered:
      return const OrderProgress(
        orderStatus: done,
        processingStatus: done,
        packedStatus: done,
        shippedStatus: done,
        deliveredStatus: todo,
        isCanceled: true,
      );
    case OrderStatus.scheduled:
      return const OrderProgress(
        orderStatus: done,
        processingStatus: busy,
        packedStatus: todo,
        shippedStatus: todo,
        deliveredStatus: todo,
      );
  }
}
