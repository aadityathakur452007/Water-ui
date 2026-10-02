import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../constants.dart';
import '../../../../models/order_model.dart';
import '../../../../route/route_constants.dart';

/// "Delivering to" header. Address comes from the repository layer
/// (currently [defaultAddress]); tap opens the address book.
///
/// Agent A additions: an opt-in "Use current location" action with
/// loading / error / retry states (ui-checklist). On success the header
/// shows the reverse-geocoded label + lat/lng text only — deliberately
/// no map widget (google_maps_flutter is not a dependency). The actual
/// permission + GPS flow lives in [LocationService] and is owned by the
/// parent (HomeScreen); this widget only renders state and forwards taps.
class DeliveryAddressHeader extends StatelessWidget {
  const DeliveryAddressHeader({
    super.key,
    this.onChange,
    this.locatedLabel,
    this.locatedLatLng,
    this.isLocating = false,
    this.locationError,
    this.showSettingsAction = false,
    this.onUseCurrentLocation,
    this.onRetryLocation,
    this.onOpenSettings,
  });

  final VoidCallback? onChange;

  /// Reverse-geocoded display label from LocationService (null = none yet).
  final String? locatedLabel;

  /// "12.34567, 76.54321" text for the prefill sheet (null = none yet).
  final String? locatedLatLng;

  /// True while the GPS + reverse-geocode flow is running.
  final bool isLocating;

  /// Safe-to-display error message (null = no error).
  final String? locationError;

  /// True only for deniedForever (open Settings instead of plain retry).
  final bool showSettingsAction;

  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onRetryLocation;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          defaultPadding, defaultPadding, defaultPadding, defaultPadding / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                "assets/icons/Location.svg",
                height: 22,
                colorFilter:
                    const ColorFilter.mode(primaryColor, BlendMode.srcIn),
              ),
              const SizedBox(width: defaultPadding / 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivering to",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(fontSize: 12),
                    ),
                    Text(
                      "${defaultAddress.label} · ${defaultAddress.line}, ${defaultAddress.city}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChange ??
                    () => Navigator.pushNamed(context, addressesScreenRoute),
                child: const Text("Change"),
              ),
            ],
          ),
          if (locatedLabel != null && !isLocating) _LocatedRow(
            label: locatedLabel!,
            latLng: locatedLatLng,
          ),
          if (isLocating)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Locating you…",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (locationError != null && !isLocating)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationError!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: Colors.redAccent),
                    ),
                  ),
                  if (showSettingsAction)
                    TextButton(
                      style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44)),
                      onPressed: onOpenSettings,
                      child: const Text("Settings"),
                    )
                  else
                    TextButton(
                      style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44)),
                      onPressed: onRetryLocation,
                      child: const Text("Retry"),
                    ),
                ],
              ),
            ),
          if (onUseCurrentLocation != null && !isLocating)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44)),
                onPressed: onUseCurrentLocation,
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text("Use current location"),
              ),
            ),
        ],
      ),
    );
  }
}

/// Success row: reverse-geocoded label + raw lat/lng text (prefill aid).
class _LocatedRow extends StatelessWidget {
  const _LocatedRow({required this.label, this.latLng});

  final String label;
  final String? latLng;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (latLng != null)
                  Text(
                    latLng!,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
