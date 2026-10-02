import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/route/router.dart';
import 'package:shop/screens/address/views/address_map_picker_screen.dart';
import 'package:shop/services/location_service.dart';

/// Fake geolocator: scripted fix / failure, zero platform I/O.
class FakeGeolocator implements GeolocatorWrapper {
  Position? position;
  Object? positionError;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    if (positionError != null) throw positionError!;
    return position ??
        Position(
          latitude: 23.2599,
          longitude: 77.4126,
          timestamp: DateTime.utc(2026, 10, 2),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1,
        );
  }

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

/// Fake geocoder: scripted placemarks, records pin-drop coords, zero I/O.
class FakeGeocoding implements GeocodingWrapper {
  List<Placemark> placemarks = const [
    Placemark(
      street: '12 MG Road',
      subLocality: 'Arera Colony',
      locality: 'Bhopal',
      postalCode: '462016',
    ),
  ];
  Object? error;
  double? lastLat;
  double? lastLng;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    lastLat = latitude;
    lastLng = longitude;
    if (error != null) throw error!;
    return placemarks;
  }
}

/// Fake map: no tiles, no GPS. "nudge" simulates dragging the map so the
/// center pin reads new coords — the screen's confirm flow is fully real.
Widget fakeMap(
  BuildContext context,
  MapController controller,
  LatLng center,
  ValueChanged<LatLng> onCenterChanged,
) {
  return Column(
    children: [
      Text('fake-map ${center.latitude},${center.longitude}'),
      TextButton(
        onPressed: () => onCenterChanged(const LatLng(24.0, 78.0)),
        child: const Text('nudge'),
      ),
    ],
  );
}

void main() {
  Map<String, dynamic>? picked;

  Future<void> openPicker(
    WidgetTester tester,
    FakeGeolocator geo,
    FakeGeocoding coding, {
    GeocodingWrapper? confirmCoding,
  }) async {
    picked = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                picked = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddressMapPickerScreen(
                      locationService: LocationService(
                        geolocator: geo,
                        geocoding: coding,
                      ),
                      geocoding: confirmCoding ?? coding,
                      mapBuilder: fakeMap,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('locate fix shows map with resolved label + confirm',
      (tester) async {
    await openPicker(tester, FakeGeolocator(), FakeGeocoding());

    expect(find.text('Finding your location'), findsNothing);
    expect(find.text('fake-map 23.2599,77.4126'), findsOneWidget);
    expect(
      find.text('12 MG Road, Arera Colony, Bhopal, 462016'),
      findsOneWidget,
    );
    expect(find.text('Confirm location'), findsOneWidget);
  });

  testWidgets('location failure shows error with retry that recovers',
      (tester) async {
    final geo = FakeGeolocator()
      ..positionError = const LocationError(LocationErrorType.denied);
    await openPicker(tester, geo, FakeGeocoding());

    expect(
      find.text(
        'Location permission was denied. '
        'Allow access to use your current location.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    geo.positionError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('fake-map 23.2599,77.4126'), findsOneWidget);
    expect(find.text('Confirm location'), findsOneWidget);
  });

  testWidgets('confirm reverse-geocodes center and pops the pick',
      (tester) async {
    final coding = FakeGeocoding();
    await openPicker(tester, FakeGeolocator(), coding);

    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(coding.lastLat, 23.2599);
    expect(coding.lastLng, 77.4126);
    expect(picked, isNotNull);
    expect(picked!['lat'], 23.2599);
    expect(picked!['lng'], 77.4126);
    expect(picked!['street'], '12 MG Road');
    expect(picked!['area'], 'Arera Colony');
    expect(picked!['city'], 'Bhopal');
    expect(picked!['pincode'], '462016');
    expect(
      picked!['label'],
      '12 MG Road, Arera Colony, Bhopal, 462016',
    );
  });

  testWidgets('moved pin confirms the new center coords', (tester) async {
    final coding = FakeGeocoding();
    await openPicker(tester, FakeGeolocator(), coding);

    await tester.tap(find.text('nudge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(coding.lastLat, 24.0);
    expect(coding.lastLng, 78.0);
    expect(picked!['lat'], 24.0);
    expect(picked!['lng'], 78.0);
  });

  testWidgets('confirm with failed geocode still pops coords-only',
      (tester) async {
    final confirmCoding = FakeGeocoding()..error = Exception('offline');
    await openPicker(
      tester,
      FakeGeolocator(),
      FakeGeocoding(),
      confirmCoding: confirmCoding,
    );

    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!['lat'], 23.2599);
    expect(picked!['lng'], 77.4126);
    expect(picked!['street'], isNull);
    expect(picked!['city'], isNull);
    expect(picked!['label'], contains('23.25990'));
  });

  test('address_map_picker route is registered (no pump, no I/O)', () {
    final route =
        generateRoute(const RouteSettings(name: addressMapPickerScreenRoute));
    expect(route, isA<MaterialPageRoute>());
  });

  test('OSM tile template is the standard public URL', () {
    expect(
      AddressMapPickerScreen.osmUrlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
  });
}
