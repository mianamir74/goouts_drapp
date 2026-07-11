import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// GoOuts Address Lookup Service — Smart Hybrid Strategy (May 2026).
///
/// This service implements a "Two-Step Professional" address verification flow:
///
///   Step 1: User enters a postcode → app fetches every official address
///           registered against that postcode (Ordnance Survey DPA records).
///   Step 2: User picks the correct address from the list → app verifies it
///           and returns the gold-standard data (UPRN + latitude + longitude
///           + full formatted address).
///
/// Coverage notes:
///   - Ordnance Survey covers England, Scotland and Wales (best UPRN data).
///   - For Northern Ireland (BT postcodes) we fall back to Mapbox geocoding,
///     which still gives us a postcode area, town and approximate coords.
///
/// The class is fully self-contained: just create one instance and call the
/// public methods. No internal state is held between calls.
class AddressLookupService {
  static const String _osApiKey =
      '1QhcDDKnU1qFg6JHK0t8V3kGZ7vMpyzG';
  static const String _mapboxToken =
      'pk.eyJ1IjoibWlhbmFtaXI3NCIsImEiOiJjbW44aGp1bTYwYzVrMnBxcnRvYzA5bG40In0.2thWcmSMupWuGVNKJmfQyg';

  // ─── Postcode helpers ────────────────────────────────────────────────────

