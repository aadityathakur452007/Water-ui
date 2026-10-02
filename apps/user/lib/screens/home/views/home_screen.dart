import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';
import 'package:shop/services/location_service.dart';

import 'components/active_delivery.dart';
import 'components/categories.dart';
import 'components/delivery_address_header.dart';
import 'components/order_again.dart';
import 'components/water_products.dart';

/// Home feed. Stateful only to own the current-location flow:
/// Use-current-location → permission flow → reverse-geocode → prefill
/// callback ([onLocationResolved]) + header display (label + lat/lng
/// text, no map widget). Address persistence belongs to Agent B.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onLocationResolved, this.locationService});

  /// Prefill hook for the address sheet (Agent B consumes lat/lng + label).
  final ValueChanged<ResolvedLocation>? onLocationResolved;

  /// Injectable for widget tests (defaults to the real service).
  final LocationService? locationService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locating = false;
  String? _locationError;
  bool _needsSettings = false;
  ResolvedLocation? _resolved;

  LocationService get _service => widget.locationService ?? LocationService();

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      _needsSettings = false;
    });
    try {
      final resolved = await _service.resolveCurrentAddress();
      if (!mounted) return;
      setState(() => _resolved = resolved);
      widget.onLocationResolved?.call(resolved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location found: ${resolved.displayLabel}')),
      );
    } on LocationError catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.userMessage;
        // Spec: only deniedForever routes to app Settings; every other
        // branch (incl. service-disabled, which already opened location
        // settings) offers a plain retry.
        _needsSettings = e.type == LocationErrorType.deniedForever;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError =
            const LocationError(LocationErrorType.unavailable).userMessage;
        _needsSettings = false;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openSettings() async {
    try {
      await _service.openAppSettings();
    } catch (_) {
      // Settings opener unavailable — the error row with Retry remains.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: DeliveryAddressHeader(
                locatedLabel: _resolved?.displayLabel,
                locatedLatLng: _resolved?.latLngText,
                isLocating: _locating,
                locationError: _locationError,
                showSettingsAction: _needsSettings,
                onUseCurrentLocation: _useCurrentLocation,
                onRetryLocation: _useCurrentLocation,
                onOpenSettings: _openSettings,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding, vertical: defaultPadding / 2),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, searchScreenRoute),
                  child: const AbsorbPointer(
                    child: SearchForm(isEnabled: false),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Text(
                  "Get water delivered to your doorstep",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Categories()),
            const SliverToBoxAdapter(child: WaterProducts()),
            const SliverToBoxAdapter(child: OrderAgain()),
            const SliverToBoxAdapter(child: ActiveDelivery()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: _WaterPromoBanner(
                  press: () => Navigator.pushNamed(
                      context, discoverScreenRoute),
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: defaultPadding)),
          ],
        ),
      ),
    );
  }
}

/// One small informational banner — never dominates the screen.
class _WaterPromoBanner extends StatelessWidget {
  const _WaterPromoBanner({required this.press});

  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: const BoxDecoration(
          color: primaryColor,
          borderRadius:
              BorderRadius.all(Radius.circular(defaultBorderRadious)),
        ),
        child: Row(
          children: [
            const Icon(Icons.water_drop, color: Colors.white, size: 28),
            const SizedBox(width: defaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Free delivery on 20L jars",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Order 2 or more jars · Bhopal",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
