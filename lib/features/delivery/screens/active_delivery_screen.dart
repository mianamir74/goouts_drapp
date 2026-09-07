import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// mobile_scanner also exports a GeoPoint type, which clashes with the
// cloud_firestore GeoPoint used throughout this screen for driver location.
// Hide the scanner's version so GeoPoint unambiguously means Firestore's.
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;
import 'package:url_launcher/url_launcher.dart';

import '../../../services/location_broadcast_service.dart';
import 'delivery_verification_screen.dart';
import 'food_delivery_chat_screen.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 14_active_delivery_screen as the visual
//  reference — EXCEPT for its map card, which used a real Unsplash photo as
//  a fake "live map" background. This screen already has something better:
//  a REAL GoogleMap with real driver/restaurant/customer markers and a real
//  polyline, so that stays exactly as it was, just restyled to a light map
//  (GoOuts apps are light-themed; the old dark map style existed only
//  because this whole screen used to be dark).
//
//  ⚠ NOT carried over from the Stitch mockup: the 4-stage "Placed → Heading
//  → Picked Up → Delivered" stepper (this order model has 3 real states,
//  not 4 — there is no separate "assigned" stage before heading to the
//  restaurant), the standalone "Confirm Arrival at Restaurant" button (the
//  real backend has no such stage — verifyPickupQR combines arrival and
//  collection into one scan), the "£21.40 Order Total" and manifest item
//  status tags ("Verified Kitchen", "Ready", "Chilled" — not real fields),
//  and the customer note quote (no such field exists on food_orders yet —
//  the block below only renders if one is actually present).
//
//  All real logic — the Firestore order listener, GPS broadcast, QR
//  pickup verification, the masked-calling flag on the customer phone
//  button, and Mark Delivered — is unchanged from before this pass.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F4F7);
  static const surface   = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy      = Color(0xFF0D1B3E);
  static const accent    = Color(0xFFF97316);
  static const accentDk  = Color(0xFFEA580C);
  static const paleTint  = Color(0xFFE0F3FB);
  static const orangeTint = Color(0xFFFFEDD5);
  static const body      = Color(0xFF4A5568);
  static const muted     = Color(0xFF718096);
  static const success   = Color(0xFF16A34A);
  static const border    = Color(0xFFE2E8F0);
  static const softBox   = Color(0xFFF8FAFC);
  static const softBoxBorder = Color(0xFFEDF2F7);
  static const statusPillBg   = Color(0xFFDCEBFA);
  static const statusPillText = Color(0xFF0369A1);
}

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
          color: _C.primary,
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
      );
      return;
    }
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await fn.httpsCallable('verifyPickupQR').call({'orderId': widget.orderId});
      if (mounted) {
        GoOutsSheet.success(context, title: 'Picked Up!', message: 'Order picked up — confirmed!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      GoOutsSheet.error(context, title: 'Verification Failed', message: 'Verification failed: ${e.toString()}',
      );
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
      );
    }
  }

  // ⚠ WIRED 6 September 2026. restaurantPhone did not exist on any order
  // until food_orders.js's restaurantTerms() started reading it off the
  // merchant/restaurant record — see that file's comment for where it
  // comes from and why it may still be empty for a restaurant that has
  // never set one, hence the null onPressed above rather than launching a
  // tel: link to nothing.
  Future<void> _callRestaurant(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone.trim());
    await launchUrl(uri);
  }

  // Real deep link to the device's own maps app — no in-house routing or
  // turn-by-turn exists, and there is no restaurant/customer geocoding to
  // draw one from scratch (see driver_dashboard_screen's own note on this).
  // A plain search-query URL is honest about that: it hands off to Google
  // Maps rather than pretending this app has real navigation.
  Future<void> _launchNativeMaps(String query) async {
    if (query.trim().isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Placeholder tile used when the restaurant has no usable image.
  ///
  /// Shared by the empty check and the errorBuilder so both paths render the
  /// same thing.
  Widget _restaurantImageFallback() => Container(
        width: 50,
        height: 50,
        color: _C.paleTint,
        child: const Icon(Icons.restaurant, color: _C.primaryDk),
      );

  @override
  Widget build(BuildContext context) {
    if (_order == null) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.primary)),
      );
    }

    final restaurant   = _order!['restaurantName']    ?? 'Restaurant';
    final restAddress  = _order!['restaurantAddress'] ?? '';
    final restPhone    = (_order!['restaurantPhone'] as String?) ?? '';
    final customer     = _order!['customerName']      ?? '';
    final custAddress  = _order!['deliveryAddress']   ?? '';
    final customerNote = (_order!['deliveryInstructions'] as String?)?.trim() ?? '';
    final driverFee    = (_order!['driverFee']        ?? 0.0).toDouble();
    final distance     = _order!['distance']          ?? '2.4';
    final estMins      = _order!['estimatedMins']     ?? 12;
    final restImageUrl = _order!['restaurantImageUrl'] as String?;
    final items        = (_order!['items'] as List?)?.cast<Map>() ?? [];
    final step         = _step;
    final itemsSubtotal = items.fold<double>(
        0, (sum, item) => sum + ((item['price'] ?? 0.0) as num).toDouble());

    // Default map center — London if no location yet
    final restGeo      = _order!['restaurantLocation'];
    final initialCam   = restGeo is GeoPoint
        ? CameraPosition(target: LatLng(restGeo.latitude, restGeo.longitude), zoom: 14)
        : const CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 13);

    final statusLabels = ['Heading to Pickup', 'Picked Up', 'Delivered'];
    final currentLabel = statusLabels[step.clamp(0, 2)];

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Active Delivery',
            style: TextStyle(color: _C.navy, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _C.statusPillBg,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(currentLabel.toUpperCase(),
                style: const TextStyle(
                    color: _C.statusPillText, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress stepper ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ORDER STATUS',
                        style: TextStyle(
                            color: _C.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                    Text('Stage ${step + 1} of 3',
                        style: const TextStyle(
                            color: _C.primaryDk,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (i) {
                    final isDone   = i < step;
                    final isActive = i == step;
                    final icons = [
                      Icons.two_wheeler_rounded,
                      Icons.inventory_2_outlined,
                      Icons.home_outlined,
                    ];
                    final labels = ['Heading', 'Picked Up', 'Delivered'];
                    return Expanded(
                      child: Row(
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? _C.primaryDk
                                      : isActive
                                          ? const Color(0xFFBAE6FD)
                                          : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isDone ? Icons.check_rounded : icons[i],
                                  size: 16,
                                  color: isDone
                                      ? Colors.white
                                      : isActive
                                          ? _C.primaryDk
                                          : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(labels[i],
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: (isDone || isActive)
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: (isDone || isActive)
                                          ? _C.navy
                                          : _C.muted)),
                            ],
                          ),
                          if (i < 2)
                            Expanded(
                              child: Container(
                                height: 2.5,
                                margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                                color: i < step ? _C.primaryDk : _C.border,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // ── Live Google Map ───────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: GoogleMap(
                    initialCameraPosition: initialCam,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapType: MapType.normal,
                    onMapCreated: (ctrl) => _mapController = ctrl,
                  ),
                ),
                // Nav info + Launch GPS card
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _C.primary,
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
                                  style: TextStyle(color: _C.muted, fontSize: 11)),
                              Text(
                                step == 0 ? restaurant : customer,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _C.navy),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _launchNativeMaps(
                              step == 0 ? '$restaurant $restAddress' : '$customer $custAddress'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _C.paleTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.navigation_rounded, size: 14, color: _C.primaryDk),
                                SizedBox(width: 4),
                                Text('GPS',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: _C.primaryDk)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // My location button
                Positioned(
                  bottom: 12,
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
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.my_location, color: _C.primaryDk, size: 20),
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
                              // isNotEmpty matters as much as the null check:
                              // Firestore stores a missing image as "" far
                              // more often than as null, and Image.network("")
                              // throws. errorBuilder covers a URL that is set
                              // but unreachable.
                              child: (restImageUrl != null &&
                                      restImageUrl.trim().isNotEmpty)
                                  ? Image.network(restImageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _restaurantImageFallback())
                                  : _restaurantImageFallback(),
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
                                          color: _C.navy)),
                                  Text(restAddress,
                                      style: const TextStyle(
                                          color: _C.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            // ⚠ MOVED 7 September 2026. This chat icon used to sit
                            // here, but it opens FoodDeliveryChatScreen with
                            // customerName — it messages the CUSTOMER, not the
                            // restaurant. Having it next to the restaurant's own
                            // phone icon made it look like both buttons talked to
                            // the restaurant. Message now lives on the customer
                            // card below, next to Call, where the party it
                            // actually reaches matches what is on screen.
                            IconButton(
                              icon: const Icon(Icons.phone_outlined,
                                  color: _C.primaryDk, size: 22),
                              onPressed: restPhone.trim().isEmpty
                                  ? null
                                  : () => _callRestaurant(restPhone),
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
                                  ? _C.accent
                                  : const Color(0xFFF1F5F9),
                              foregroundColor:
                                  step == 0 ? Colors.white : _C.muted,
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
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: _C.paleTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_outline,
                                  color: _C.primaryDk, size: 22),
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
                                          color: _C.navy)),
                                  Text(custAddress,
                                      style: const TextStyle(
                                          color: _C.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            // Message — real, backed by order_chats, same
                            // 30-minute post-delivery window FoodDeliveryChatScreen
                            // already computes for itself. Moved here from the
                            // restaurant card above, since this is who it talks to.
                            IconButton(
                              icon: const Icon(Icons.chat_outlined,
                                  color: _C.primaryDk, size: 22),
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
                            // ⚠ FLAGGED 7 September 2026, DELIBERATELY DISABLED.
                            // There is no customerPhone anywhere on a food_orders
                            // document — only restaurantPhone. Real platforms never
                            // hand a driver the customer's raw personal number
                            // anyway; they proxy the call through a masked virtual
                            // number so neither side sees the other's real one.
                            // That needs a calling provider, which this project does
                            // not have yet. Per the agreed plan: sign up with
                            // Twilio for virtual-number calling first, then replace
                            // it with a native VOIP call later. Do not wire this to
                            // a raw tel: link to a customer's number in the
                            // meantime — that is a privacy regression, not a
                            // shortcut.
                            IconButton(
                              icon: const Icon(Icons.phone_outlined,
                                  color: Color(0xFFCBD5E1), size: 22),
                              tooltip: 'Calling opens once phone connect is set up',
                              onPressed: null,
                            ),
                          ],
                        ),
                        if (customerNote.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _C.softBox,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _C.softBoxBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.speaker_notes_outlined,
                                    size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('CUSTOMER NOTE',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFB45309),
                                              letterSpacing: 0.4)),
                                      const SizedBox(height: 2),
                                      Text('"$customerNote"',
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              fontStyle: FontStyle.italic,
                                              color: _C.navy,
                                              height: 1.35)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: step == 1 ? _markDelivered : null,
                            icon: Icon(Icons.local_shipping_outlined,
                                size: 18,
                                color: step == 1 ? Colors.white : const Color(0xFFCBD5E1)),
                            label: Text('MARK DELIVERED',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: step == 1 ? Colors.white : const Color(0xFFCBD5E1))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step == 1
                                  ? _C.success
                                  : const Color(0xFFF1F5F9),
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
                                  color: _C.primaryDk, size: 20),
                              const SizedBox(width: 10),
                              Text('Order Items (${items.length} items)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _C.navy)),
                              const Spacer(),
                              if (items.isNotEmpty)
                                Text('£${itemsSubtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _C.body,
                                        fontSize: 13)),
                              const SizedBox(width: 6),
                              Icon(
                                _itemsExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _C.muted,
                              ),
                            ],
                          ),
                          if (_itemsExpanded && items.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(color: _C.border),
                            ...items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Text('${item['quantity'] ?? 1}x',
                                          style: const TextStyle(
                                              color: _C.primaryDk,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(item['name'] ?? '',
                                              style: const TextStyle(color: _C.navy))),
                                      Text(
                                          '£${((item['price'] ?? 0.0) as num).toStringAsFixed(2)}',
                                          style:
                                              const TextStyle(color: _C.muted)),
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
          color: _C.surface,
          border: Border(top: BorderSide(color: _C.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bottomStat('GUARANTEED FEE',
                '£${driverFee.toStringAsFixed(2)}',
                color: _C.success),
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
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _bottomStat(String label, String value, {Color color = _C.navy}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _C.muted, fontSize: 9, letterSpacing: 0.6, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      );
}

// ── QR Scanner bottom sheet ───────────────────────────────────────────────────
class _QrScanSheet extends StatefulWidget {
  final ValueChanged<String> onScanned;
  const _QrScanSheet({required this.onScanned});

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  // RECONSTRUCTED: the file was truncated mid-word here, so this State class
  // was missing entirely and the app could not compile. _QrScanSheet is used
  // by _openQrScanner() to scan the pickup QR on a food order.
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Guard against the scanner firing repeatedly for the same code.
    if (_handled) return;
    final String raw = capture.barcodes.isNotEmpty
        ? (capture.barcodes.first.rawValue ?? '')
        : '';
    final String code = raw.trim();
    if (code.isEmpty) return;

    _handled = true;
    _controller.stop();
    widget.onScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.72;

    // The scanner keeps a dark sheet — the live camera preview needs a dark
    // surround for contrast, unlike the rest of this now-light screen.
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF0B1620),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Scan pickup QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: Text(
              'Point the camera at the QR code on the order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
