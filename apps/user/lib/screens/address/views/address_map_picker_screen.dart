import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shop/constants.dart';
import 'package:shop/services/location_service.dart';

/// Popped result keys (all numbers are real coords, strings are geocoded
/// parts — null when reverse-geocode found nothing; the sheet keeps any
/// manually typed text in that case).
const String kMapPickLat = 'lat';
const String kMapPickLng = 'lng';

/// Builds the map body. The default renders the real OSM [FlutterMap];
/// tests inject a fake (no network/GPS). [onCenterChanged] fires for every
/// camera move — confirm reads the last reported center.
typedef AddressMapBuilder = Widget Function(
  BuildContext context,
  MapController controller,
  LatLng center,
  ValueChanged<LatLng> onCenterChanged,
);

/// Full-screen OSM map picker (KEYLESS: flutter_map, no billing, no key).
///
/// Fixed center pin + move map (no marker-drag controller APIs): confirm
/// reads the map center, reverse-geocodes it via [GeocodingWrapper], and
/// pops `{lat, lng, label, street, area, city, pincode}` for the address
/// sheet to prefill. Tile failures show an honest chip but never trap —
/// confirm always stays available.
class AddressMapPickerScreen extends StatefulWidget {
  const AddressMapPickerScreen({
    super.key,
    LocationService? locationService,
    GeocodingWrapper? geocoding,
    AddressMapBuilder? mapBuilder,
  })  : _locationService = locationService,
        _geocoding = geocoding,
        _mapBuilder = mapBuilder;

  final LocationService? _locationService;
  final GeocodingWrapper? _geocoding;
  final AddressMapBuilder? _mapBuilder;

  @visibleForTesting
  static const osmUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  State<AddressMapPickerScreen> createState() => _AddressMapPickerScreenState();
}

class _AddressMapPickerScreenState extends State<AddressMapPickerScreen> {
  static const double _zoom = 15;
  static const LatLng _fallbackCenter = LatLng(23.2599, 77.4126);

  late final LocationService _location =
      widget._locationService ?? LocationService();
  late final GeocodingWrapper _geocoding =
      widget._geocoding ?? DefaultGeocodingWrapper();
  late final MapController _controller = MapController();

  bool _locating = true;
  bool _confirming = false;
  bool _tilesFailed = false;
  String? _error;
  LatLng? _center;
  String? _label;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final fix = await _location.resolveCurrentAddress();
      if (!mounted) return;
      setState(() {
        _locating = false;
        _center = LatLng(fix.latitude, fix.longitude);
        _label = fix.displayLabel;
      });
    } on LocationError catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = 'Could not get your location. Please try again.';
      });
    }
  }

  void _onTileError() {
    if (_tilesFailed || !mounted) return;
    setState(() => _tilesFailed = true);
  }

  /// Confirm reads the map center, reverse-geocodes it, and pops the pick.
  /// Geocode failure still pops coords-only (label falls back to lat,lng)
  /// so the sheet's manual fields can take over — never a dead end.
  Future<void> _confirm() async {
    final center = _center;
    if (center == null || _confirming) return;
    setState(() => _confirming = true);
    String? street;
    String? area;
    String? city;
    String? pincode;
    try {
      final marks = await _geocoding.placemarkFromCoordinates(
        center.latitude,
        center.longitude,
      );
      if (marks.isNotEmpty) {
        final p = marks.first;
        String? clean(String? v) {
          final s = v?.trim();
          return (s == null || s.isEmpty) ? null : s;
        }

        street = clean(p.street) ?? clean(p.name);
        area = clean(p.subLocality) ?? clean(p.locality);
        city = clean(p.locality) ?? clean(p.subAdministrativeArea);
        pincode = clean(p.postalCode);
      }
    } catch (_) {
      // Coords-only fallback below (offline / quota-safe, per States.md).
    }
    if (!mounted) return;
    final parts = [
      if (street != null) street,
      if (area != null && area != street) area,
      if (city != null && city != area) city,
      if (pincode != null) pincode,
    ];
    Navigator.pop(context, <String, dynamic>{
      kMapPickLat: center.latitude,
      kMapPickLng: center.longitude,
      'label': parts.isEmpty
          ? '${center.latitude.toStringAsFixed(5)}, '
              '${center.longitude.toStringAsFixed(5)}'
          : parts.join(', '),
      'street': street,
      'area': area,
      'city': city,
      'pincode': pincode,
    });
  }

  Widget _buildMap(BuildContext context, LatLng center) {
    final builder = widget._mapBuilder ?? _defaultMap;
    return builder(
      context,
      _controller,
      center,
      (moved) => setState(() => _center = moved),
    );
  }

  Widget _defaultMap(
    BuildContext context,
    MapController controller,
    LatLng center,
    ValueChanged<LatLng> onCenterChanged,
  ) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _zoom,
        onPositionChanged: (camera, _) => onCenterChanged(camera.center),
      ),
      children: [
        TileLayer(
          urlTemplate: AddressMapPickerScreen.osmUrlTemplate,
          // OSM tile policy: identify the app (package `shop`).
          userAgentPackageName: 'shop',
          maxNativeZoom: 19,
          errorTileCallback: (tile, error, stackTrace) => _onTileError(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick location')),
      body: _locating
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: defaultPadding / 2),
                  Text('Finding your location'),
                ],
              ),
            )
          : center == null
              ? _errorBody(context)
              : Stack(
                  children: [
                    _buildMap(context, center),
                    // Fixed center pin: move the map under it.
                    const IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.location_pin,
                              size: 44, color: Colors.red),
                        ),
                      ),
                    ),
                    if (_tilesFailed)
                      const Positioned(
                        top: 8,
                        left: 12,
                        right: 12,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Text(
                              'Map tiles unavailable — move the pin area '
                              'anyway, or confirm to enter details manually.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    if (_label != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Text(_label!, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    const Positioned(
                      right: 8,
                      bottom: 64,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: center == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: ElevatedButton(
                  onPressed: _confirming ? null : _confirm,
                  child: _confirming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm location'),
                ),
              ),
            ),
    );
  }

  Widget _errorBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Could not get your location.',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again, or pick manually.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: defaultPadding),
            ElevatedButton(
              onPressed: _locate,
              child: const Text('Retry'),
            ),
            const SizedBox(height: defaultPadding / 2),
            OutlinedButton(
              onPressed: () => setState(() {
                _center = _fallbackCenter;
                _label = 'Move the map to your address';
              }),
              child: const Text('Pick manually'),
            ),
          ],
        ),
      ),
    );
  }
}
