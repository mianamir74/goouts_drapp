import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;

/// GoOuts Address Lookup Service
///
/// Two strategies, one token:
///
///  1. Profile registration — postcode → Look Up → dropdown of real addresses
///     (one paid Geocoding v6 call, up to 10 results, user picks theirs)
///
///  2. Food delivery picker — free-text autofill with session tokens
///     (suggest calls = FREE within session; only retrieve = 1 paid call)
class AddressLookupService {
  static const String _mapboxToken =
      'pk.eyJ1IjoibWlhbmFtaXI3NCIsImEiOiJjbW44aGp1bTYwYzVrMnBxcnRvYzA5bG40In0.2thWcmSMupWuGVNKJmfQyg';

  // ─── Session token ────────────────────────────────────────────────────────

  /// Generates a UUID v4 to use as a Mapbox session token.
  /// All suggest() calls sharing the same token are FREE.
  /// Only the matching retrieve() call is billed (one session = one charge).
  static String generateSessionToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC variant
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '\${hex.substring(0, 8)}-\${hex.substring(8, 12)}-'
        '\${hex.substring(12, 16)}-\${hex.substring(16, 20)}-'
        '\${hex.substring(20)}';
  }

  // ─── Postcode helpers ─────────────────────────────────────────────────────

  /// Normalise postcode to standard `AA1 1AA` format.
  static String normalise(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length < 3) return cleaned;
    return '\${cleaned.substring(0, cleaned.length - 3)} '
        '\${cleaned.substring(cleaned.length - 3)}';
  }

  /// True if the postcode is a Northern Ireland (BT) code.
  static bool isNorthernIrelandPostcode(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.startsWith('BT');
  }

  // ─── Profile registration: postcode → address list ────────────────────────

  /// One Mapbox Geocoding v6 call.
  /// Returns up to 10 real physical addresses for the given postcode.
  /// User picks one from a dropdown — no second call needed.
  Future<List<MapboxAddressResult>> validatePostcode(String postcode) async {
    final String normalised = normalise(postcode);
    try {
      final Uri uri = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/forward',
        <String, String>{
          'q': normalised,
          'country': 'GB',
          'types': 'address',   // real street addresses, not just postcode areas
          'limit': '10',
          'autocomplete': 'false',
          'access_token': _mapboxToken,
        },
      );

      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 10));

      developer.log(
        'Mapbox postcode \${res.statusCode} for \$normalised',
        name: 'AddressLookup',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) return [];

      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> features =
          (decoded['features'] as List<dynamic>?) ?? <dynamic>[];
      if (features.isEmpty) return [];

      final List<MapboxAddressResult> results = [];
      for (final f in features) {
        final feature = _asMap(f);
        final props   = _asMap(feature['properties']);
        final ctx     = _asMap(props['context']);
        final geometry = _asMap(feature['geometry']);
        final coords   =
            (geometry['coordinates'] as List<dynamic>?) ?? <dynamic>[];

        double? lng, lat;
        if (coords.length >= 2) {
          lng = _toDouble(coords[0]);
          lat = _toDouble(coords[1]);
        }

        final addrCtx     = _asMap(ctx['address']);
        final postcodeCtx = _asMap(ctx['postcode']);
        final placeCtx    = _asMap(ctx['place']);
        final countryCtx  = _asMap(ctx['country']);

        final houseNumber = _str(addrCtx['address_number']);
        final street      = _str(addrCtx['street_name']);
        final pc          = _str(postcodeCtx['name']).isNotEmpty
            ? _str(postcodeCtx['name'])
            : normalised;
        final town        = _str(placeCtx['name']);
        final country     = _str(countryCtx['name']);

        final inferredCity =
            inferCityFromPostcode(pc) ?? town;

        final fullAddress = _str(props['full_address']).isNotEmpty
            ? _str(props['full_address'])
            : _str(props['name']);

        if (fullAddress.isEmpty) continue;

        results.add(MapboxAddressResult(
          city: inferredCity,
          town: town.isNotEmpty ? town : null,
          fullAddress: fullAddress,
          postcode: pc,
          latitude: lat,
          longitude: lng,
          houseNumber: houseNumber.isNotEmpty ? houseNumber : null,
          street: street.isNotEmpty ? street : null,
          country: country.isNotEmpty ? country : null,
        ));
      }
      return results;
    } catch (e, st) {
      developer.log(
        'Mapbox error: \$e',
        name: 'AddressLookup',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // ─── Food delivery: free-text autofill with session tokens ────────────────

  /// Suggest addresses as the user types.
  /// ALL calls sharing the same [sessionToken] are FREE — Mapbox bundles them.
  /// Minimum 3 characters before firing.
  Future<List<MapboxSuggestResult>> suggest(
      String query, String sessionToken) async {
    if (query.trim().length < 3) return [];
    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/search/searchbox/v1/suggest',
        <String, String>{
          'q': query,
          'session_token': sessionToken,
          'country': 'gb',
          'limit': '6',
          'language': 'en',
          'types': 'address',
          'access_token': _mapboxToken,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return [];

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final suggestions =
          (decoded['suggestions'] as List<dynamic>?) ?? <dynamic>[];

      return suggestions.map((s) {
        final m = _asMap(s);
        final name = _str(m['name']);
        final pf   = _str(m['place_formatted']);
        return MapboxSuggestResult(
          mapboxId: _str(m['mapbox_id']),
          name: name,
          placeFormatted: pf,
          fullAddress: '\$name, \$pf',
        );
      }).where((r) => r.mapboxId.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retrieve full details for a selected suggestion.
  /// This is the ONE paid call per address lookup.
  /// Always generate a new session token after calling this.
  Future<MapboxAddressResult?> retrieve(
      String mapboxId, String sessionToken) async {
    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/search/searchbox/v1/retrieve/\$mapboxId',
        <String, String>{
          'session_token': sessionToken,
          'access_token': _mapboxToken,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final features =
          (decoded['features'] as List<dynamic>?) ?? <dynamic>[];
      if (features.isEmpty) return null;

      final feature  = _asMap(features.first);
      final props    = _asMap(feature['properties']);
      final ctx      = _asMap(props['context']);
      final geometry = _asMap(feature['geometry']);
      final coords =
          (geometry['coordinates'] as List<dynamic>?) ?? <dynamic>[];

      double? lng, lat;
      if (coords.length >= 2) {
        lng = _toDouble(coords[0]);
        lat = _toDouble(coords[1]);
      }

      final addrCtx     = _asMap(ctx['address']);
      final postcodeCtx = _asMap(ctx['postcode']);
      final placeCtx    = _asMap(ctx['place']);
      final countryCtx  = _asMap(ctx['country']);

      final houseNumber = _str(addrCtx['address_number']);
      final street      = _str(addrCtx['street_name']);
      final postcode    = _str(postcodeCtx['name']);
      final town        = _str(placeCtx['name']);
      final country     = _str(countryCtx['name']);
      final inferredCity = inferCityFromPostcode(postcode) ?? town;

      final fullAddress = _str(props['full_address']).isNotEmpty
          ? _str(props['full_address'])
          : _str(props['name']);

      return MapboxAddressResult(
        city: inferredCity,
        town: town.isNotEmpty ? town : null,
        fullAddress: fullAddress,
        postcode: postcode,
        latitude: lat,
        longitude: lng,
        houseNumber: houseNumber.isNotEmpty ? houseNumber : null,
        street: street.isNotEmpty ? street : null,
        country: country.isNotEmpty ? country : null,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Reverse geocode (GPS flow — unchanged) ───────────────────────────────

  Future<MapboxAddressResult?> reverseGeocode(
      double latitude, double longitude) async {
    try {
      final Uri uri = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/reverse',
        <String, String>{
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
          'types': 'address',
          'limit': '1',
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
      final Map<String, dynamic> props   = _asMap(feature['properties']);
      final Map<String, dynamic> ctx     = _asMap(props['context']);

      final city = _readContextName(ctx, 'place') ??
          _readContextName(ctx, 'locality') ??
          _readContextName(ctx, 'district') ??
          '';

      final dynamic postcodeCtx = ctx['postcode'];
      String postcode = '';
      if (postcodeCtx is Map) {
        postcode = _str(Map<String, dynamic>.from(postcodeCtx)['name']);
      }

      final fullAddress = _str(props['full_address']).isNotEmpty
          ? _str(props['full_address'])
          : _str(props['name']);

      return MapboxAddressResult(
        city: city,
        fullAddress: fullAddress,
        postcode: postcode,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── City inference from postcode area (unchanged) ───────────────────────

  static String? inferCityFromPostcode(String postcode) {
    final String area = postcode
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll(RegExp(r'\d.*'), '');

    const Map<String, String> twoLetter = <String, String>{
      'AB': 'Aberdeen', 'BA': 'Bath', 'BB': 'Blackburn', 'BD': 'Bradford',
      'BH': 'Bournemouth', 'BL': 'Bolton', 'BN': 'Brighton', 'BR': 'London',
      'BS': 'Bristol', 'CB': 'Cambridge', 'CF': 'Cardiff', 'CH': 'Chester',
      'CM': 'Chelmsford', 'CO': 'Colchester', 'CR': 'London', 'CV': 'Coventry',
      'DA': 'London', 'DD': 'Dundee', 'DE': 'Derby', 'DH': 'Durham',
      'DY': 'Wolverhampton', 'EC': 'London', 'EH': 'Edinburgh', 'EN': 'London',
      'EX': 'Exeter', 'FY': 'Blackpool', 'GL': 'Gloucester', 'HA': 'London',
      'HD': 'Huddersfield', 'HU': 'Hull', 'IG': 'London', 'IP': 'Ipswich',
      'IV': 'Inverness', 'KT': 'London', 'LE': 'Leicester', 'LL': 'Chester',
      'LN': 'Lincoln', 'LS': 'Leeds', 'LU': 'Luton', 'ME': 'Chelmsford',
      'MK': 'Milton Keynes', 'NE': 'Newcastle upon Tyne', 'NG': 'Nottingham',
      'NN': 'Northampton', 'NR': 'Norwich', 'NW': 'London', 'OX': 'Oxford',
      'PE': 'Peterborough', 'PL': 'Plymouth', 'PO': 'Portsmouth', 'PR': 'Preston',
      'RG': 'Reading', 'RM': 'London', 'SA': 'Swansea', 'SE': 'London',
      'SM': 'London', 'SO': 'Southampton', 'SR': 'Sunderland', 'ST': 'Stoke-on-Trent',
      'SW': 'London', 'TW': 'London', 'UB': 'London', 'WC': 'London',
      'WD': 'London', 'WR': 'Worcester', 'WS': 'Wolverhampton',
      'WV': 'Wolverhampton', 'YO': 'York', 'BT': 'Belfast',
    };

    if (area.length >= 2 && twoLetter.containsKey(area.substring(0, 2))) {
      return twoLetter[area.substring(0, 2)];
    }

    const Map<String, String> oneLetter = <String, String>{
      'B': 'Birmingham', 'E': 'London', 'G': 'Glasgow',
      'L': 'Liverpool', 'M': 'Manchester', 'N': 'London',
      'S': 'Sheffield', 'W': 'London',
    };

    if (area.isNotEmpty && oneLetter.containsKey(area[0])) {
      return oneLetter[area[0]];
    }
    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

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

  // ── Backward-compat methods used by goouts_drapp registration screens ───────

  /// Returns up to 10 real addresses for [postcode] as [OsAddressResult] objects.
  /// Used by the OS-style bottom-sheet picker in registration_screen.dart.
  Future<List<OsAddressResult>> findAddressesAtPostcode(String postcode) async {
    final List<MapboxAddressResult> results = await validatePostcode(postcode);
    return results.map(OsAddressResult.fromMapbox).toList();
  }

  /// Returns the first Mapbox result for [postcode], or null if not found.
  /// Used for Northern Ireland (BT) fallback in registration_screen.dart.
  Future<MapboxAddressResult?> findFromMapbox(String postcode) async {
    final List<MapboxAddressResult> results = await validatePostcode(postcode);
    return results.isNotEmpty ? results.first : null;
  }
}

// ─── Result models ────────────────────────────────────────────────────────────

/// Full address result from Mapbox (geocoding or retrieve).
class MapboxAddressResult {
  const MapboxAddressResult({
    required this.city,
    required this.fullAddress,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.town,
    this.country,
  });

  /// Major city inferred from postcode area (e.g. "London", "Manchester").
  final String city;

  /// Local area / town from Mapbox context (e.g. "Wembley", "Salford").
  final String? town;

  /// Full formatted address string.
  final String fullAddress;

  /// Normalised postcode (e.g. "HA9 9PT").
  final String postcode;

  /// House / building number (e.g. "12").
  final String? houseNumber;

  /// Street / road name (e.g. "East Hill").
  final String? street;

  /// Country name (e.g. "United Kingdom").
  final String? country;

  final double? latitude;
  final double? longitude;
}

/// Lightweight suggestion returned by suggest() — no coordinates yet.
/// Call retrieve() with [mapboxId] to get full details.
class MapboxSuggestResult {
  const MapboxSuggestResult({
    required this.mapboxId,
    required this.name,
    required this.placeFormatted,
    required this.fullAddress,
  });

  /// Mapbox internal ID — pass to retrieve().
  final String mapboxId;

  /// Primary display name (e.g. "12 East Hill").
  final String name;

  /// Secondary display line (e.g. "London, SE18 2DP, United Kingdom").
  final String placeFormatted;

  /// Combined display string.
  final String fullAddress;
}

// ─── Backward-compat wrapper for goouts_drapp registration flows ──────────────
//
// The OS (Ordnance Survey) address picker bottom sheet expects an OsAddressResult
// with fields like uprn, thoroughfareName, resolvedBuildingRef, postTown.
// We now use Mapbox for everything, so we expose a thin wrapper that maps the
// Mapbox fields to the old OS field names so the bottom-sheet code keeps working.

class OsAddressResult {
  const OsAddressResult._({
    required this.uprn,
    required this.fullAddress,
    required this.postcode,
    required this.postTown,
    required this.thoroughfareName,
    required this.resolvedBuildingRef,
    required this.latitude,
    required this.longitude,
  });

  /// Not available from Mapbox — kept for API compat (empty string).
  final String uprn;

  /// Full formatted address string.
  final String fullAddress;

  /// Normalised postcode (e.g. "HA9 9PT").
  final String postcode;

  /// Town / locality (Mapbox: town ?? city).
  final String postTown;

  /// Street / road name.
  final String thoroughfareName;

  /// House / building number or name.
  final String resolvedBuildingRef;

  final double? latitude;
  final double? longitude;

  /// Build from a [MapboxAddressResult].
  factory OsAddressResult.fromMapbox(MapboxAddressResult m) =>
      OsAddressResult._(
        uprn: '',
        fullAddress: m.fullAddress,
        postcode: m.postcode,
        postTown: m.town ?? m.city,
        thoroughfareName: m.street ?? '',
        resolvedBuildingRef: m.houseNumber ?? '',
        latitude: m.latitude,
        longitude: m.longitude,
      );
}