  /// Normalise postcode to standard `AA1 1AA` format
  /// (uppercase, single space before the inward code).
  static String normalise(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length < 3) return cleaned;
    return '${cleaned.substring(0, cleaned.length - 3)} '
        '${cleaned.substring(cleaned.length - 3)}';
  }

  /// Returns true if the postcode looks like a Northern Ireland (BT) code.
  static bool isNorthernIrelandPostcode(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.startsWith('BT');
  }

  // ─── Step 1: List all addresses at a postcode ────────────────────────────

  /// Calls the Ordnance Survey Places API `/postcode` endpoint and returns
  /// every Delivery Point Address (DPA) registered at that postcode.
  ///
  /// Returns an empty list if nothing is found or if the call fails.
  /// Used by the "Find Official Address" button to populate the bottom sheet.
  Future<List<OsAddressResult>> findAddressesAtPostcode(String postcode) async {
    final String normalised = normalise(postcode);

    try {
      final Uri uri = Uri.https(
        'api.os.uk',
        '/search/places/v1/postcode',
        <String, String>{
          'postcode': normalised,
          'key': _osApiKey,
          'maxresults': '100',
          'dataset': 'DPA',
        },
      );

      // ignore: avoid_print
      developer.log(
        'OS Places API call → $uri',
        name: 'AddressLookup',
      );

      final http.Response res = await http
          .get(uri, headers: <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      // ignore: avoid_print
      developer.log(
        'OS response status=${res.statusCode}, body length=${res.body.length}',
        name: 'AddressLookup',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final String preview =
            res.body.length > 500 ? res.body.substring(0, 500) : res.body;
        // ignore: avoid_print
        developer.log(
          'OS returned non-2xx. Body: $preview',
          name: 'AddressLookup',
        );
        return <OsAddressResult>[];
      }

      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;

      final List<dynamic> results =
          (decoded['results'] as List<dynamic>?) ?? <dynamic>[];

      // ignore: avoid_print
      developer.log(
        'OS returned ${results.length} result(s) for $normalised',
        name: 'AddressLookup',
      );

      final List<OsAddressResult> addresses = <OsAddressResult>[];
      for (final dynamic raw in results) {
        final Map<String, dynamic> row = _asMap(raw);
        final Map<String, dynamic> dpa = _asMap(row['DPA']);
        if (dpa.isEmpty) continue;

        addresses.add(OsAddressResult.fromDpa(dpa));
      }
      return addresses;
    } catch (e, stack) {
      // ignore: avoid_print
      developer.log(
        'OS lookup threw exception: $e',
        name: 'AddressLookup',
        error: e,
        stackTrace: stack,
      );
      return <OsAddressResult>[];
    }
  }

  // ─── Step 1 fallback: Mapbox lookup (mainly for BT postcodes) ────────────

  /// Calls Mapbox Geocoding for the postcode and returns a single
  /// best-guess address. Used when Ordnance Survey returns nothing
  /// (typical for Northern Ireland BT postcodes).
  ///
  /// Returns null if Mapbox finds nothing.
  Future<MapboxAddressResult?> findFromMapbox(String postcode) async {
    final String normalised = normalise(postcode);

    try {
      final Uri uri = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/forward',
        <String, String>{
          'q': normalised,
          'country': 'GB',
          'types': 'postcode',
          'limit': '1',
          'autocomplete': 'false',
          'access_token': _mapboxToken,
        },
      );

      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;

      final List<dynamic> features =
          (decoded['features'] as List<dynamic>?) ?? <dynamic>[];
      if (features.isEmpty) return null;

      final Map<String, dynamic> feature = _asMap(features.first);
      final Map<String, dynamic> props = _asMap(feature['properties']);
      final Map<String, dynamic> ctx = _asMap(props['context']);
      final Map<String, dynamic> geometry = _asMap(feature['geometry']);

      final List<dynamic> coords =
          (geometry['coordinates'] as List<dynamic>?) ?? <dynamic>[];

      double? lng;
      double? lat;
      if (coords.length >= 2) {
        lng = _toDouble(coords[0]);
        lat = _toDouble(coords[1]);
      }

      final String city = _readContextName(ctx, 'place') ??
          _readContextName(ctx, 'locality') ??
          _readContextName(ctx, 'district') ??
          '';

      final String fullAddress = _str(props['full_address']).isNotEmpty
          ? _str(props['full_address'])
          : _str(props['name']);

      return MapboxAddressResult(
        city: city,
        fullAddress: fullAddress,
        postcode: normalised,
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Legacy single-address lookup (kept for backwards compatibility) ─────

  /// Returns the first address at a postcode, or null. Internally calls
  /// [findAddressesAtPostcode] and just returns the first item.
  ///
  /// Existing screens that haven't been migrated to the bottom-sheet flow
  /// can still use this without breaking.
  Future<OsAddressResult?> verifyWithOS(String postcode) async {
    final List<OsAddressResult> all = await findAddressesAtPostcode(postcode);
    if (all.isEmpty) return null;
    return all.first;
  }

  /// Returns just the city name from Mapbox for a postcode. Kept for
  /// backwards compatibility with the old confirm-postcode flow.
  Future<String> cityFromMapbox(String postcode) async {
    final MapboxAddressResult? result = await findFromMapbox(postcode);
    return result?.city ?? '';
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String? _readContextName(Map<String, dynamic> ctx, String key) {
    final dynamic v = ctx[key];
    if (v is Map) {
      final String name = _str(Map<String, dynamic>.from(v)['name']);
      if (name.isNotEmpty) return name;
    }
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }
}

/// A single official address record returned by Ordnance Survey.
///
/// Built from a DPA (Delivery Point Address) record. Includes the
/// gold-standard fields a delivery driver app should store:
///   • [uprn]        — Unique Property Reference Number (never changes)
///   • [latitude] / [longitude] — precise delivery coordinates
///   • [fullAddress] — formatted human-readable address for display
class OsAddressResult {
  const OsAddressResult({
    required this.postTown,
    required this.thoroughfareName,
    required this.buildingNumber,
    required this.buildingName,
    required this.subBuildingName,
    required this.dependentLocality,
    required this.uprn,
    required this.fullAddress,
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });

  /// Construct from a raw OS DPA map.
  factory OsAddressResult.fromDpa(Map<String, dynamic> dpa) {
    return OsAddressResult(
      postTown: _str(dpa['POST_TOWN']),
      thoroughfareName: _str(dpa['THOROUGHFARE_NAME']),
      buildingNumber: _str(dpa['BUILDING_NUMBER']),
      buildingName: _str(dpa['BUILDING_NAME']),
      subBuildingName: _str(dpa['SUB_BUILDING_NAME']),
      dependentLocality: _str(dpa['DEPENDENT_LOCALITY']),
      uprn: _str(dpa['UPRN']),
      fullAddress: _str(dpa['ADDRESS']),
      postcode: _str(dpa['POSTCODE']),
      latitude: _toDouble(dpa['LAT']),
      longitude: _toDouble(dpa['LNG']),
    );
  }

  final String postTown;
  final String thoroughfareName;
  final String buildingNumber;
  final String buildingName;
  final String subBuildingName;
  final String dependentLocality;
  final String uprn;
  final String fullAddress;
  final String postcode;
  final double? latitude;
  final double? longitude;

  /// Best building identifier: number first, then name.
  String get resolvedBuildingRef =>
      buildingNumber.isNotEmpty ? buildingNumber : buildingName;

  /// True when there's nothing meaningful in this record.
  bool get isEmpty =>
      postTown.isEmpty &&
      thoroughfareName.isEmpty &&
      buildingNumber.isEmpty &&
      buildingName.isEmpty &&
      uprn.isEmpty;

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Lightweight Mapbox fallback result. Used when Ordnance Survey has no
/// data (e.g. Northern Ireland BT postcodes, brand new builds).
class MapboxAddressResult {
  const MapboxAddressResult({
    required this.city,
    required this.fullAddress,
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });

  final String city;
  final String fullAddress;
  final String postcode;
  final double? latitude;
  final double? longitude;
}
