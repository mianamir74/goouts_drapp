// ─────────────────────────────────────────────────────────────────────────────
// DAPP Google Maps Widget — drop-in replacement for CustomPainter placeholders
//
// SETUP (one-time, done by developer):
//   Android: android/app/src/main/AndroidManifest.xml
//     Inside <application> tag add:
//     <meta-data
//       android:name="com.google.android.geo.API_KEY"
//       android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
//
//   iOS: ios/Runner/AppDelegate.swift
//     import GoogleMaps
//     GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
//
//   Enable APIs in Google Cloud Console:
//     - Maps SDK for Android
//     - Maps SDK for iOS
//     - Directions API (for route polylines)
//
// USAGE — replace each CustomPainter block with the relevant widget below:
//   DashboardMap()            → driver_dashboard_screen.dart (Busy Zones card)
//   ActiveDeliveryMap()       → active_delivery_screen.dart (route view)
//   TripRadarMap()            → trip_radar_screen.dart (nearby orders map)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// ── Shared helper: get current location ──────────────────────────────────────
Future<LatLng?> getCurrentLatLng() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  if (permission == LocationPermission.deniedForever) return null;

  final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return LatLng(pos.latitude, pos.longitude);
}

// ── 1. Dashboard Map (Busy Zones / Heatmap) ──────────────────────────────────
//
// Replaces the CustomPainter block in driver_dashboard_screen.dart.
// Shows driver's current location with a blue dot and nearby demand circles.
//
// Swap-in instruction:
//   Replace this block in driver_dashboard_screen.dart:
//     ClipRRect(
//       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
//       child: Container(
//         height: 200,
//         color: const Color(0xFF0d1f4a),
//         child: CustomPaint(painter: _MapPlaceholderPainter(), ...),
//       ),
//     ),
//   With:
//     ClipRRect(
//       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
//       child: SizedBox(height: 200, child: DashboardMap()),
//     ),
//
class DashboardMap extends StatefulWidget {
  const DashboardMap({super.key});

  @override
  State<DashboardMap> createState() => _DashboardMapState();
}

class _DashboardMapState extends State<DashboardMap> {
  GoogleMapController? _ctrl;
  LatLng _center = const LatLng(51.5074, -0.1278); // London fallback
  bool _loading = true;

  // Demand heat circles — in production, load these from Firestore
  final Set<Circle> _demandCircles = {
    Circle(
      circleId: const CircleId('hot1'),
      center: const LatLng(51.510, -0.130),
      radius: 400,
      fillColor: const Color(0xFFf97316).withOpacity(0.25),
      strokeColor: const Color(0xFFf97316).withOpacity(0.5),
      strokeWidth: 1,
    ),
    Circle(
      circleId: const CircleId('hot2'),
      center: const LatLng(51.505, -0.120),
      radius: 300,
      fillColor: const Color(0xFF0392ca).withOpacity(0.2),
      strokeColor: const Color(0xFF0392ca).withOpacity(0.4),
      strokeWidth: 1,
    ),
    Circle(
      circleId: const CircleId('med1'),
      center: const LatLng(51.515, -0.115),
      radius: 250,
      fillColor: const Color(0xFF10b981).withOpacity(0.2),
      strokeColor: const Color(0xFF10b981).withOpacity(0.3),
      strokeWidth: 1,
    ),
  };

  @override
  void initState() {
    super.initState();
    _locateDriver();
  }

  Future<void> _locateDriver() async {
    final loc = await getCurrentLatLng();
    if (!mounted) return;
    if (loc != null) {
      setState(() { _center = loc; _loading = false; });
      _ctrl?.animateCamera(CameraUpdate.newLatLng(loc));
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _center, zoom: 14.5),
          onMapCreated: (c) => _ctrl = c,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          circles: _demandCircles,
          mapType: MapType.normal,
          style: _darkMapStyle,
        ),
        if (_loading)
          Container(
            color: const Color(0xFF0b1a3d),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF0392ca)),
            ),
          ),
      ],
    );
  }
}


