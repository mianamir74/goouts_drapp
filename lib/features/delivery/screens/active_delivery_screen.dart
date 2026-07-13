import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../services/location_broadcast_service.dart';
import 'delivery_verification_screen.dart';
import 'food_delivery_chat_screen.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final _db  = FirebaseFirestore.instance;
  final _loc = LocationBroadcastService();

  Map<String, dynamic>? _order;
  StreamSubscription? _sub;
  bool _itemsExpanded = false;
  bool _qrScannerOpen = false;
  bool _qrVerifying   = false;

  // Map
  GoogleMapController? _mapController;
  LatLng? _driverLatLng;
  final Set<Marker>  _markers   = {};
  final Set<Polyline> _polylines = {};

  // Steps: 0 = heading to restaurant, 1 = picked up, 2 = delivered
  int get _step {
    final s = _order?['status'] ?? '';
    if (s == 'driver_heading_to_restaurant') return 0;
    if (s == 'driver_picked_up') return 1;
    if (s == 'delivered') return 2;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _sub = _db
        .collection('food_orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = {'id': snap.id, ...?snap.data()};
      setState(() => _order = data);
      _updateMapMarkers(data);
    });

    // Start broadcasting GPS to RTDB
    final driverId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    _loc.start(orderId: widget.orderId, driverId: driverId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _loc.stop();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMapMarkers(Map<String, dynamic> order) {
    final markers  = <Marker>{};
    final polyline = <LatLng>[];

    // Restaurant pin
    final restGeo = order['restaurantLocation'];
    LatLng? restLatLng;
    if (restGeo is GeoPoint) {
      restLatLng = LatLng(restGeo.latitude, restGeo.longitude);
      markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: restLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: order['restaurantName'] ?? 'Restaurant'),
      ));
      polyline.add(restLatLng);
    }

    // Customer pin
    final custGeo = order['deliveryLocation'];
    LatLng? custLatLng;
    if (custGeo is GeoPoint) {
      custLatLng = LatLng(custGeo.latitude, custGeo.longitude);
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: custLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: order['customerName'] ?? 'Customer'),
      ));
      polyline.add(custLatLng);
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _polylines.clear();
      if (polyline.length >= 2) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: polyline,
          color: const Color(0xFF0392ca),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      }
    });
  }

  Future<void> _openQrScanner() async {
    setState(() => _qrScannerOpen = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrScanSheet(
        onScanned: (code) async {
          Navigator.pop(context);
          setState(() => _qrVerifying = true);
          await _verifyPickupQR(code);
          setState(() => _qrVerifying = false);
        },
      ),
    );
    if (mounted) setState(() => _qrScannerOpen = false);
  }

  Future<void> _verifyPickupQR(String scannedOrderId) async {
    if (scannedOrderId.trim() != widget.orderId) {
      if (!mounted) return;
      GoOutsSheet.error(context, title: 'Scan Error', message: 'QR does not match this order.',
      ));
      return;
    }
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await fn.httpsCallable('verifyPickupQR').call({'orderId': widget.orderId});
      if (mounted) {
        GoOutsSheet.success(context, title: 'Picked Up!', message: 'Order picked up — confirmed!',
        ));
      }
    } catch (e) {
      if (!mounted) return;
      GoOutsSheet.error(context, title: 'Verification Failed', message: 'Verification failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _markDelivered() async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryVerificationScreen(orderId: widget.orderId),
      ),
    );
    if (confirmed != true) return;
    try {
      await _db.collection('food_orders').doc(widget.orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
      // Stop broadcasting location once delivered
      await _loc.stop();
    } catch (e) {
      if (!mounted) return;
      GoOutsSheet.error(context, title: 'Delivery Failed', message: 'Failed to confirm delivery. Check your connection.',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_order == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF031134),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0392ca))),
      );
    }

    final restaurant   = _order!['restaurantName']    ?? 'Restaurant';
    final restAddress  = _order!['restaurantAddress'] ?? '';
    final customer     = _order!['customerName']      ?? '';
    final custAddress  = _order!['deliveryAddress']   ?? '';
    final driverFee    = (_order!['driverFee']        ?? 0.0).toDouble();
    final distance     = _order!['distance']          ?? '2.4';
    final estMins      = _order!['estimatedMins']     ?? 12;
    final restImageUrl = _order!['restaurantImageUrl'] as String?;
    final items        = (_order!['items'] as List?)?.cast<Map>() ?? [];
    final step         = _step;

    // Default map center — London if no location yet
    final restGeo      = _order!['restaurantLocation'];
    final initialCam   = restGeo is GeoPoint
        ? CameraPosition(target: LatLng(restGeo.latitude, restGeo.longitude), zoom: 14)
        : const CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 13);

    final statusLabels = ['Heading to Pickup', 'Picked Up', 'Delivered'];
    final currentLabel = statusLabels[step.clamp(0, 2)];

    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Active Delivery',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0392ca),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text('ON ROUTE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress stepper ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order Status',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text(currentLabel,
                        style: const TextStyle(
                            color: Color(0xFF0392ca),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: step == 0 ? 0.33 : step == 1 ? 0.66 : 1.0,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF0392ca),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['ORDER READY', 'PICKED UP', 'DELIVERED']
                      .map((l) => Text(l,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 9, letterSpacing: 0.5)))
                      .toList(),
                ),
              ],
            ),
          ),

          // ── Live Google Map ───────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialCam,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  onMapCreated: (ctrl) {
                    _mapController = ctrl;
                    // Dark-style map
                    ctrl.setMapStyle(_darkMapStyle);
                  },
                ),
                // Nav info card
                Positioned(
                  top: 12,
                  left: 12,
                  right: 64,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0b1a3d).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0392ca),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Next Stop',
                                  style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Text(
                                step == 0 ? restaurant : customer,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // My location button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          _driverLatLng ?? initialCam.target, 15),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1a3d),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Action cards ──────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  // Restaurant card
                  _card(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: restImageUrl != null
                                  ? Image.network(restImageUrl,
                                      width: 50, height: 50, fit: BoxFit.cover)
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: const Color(0xFF031134),
                                      child: const Icon(Icons.restaurant, color: Color(0xFF0392ca))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(restaurant,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white)),
                                  Text(restAddress,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_outlined,
                                  color: Color(0xFF0392ca), size: 22),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FoodDeliveryChatScreen(
                                    orderId: widget.orderId,
                                    customerName: _order?['customerName'] ?? 'Customer',
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_outlined,
                                  color: Color(0xFF0392ca), size: 22),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: (step == 0 && !_qrVerifying) ? _openQrScanner : null,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: _qrVerifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('SCAN QR TO COLLECT',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step == 0
                                  ? const Color(0xFFf97316)
                                  : Colors.white12,
                              foregroundColor:
                                  step == 0 ? Colors.white : Colors.white38,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Customer card
                  _card(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF031134),
                              radius: 20,
                              child: Icon(Icons.person_outline,
                                  color: Colors.white54, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white)),
                                  Text(custAddress,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: step == 1 ? _markDelivered : null,
                            icon: Icon(Icons.local_shipping_outlined,
                                size: 18,
                                color: step == 1 ? Colors.white : Colors.white24),
                            label: Text('MARK DELIVERED',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: step == 1 ? Colors.white : Colors.white24)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step == 1
                                  ? const Color(0xFF10b981)
                                  : const Color(0xFF10b981).withOpacity(0.06),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Order items accordion
                  GestureDetector(
                    onTap: () => setState(() => _itemsExpanded = !_itemsExpanded),
                    child: _card(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long,
                                  color: Color(0xFF0392ca), size: 20),
                              const SizedBox(width: 10),
                              Text('Order Items (${items.length} items)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const Spacer(),
                              Icon(
                                _itemsExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white54,
                              ),
                            ],
                          ),
                          if (_itemsExpanded && items.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(color: Colors.white10),
                            ...items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Text('${item['quantity'] ?? 1}x',
                                          style: const TextStyle(
                                              color: Color(0xFF0392ca),
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(item['name'] ?? '',
                                              style: const TextStyle(color: Colors.white))),
                                      Text(
                                          '£${((item['price'] ?? 0.0) as num).toStringAsFixed(2)}',
                                          style:
                                              const TextStyle(color: Colors.white54)),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom earnings strip ─────────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bottomStat('ESTIMATED EARNINGS',
                '£${driverFee.toStringAsFixed(2)}',
                color: const Color(0xFF10b981)),
            _bottomStat('DISTANCE', '${distance}mi'),
            _bottomStat('TIME', '${estMins}m'),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: child,
      );

  Widget _bottomStat(String label, String value, {Color color = Colors.white}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      );
}

// ── Dark map style JSON ───────────────────────────────────────────────────────
const _darkMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#0a1628"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#0b2545"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#0392ca"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#021f33"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';

// ── QR Scanner bottom sheet ───────────────────────────────────────────────────
class _QrScanSheet extends StatefulWidget {
  final ValueChanged<String> onScanned;
  const _QrScanSheet({required this.onScanned});

  @override
  State<_QrScanSheet> createState() => _QrScanSheetStat