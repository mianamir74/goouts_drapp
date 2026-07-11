import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// GoOuts Address Lookup Service
///
/// Strategy: user types postcode → tap "Look Up Postcode" → Mapbox validates
/// it and returns city + coordinates in one call → city/country auto-fill →
/// driver/owner types house number and street name manually.
class AddressLookupService {
  static const String _mapboxToken =
      'pk.eyJ1IjoibWlhbmFtaXI3NCIsImEiOiJjbW44aGp1bTYwYzVrMnBxcnRvYzA5bG40In0.2thWcmSMupWuGVNKJmfQyg';

  // ─── Postcode helpers ────────────────────────────────────────────────────

  /// Normalise postcode to standard `AA1 1AA` format.
  static String normalise(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length < 3) return cleaned;
    return '${cleaned.substring(0, cleaned.length - 3)} '
        '${cleaned.substring(cleaned.length - 3)}';
  }

  /// True if the postcode is a Northern Ireland (BT) code.
  static bool isNorthernIrelandPostcode(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.startsWith('BT');
  }

  // ─── Mapbox postcode validation ──────────────────────────────────────────

  /// Validates a postcode via Mapbox and returns city + coordinates.
  /// Returns null if the postcode is not recognised.
  Future<MapboxAddressResult?> validatePostcode(String postcode) async {
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

      developer.log(
        'Mapbox postcode ${res.statusCode} for $normalised',
        name: 'AddressLookup',
      );

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
    } catch (e, st) {
      developer.log(
        'Mapbox error: $e',
        name: 'AddressLookup',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ─── City inference from postcode area ──────────────────────────────────

  /// Maps a UK postcode to the closest city in the app's dropdown.
  /// Two-letter area codes are checked before one-letter codes.
  /// Returns null if not mapped (user picks from dropdown manually).
  static String? inferCityFromPostcode(String postcode) {
    final String area = postcode
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll(RegExp(r'\d.*'), '');

    const Map<String, String> twoLetter = <String, String>{
      'AB': 'ABERDEEN',
      'BA': 'BATH',
      'BB': 'BLACKBURN',
      'BD': 'BRADFORD',
      'BH': 'BOURNEMOUTH',
      'BL': 'BOLTON',
      'BN': 'BRIGHTON',
      'BR': 'LONDON',
      'BS': 'BRISTOL',
      'CB': 'CAMBRIDGE',
      'CF': 'CARDIFF',
      'CH': 'CHESTER',
      'CM': 'CHELMSFORD',
      'CO': 'COLCHESTER',
      'CR': 'LONDON',
      'CV': 'COVENTRY',
      'DA': 'LONDON',
      'DD': 'DUNDEE',
      'DE': 'DERBY',
      'DH': 'DURHAM',
      'DY': 'WOLVERHAMPTON',
      'EC': 'LONDON',
      'EH': 'EDINBURGH',
      'EN': 'LONDON',
      'EX': 'EXETER',
      'FY': 'BLACKPOOL',
      'GL': 'GLOUCESTER',
      'HA': 'LONDON',
      'HD': 'HUDDERSFIELD',
      'HU': 'HULL',
      'IG': 'LONDON',
      'IP': 'IPSWICH',
      'IV': 'INVERNESS',
      'KT': 'LONDON',
      'LE': 'LEICESTER',
      'LL': 'CHESTER',
      'LN': 'LINCOLN',
      'LS': 'LEEDS',
      'LU': 'LUTON',
      'ME': 'CHELMSFORD',
      'MK': 'MILTON KEYNES',
      'NE': 'NEWCASTLE UPON TYNE',
      'NG': 'NOTTINGHAM',
      'NN': 'NORTHAMPTON',
      'NR': 'NORWICH',
      'NW': 'LONDON',
      'OX': 'OXFORD',
      'PE': 'PETERBOROUGH',
      'PL': 'PLYMOUTH',
      'PO': 'PORTSMOUTH',
      'PR': 'PRESTON',
      'RG': 'READING',
      'RM': 'LONDON',
      'SA': 'SWANSEA',
      'SE': 'LONDON',
      'SM': 'LONDON',
      'SO': 'SOUTHAMPTON',
      'SR': 'SUNDERLAND',
      'ST': 'STOKE-ON-TRENT',
      'SW': 'LONDON',
      'TW': 'LONDON',
      'UB': 'LONDON',
      'WC': 'LONDON',
      'WD': 'LONDON',
      'WR': 'WORCESTER',
      'WS': 'WOLVERHAMPTON',
      'WV': 'WOLVERHAMPTON',
      'YO': 'YORK',
      'BT': 'BELFAST',
    };

    if (area.length >= 2 && twoLetter.containsKey(area.substring(0, 2))) {
      return twoLetter[area.substring(0, 2)];
    }

    const Map<String, String> oneLetter = <String, String>{
      'B': 'BIRMINGHAM',
      'E': 'LONDON',
      'G': 'GLASGOW',
      'L': 'LIVERPOOL',
      'M': 'MANCHESTER',
      'N': 'LONDON',
      'S': 'SHEFFIELD',
      'W': 'LONDON',
    };

    if (area.isNotEmpty && oneLetter.containsKey(area[0])) {
      return oneLetter[area[0]];
    }

    return null;
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

/// Result from Mapbox postcode validation.
class MapboxAddressResult {
  const MapboxAddressResult({
    required this.city,
    required this.fullAddress,
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });

  /// Local area name from Mapbox (e.g. "Wembley", "Salford").
  final String city;

  /// Full formatted address string from Mapbox.
  final String fullAddress;

  /// Normalised postcode (e.g. "HA9 9PT").
  final String postcode;

  final double? latitude;
  final double? longitude;
}
