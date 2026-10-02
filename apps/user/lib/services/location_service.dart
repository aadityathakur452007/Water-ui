import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Typed failure for the current-location flow.
///
/// The UI only ever sees [userMessage] (ssdlc: generic client errors —
/// no coordinates, platform details, or stack traces leak to the UI/logs).
enum LocationErrorType {
  serviceDisabled,
  denied,
  deniedForever,
  timeout,
  unavailable,
  reverseGeocodeFailed,
}

class LocationError implements Exception {
  const LocationError(this.type, [this.detail = '']);

  final LocationErrorType type;

  /// Internal detail only (never shown to the user, never logged with PII).
  final String detail;

  /// Honest, actionable message safe to display.
  String get userMessage {
    switch (type) {
      case LocationErrorType.serviceDisabled:
        return 'Location services are off. Turn them on, then try again.';
      case LocationErrorType.denied:
        return 'Location permission was denied. Allow access to use your current location.';
      case LocationErrorType.deniedForever:
        return 'Location permission is blocked. Open Settings to allow access.';
      case LocationErrorType.timeout:
        return 'Taking too long to find your location. Try again.';
      case LocationErrorType.unavailable:
        return 'Could not get your location. Please try again.';
      case LocationErrorType.reverseGeocodeFailed:
        return 'Found your position but not the address. Try again.';
    }
  }

  @override
  String toString() => 'LocationError($type)';
}

/// Injectable seam over geolocator statics so unit tests never touch GPS.
abstract class GeolocatorWrapper {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    Duration? timeLimit,
  });
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class DefaultGeolocatorWrapper implements GeolocatorWrapper {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) =>
      Geolocator.getCurrentPosition(
          desiredAccuracy: desiredAccuracy, timeLimit: timeLimit);

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Routed via permission_handler so the app has a single app-settings
  /// entry point (notification prompt uses the same plugin).
  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}

/// Injectable seam over geocoding statics so unit tests never do I/O.
abstract class GeocodingWrapper {
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  );
}

class DefaultGeocodingWrapper implements GeocodingWrapper {
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) =>
      placemarkFromCoordinates(latitude, longitude);
}

/// Current position + reverse-geocoded display (lat/lng text only —
/// deliberately no map widget; google_maps_flutter is not a dependency).
class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.displayLabel,
    this.street,
    this.area,
    this.city,
    this.postalCode,
  });

  final double latitude;
  final double longitude;

  /// Human-readable address line built from the placemark.
  final String displayLabel;
  final String? street;
  final String? area;
  final String? city;
  final String? postalCode;

  /// Stable text representation for the prefill sheet / header.
  String get latLngText =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

/// Pure wrapper over geolocator + geocoding + permission_handler.
///
/// Flow (per spec): isServiceEnabled? no → openLocationSettings → retry;
/// checkPermission denied → request; deniedForever → openAppSettings;
/// getCurrentPosition(high accuracy, 15s timeout) → placemark → prefill.
class LocationService {
  LocationService({GeolocatorWrapper? geolocator, GeocodingWrapper? geocoding})
      : _geolocator = geolocator ?? DefaultGeolocatorWrapper(),
        _geocoding = geocoding ?? DefaultGeocodingWrapper();

  static const Duration positionTimeout = Duration(seconds: 15);

  final GeolocatorWrapper _geolocator;
  final GeocodingWrapper _geocoding;

  /// Full flow: permission handling, one-shot fix, reverse-geocode.
  /// Throws a typed [LocationError] on every failure branch.
  Future<ResolvedLocation> resolveCurrentAddress() async {
    final serviceEnabled = await _geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _geolocator.openLocationSettings();
      throw const LocationError(LocationErrorType.serviceDisabled);
    }

    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationError(LocationErrorType.denied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      await _geolocator.openAppSettings();
      throw const LocationError(LocationErrorType.deniedForever);
    }

    late final Position position;
    try {
      position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: positionTimeout,
      );
    } on TimeoutException {
      throw const LocationError(LocationErrorType.timeout);
    } on LocationError {
      rethrow;
    } catch (_) {
      throw const LocationError(LocationErrorType.unavailable);
    }

    // ssdlc input validation at the trust boundary (spec: lat -90..90,
    // lng -180..180). Never log the raw values (PII).
    if (position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      throw const LocationError(
        LocationErrorType.unavailable,
        'invalid-fix-out-of-range',
      );
    }

    late final List<Placemark> placemarks;
    try {
      placemarks = await _geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(positionTimeout);
    } on TimeoutException {
      throw const LocationError(LocationErrorType.timeout);
    } catch (_) {
      throw const LocationError(LocationErrorType.reverseGeocodeFailed);
    }
    if (placemarks.isEmpty) {
      throw const LocationError(LocationErrorType.reverseGeocodeFailed);
    }

    return _fromPlacemark(
      latitude: position.latitude,
      longitude: position.longitude,
      placemark: placemarks.first,
    );
  }

  /// Opens the OS app-settings page (deniedForever recovery action).
  Future<bool> openAppSettings() => _geolocator.openAppSettings();

  ResolvedLocation _fromPlacemark({
    required double latitude,
    required double longitude,
    required Placemark placemark,
  }) {
    String? clean(String? value) {
      final v = value?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final street = clean(placemark.street) ?? clean(placemark.name);
    final area = clean(placemark.subLocality) ?? clean(placemark.locality);
    final city = clean(placemark.locality) ?? clean(placemark.subAdministrativeArea);
    final postalCode = clean(placemark.postalCode);
    final parts = <String>[
      if (street != null) street,
      if (area != null && area != street) area,
      if (city != null && city != area) city,
      if (postalCode != null) postalCode,
    ];
    return ResolvedLocation(
      latitude: latitude,
      longitude: longitude,
      displayLabel:
          parts.isEmpty ? 'Current location' : parts.join(', '),
      street: street,
      area: area,
      city: city,
      postalCode: postalCode,
    );
  }
}
