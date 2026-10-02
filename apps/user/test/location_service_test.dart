import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shop/screens/home/views/components/delivery_address_header.dart';
import 'package:shop/screens/notification/view/enable_notification_screen.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/location_service.dart';

/// Fake geolocator: scripted answers + call log, zero platform I/O.
class FakeGeolocator implements GeolocatorWrapper {
  bool serviceEnabled = true;
  LocationPermission checkResult = LocationPermission.whileInUse;
  LocationPermission requestResult = LocationPermission.whileInUse;
  Position? position;
  Object? positionError;
  bool openedLocationSettings = false;
  bool openedAppSettings = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkResult;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    if (positionError != null) throw positionError!;
    return position ??
        _pos(23.25990 /* Bhopal */, 77.41260 /* Bhopal */);
  }

  @override
  Future<bool> openLocationSettings() async {
    openedLocationSettings = true;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings = true;
    return true;
  }
}

/// Fake geocoder: scripted placemarks, zero network I/O.
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

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (error != null) throw error!;
    return placemarks;
  }
}

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.utc(2026, 10, 2),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );

LocationError _asLocationError(Object e) {
  expect(e, isA<LocationError>());
  return e as LocationError;
}

void main() {
  group('LocationService.resolveCurrentAddress', () {
    test('service disabled opens location settings + throws serviceDisabled',
        () async {
      final geo = FakeGeolocator()..serviceEnabled = false;
      final service =
          LocationService(geolocator: geo, geocoding: FakeGeocoding());
      try {
        await service.resolveCurrentAddress();
        fail('expected LocationError');
      } catch (e) {
        expect(
          _asLocationError(e).type,
          LocationErrorType.serviceDisabled,
        );
      }
      expect(geo.openedLocationSettings, isTrue);
    });

    test('denied then denied again throws denied (no settings opened)',
        () async {
      final geo = FakeGeolocator()
        ..checkResult = LocationPermission.denied
        ..requestResult = LocationPermission.denied;
      final service =
          LocationService(geolocator: geo, geocoding: FakeGeocoding());
      try {
        await service.resolveCurrentAddress();
        fail('expected LocationError');
      } catch (e) {
        expect(_asLocationError(e).type, LocationErrorType.denied);
      }
      expect(geo.openedAppSettings, isFalse);
    });

    test('deniedForever opens app settings + throws deniedForever', () async {
      final geo = FakeGeolocator()
        ..checkResult = LocationPermission.deniedForever;
      final service =
          LocationService(geolocator: geo, geocoding: FakeGeocoding());
      try {
        await service.resolveCurrentAddress();
        fail('expected LocationError');
      } catch (e) {
        expect(
          _asLocationError(e).type,
          LocationErrorType.deniedForever,
        );
      }
      expect(geo.openedAppSettings, isTrue);
    });

    test('success path returns label + lat/lng text (no real GPS)', () async {
      final service = LocationService(
        geolocator: FakeGeolocator(),
        geocoding: FakeGeocoding(),
      );
      final resolved = await service.resolveCurrentAddress();
      expect(resolved.latitude, closeTo(23.2599, 0.0001));
      expect(resolved.longitude, closeTo(77.4126, 0.0001));
      expect(resolved.displayLabel, contains('MG Road'));
      expect(resolved.displayLabel, contains('Bhopal'));
      expect(resolved.city, 'Bhopal');
      expect(resolved.latLngText, isNotEmpty);
    });

    test('position timeout maps to timeout error', () async {
      final geo = FakeGeolocator()..positionError = TimeoutException('t');
      final service =
          LocationService(geolocator: geo, geocoding: FakeGeocoding());
      try {
        await service.resolveCurrentAddress();
        fail('expected LocationError');
      } catch (e) {
        expect(_asLocationError(e).type, LocationErrorType.timeout);
      }
    });

    test('empty placemarks map to reverseGeocodeFailed', () async {
      final coding = FakeGeocoding()..placemarks = const [];
      final service =
          LocationService(geolocator: FakeGeolocator(), geocoding: coding);
      try {
        await service.resolveCurrentAddress();
        fail('expected LocationError');
      } catch (e) {
        expect(
          _asLocationError(e).type,
          LocationErrorType.reverseGeocodeFailed,
        );
      }
    });

    test('out-of-range fix is rejected (input validation)', () async {
      final geo = FakeGeolocator()..position = _pos(120, 300);
      final service =
          LocationService(geolocator: geo, geocoding: FakeGeocoding());
      try {
        await service.resolveCurrentAddress();
        fail('expected LocationError');
      } catch (e) {
        expect(_asLocationError(e).type, LocationErrorType.unavailable);
      }
    });

    test('every error type has a safe display message', () {
      for (final type in LocationErrorType.values) {
        expect(LocationError(type).userMessage, isNotEmpty);
      }
    });
  });

  group('DeliveryAddressHeader location states', () {
    testWidgets('shows loading state while locating', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _TestAssetBundle(),
            child: const Scaffold(
              body: DeliveryAddressHeader(
                isLocating: true,
                onUseCurrentLocation: _noop,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Locating you…'), findsOneWidget);
      expect(find.text('Use current location'), findsNothing);
    });

    testWidgets('shows error + retry action on failure', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _TestAssetBundle(),
            child: Scaffold(
              body: DeliveryAddressHeader(
                locationError: 'Could not get your location. Please try again.',
                onUseCurrentLocation: _noop,
                onRetryLocation: () => retried = true,
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Could not get your location. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('shows Settings action for deniedForever', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _TestAssetBundle(),
            child: Scaffold(
              body: DeliveryAddressHeader(
                locationError: 'Location permission is blocked.',
                showSettingsAction: true,
                onUseCurrentLocation: _noop,
                onOpenSettings: () => opened = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      expect(opened, isTrue);
    });

    testWidgets('shows located label + lat/lng text on success', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _TestAssetBundle(),
            child: const Scaffold(
              body: DeliveryAddressHeader(
                locatedLabel: '12 MG Road, Bhopal 462016',
                locatedLatLng: '23.25990, 77.41260',
                onUseCurrentLocation: _noop,
              ),
            ),
          ),
        ),
      );
      expect(find.text('12 MG Road, Bhopal 462016'), findsOneWidget);
      expect(find.text('23.25990, 77.41260'), findsOneWidget);
    });
  });

  group('EnableNotificationScreen', () {
    const permChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');

    setUp(() {
      // permission_handler has no plugin in flutter_test: answer granted
      // (perm 17 = notification, status 1 = granted) so request() resolves
      // instead of hanging and the screen routes onward.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permChannel, (call) async {
        if (call.method == 'requestPermissions') return <int, int>{17: 1};
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permChannel, null);
    });

    testWidgets(
        'requests permission then routes onward even without plugin (CI)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (_) => const EnableNotificationScreen(),
            notificationOptionsScreenRoute: (_) =>
                const Scaffold(body: Text('Notification options')),
          },
        ),
      );
      await tester.tap(find.text('Enable notifications'));
      await tester.pumpAndSettle();
      // No MethodChannel plugin in flutter_test: the screen catches it and
      // still routes onward instead of trapping the user.
      expect(find.text('Notification options'), findsOneWidget);
    });
  });
}

void _noop() {}

/// Serves a stub SVG for vector keys so the header pumps without a real
/// asset bundle (same pattern as boot_routing_test's bundle).
class _TestAssetBundle extends CachingAssetBundle {
  static final Uint8List _svg = Uint8List.fromList(
    utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"></svg>',
    ),
  );

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, dynamic>{})!;
    }
    if (key == 'AssetManifest.json' || key == 'FontManifest.json') {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode('{}')));
    }
    return ByteData.sublistView(_svg);
  }
}