// ── 2. Active Delivery Route Map ──────────────────────────────────────────────
//
// Shows driver position, restaurant marker, customer marker, and a route line.
// Replaces the _RouteMapPainter CustomPainter in active_delivery_screen.dart.
//
// Swap-in instruction — replace the CustomPaint(painter: _RouteMapPainter())
// container with:
//   ActiveDeliveryMap(
//     restaurantLatLng: LatLng(restaurantLat, restaurantLng),
//     customerLatLng:   LatLng(customerLat, customerLng),
//   )
//
class ActiveDeliveryMap extends StatefulWidget {
  /// Restaurant pickup location
  final LatLng restaurantLatLng;
  /// Customer dropoff location
  final LatLng customerLatLng;

  const ActiveDeliveryMap({
    super.key,
    required this.restaurantLatLng,
    required this.customerLatLng,
  });

  @override
  State<ActiveDeliveryMap> createState() => _ActiveDeliveryMapState();
}

class _ActiveDeliveryMapState extends State<ActiveDeliveryMap> {
  GoogleMapController? _ctrl;
  LatLng? _driverPos;

  late final Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _markers = {
      Marker(
        markerId: const MarkerId('restaurant'),
        position: widget.restaurantLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      Marker(
        markerId: const MarkerId('customer'),
        position: widget.customerLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Dropoff'),
      ),
    };
    _locateDriver();
  }

  Future<void> _locateDriver() async {
    final loc = await getCurrentLatLng();
    if (!mounted || loc == null) return;
    setState(() => _driverPos = loc);
  }

  // Fit map to show all 3 points
  void _fitBounds() {
    final points = [
      widget.restaurantLatLng,
      widget.customerLatLng,
      if (_driverPos != null) _driverPos!,
    ];
    final sw = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
      points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
    );
    final ne = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
      points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
    );
    _ctrl?.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 60));
  }

  @override
  Widget build(BuildContext context) {
    // Straight-line polyline between restaurant and customer
    // In production: call Directions API for a real road route
    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.restaurantLatLng, widget.customerLatLng],
        color: const Color(0xFF0392ca),
        width: 4,
        patterns: [PatternItem.dash(12), PatternItem.gap(8)],
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
          target: widget.restaurantLatLng, zoom: 14),
      onMapCreated: (c) {
        _ctrl = c;
        Future.delayed(const Duration(milliseconds: 300), _fitBounds);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: _markers,
      polylines: polylines,
      style: _darkMapStyle,
    );
  }
}


// ── 3. Trip Radar Map ─────────────────────────────────────────────────────────
//
// Shows driver's position plus pulsing markers for nearby available orders.
// Replaces the _RadarMapPainter CustomPainter in trip_radar_screen.dart.
//
// Swap-in instruction — replace the Container(... child: CustomPaint(...))
// in trip_radar_screen.dart with:
//   TripRadarMap(nearbyOrders: _orders)
// where _orders is a List<Map<String,dynamic>> from Firestore.
//
class TripRadarMap extends StatefulWidget {
  final List<Map<String, dynamic>> nearbyOrders;

  const TripRadarMap({super.key, this.nearbyOrders = const []});

  @override
  State<TripRadarMap> createState() => _TripRadarMapState();
}

class _TripRadarMapState extends State<TripRadarMap> {
  GoogleMapController? _ctrl;
  LatLng _center = const LatLng(51.5074, -0.1278);

  @override
  void initState() {
    super.initState();
    getCurrentLatLng().then((loc) {
      if (!mounted || loc == null) return;
      setState(() => _center = loc);
      _ctrl?.animateCamera(CameraUpdate.newLatLng(loc));
    });
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (int i = 0; i < widget.nearbyOrders.length; i++) {
      final o = widget.nearbyOrders[i];
      final lat = o['restaurantLat'];
      final lng = o['restaurantLng'];
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        markerId: MarkerId('order_$i'),
        position: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0
                ? BitmapDescriptor.hueOrange   // highest pay
                : BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: o['restaurantName'] ?? 'Order',
          snippet: o['driverFee'] != null ? '£${o['driverFee']}' : null,
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _center, zoom: 13.5),
      onMapCreated: (c) => _ctrl = c,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: _markers,
      style: _darkMapStyle,
    );
  }
}


// ── Dark map style (matches GoOuts #031134 theme) ────────────────────────────
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#031134"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#0b1a3d"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#0392ca"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#02111e"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';
