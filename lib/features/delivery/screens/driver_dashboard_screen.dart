import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'new_order_offer_screen.dart';
import 'active_delivery_screen.dart';
import 'dashboard_heatmap_screen.dart';
import 'trip_radar_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 05_driver_dashboard_screen (the
//  "home_dispatch" Stitch pass) as the visual reference. All real Firestore
//  wiring below is unchanged from before this pass — only the widget tree
//  changed. See individual ⚠ comments for what was deliberately left out of
//  the Stitch mockup or changed from it.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F4F7);
  static const surface   = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF0392CA);
  static const navy      = Color(0xFF0D1B3E);
  static const accent    = Color(0xFFF97316);
  static const paleTint  = Color(0xFFE0F3FB);
  static const body      = Color(0xFF475569);
  static const muted     = Color(0xFF94A3B8);
  static const success   = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const warning   = Color(0xFFF59E0B);
  static const error     = Color(0xFFEF4444);
  static const errorBg   = Color(0xFFFEE2E2);
}

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool   _isOnline       = false;
  bool   _loadingToggle  = false;
  Map<String, dynamic>? _driverData;

  // ⚠ TWO SEPARATE THINGS, SPLIT 6 September 2026. Both used to be one
  // "_pendingOrder" fed by one query that, before that day, could never
  // actually match anything (see _listenForOrders' own comment). Fixing the
  // query surfaced that the single field was doing two different jobs:
  //
  //   _availableOffer  a broadcast order nobody has accepted yet — pops the
  //                     full-screen NewOrderOfferScreen, is not "mine" until
  //                     I tap Accept, and must never render as though it is
  //                     already my job.
  //   _activeOrder     an order I HAVE accepted — drives the inline
  //                     "Active order" card on this dashboard, tracked
  //                     independently of the online toggle because being
  //                     mid-delivery does not stop just because I go offline.
  Map<String, dynamic>? _activeOrder;
  StreamSubscription? _orderSub;
  StreamSubscription? _activeOrderSub;

  int    _deliveriesToday  = 0;
  double _earnedToday      = 0;
  double _hoursOnline      = 0;
  double _weeklyEarnings   = 0;
  double _acceptanceRate   = 94;
  double _cancellationRate = 2;
  double _rating           = 4.9;

  static const _activeStatuses = {
    'driver_heading_to_restaurant',
    'driver_picked_up',
  };

  @override
  void initState() {
    super.initState();
    _loadDriver();
    _listenForActiveOrder();
  }

  @override
  void dispose() {
    _activeOrderSub?.cancel();
    _orderSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDriver() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('food_drivers').doc(uid).get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    setState(() {
      _driverData       = data;
      _isOnline         = data['isOnline']         ?? false;
      _deliveriesToday  = data['deliveriesToday']   ?? 0;
      _earnedToday      = (data['earnedToday']      ?? 0).toDouble();
      _hoursOnline      = (data['hoursOnline']      ?? 0).toDouble();
      // ⚠ FIXED 7 September 2026. The old dashboard drew a 7-day bar chart
      // from a hardcoded [42, 58, 65, 84, 71, 38, 20] list — fake numbers
      // with no Firestore field behind them at all, on every driver's
      // screen, always. weeklyEarnings is a real field (protected in
      // firestore.rules, driver-can't-self-edit), it just was not read
      // here. A per-day breakdown still does not exist anywhere in the
      // schema, so this shows the one real weekly total instead of
      // inventing seven fake daily ones — see earnings_screen.dart for
      // where a real per-delivery breakdown is shown.
      _weeklyEarnings   = (data['weeklyEarnings']   ?? 0).toDouble();
      _acceptanceRate   = (data['acceptanceRate']   ?? 94).toDouble();
      _cancellationRate = (data['cancellationRate'] ?? 2).toDouble();
      _rating           = (data['rating']           ?? 4.9).toDouble();
    });
    // Only a driver who is actually online should be woken up with new-order
    // offers. _listenForOrders() itself has no online check — it is this
    // call site's job to decide when it runs, same as _toggleOnline below.
    if (_isOnline) _listenForOrders();
  }

  // Runs regardless of the online toggle — a driver who is mid-delivery is
  // still mid-delivery if they flip themselves offline, and needs to keep
  // seeing the job. where('driverId','==',uid) alone, no orderBy, no second
  // equality clause: single-field, no composite index, status filtered in
  // Dart, same trade-off this codebase makes everywhere a small per-driver
  // result set makes it cheap.
  void _listenForActiveOrder() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _activeOrderSub = _db
        .collection('food_orders')
        .where('driverId', isEqualTo: uid)
        .limit(10)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final active = snap.docs.where(
          (d) => _activeStatuses.contains(d.data()['status']));
      setState(() {
        _activeOrder = active.isEmpty
            ? null
            : {'id': active.first.id, ...active.first.data()};
      });
    });
  }

  // This is a broadcast model: every online driver watches the same pool of
  // pending, unassigned orders. Firestore's live listener naturally drops an
  // order from every OTHER driver's results the instant one driver accepts
  // it (driverId stops being null), so no separate "somebody else took it"
  // signal is needed here — only inside acceptFoodOrder's own transaction,
  // for the driver who is mid-tap when that happens.
  //
  // declinedBy is filtered in Dart, not in the query — Firestore has no
  // "array does not contain" filter, and it does not need one here: every
  // document this query is allowed to return already satisfies
  // firestore.rules' own read rule (status pending, driverId null), so
  // narrowing further client-side changes nothing about what was authorised.
  //
  // ⚠ SUPPRESSED WHILE _activeOrder IS SET. A driver already mid-delivery
  // must not be interrupted with a second offer — they cannot act on it
  // until the first job is done anyway, and the full-screen offer dialog
  // would cover the active-delivery screen they are supposed to be using.
  void _listenForOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _orderSub?.cancel(); // guard against double-subscribing
    _orderSub = _db
        .collection('food_orders')
        .where('status', isEqualTo: 'pending')
        .where('driverId', isEqualTo: null)
        .limit(20)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (_activeOrder != null) return;
      final candidates = snap.docs.where((d) {
        final declinedBy = (d.data()['declinedBy'] as List?) ?? const [];
        return !declinedBy.contains(uid);
      });
      if (candidates.isNotEmpty) {
        final doc = candidates.first;
        final order = {'id': doc.id, ...doc.data()};
        if (!_offerShowing) _showOrderOffer(order);
      }
    });
  }

  bool _offerShowing = false;

  void _showOrderOffer(Map<String, dynamic> order) {
    if (_offerShowing) return;
    _offerShowing = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewOrderOfferScreen(order: order),
        fullscreenDialog: true,
      ),
    ).whenComplete(() => _offerShowing = false);
  }

  Future<void> _toggleOnline(bool value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingToggle = true);
    try {
      await _db.collection('food_drivers').doc(uid).set(
        {'isOnline': value},
        SetOptions(merge: true),
      );
      setState(() {
        _isOnline      = value;
        _loadingToggle = false;
      });
      if (value) {
        _listenForOrders();
      } else {
        _orderSub?.cancel();
        _orderSub = null;
      }
    } catch (_) {
      setState(() => _loadingToggle = false);
    }
  }

  Future<void> _callSos() async {
    await launchUrl(Uri(scheme: 'tel', path: '999'));
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name  = (_driverData?['name'] as String?)?.trim() ?? '';
    final photo = _driverData?['profilePhotoUrl'] as String?;
    final firstName = name.isEmpty ? 'Driver' : name.split(' ').first;
    final pace = _hoursOnline > 0 ? _earnedToday / _hoursOnline : 0.0;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        title: const Text('GoOuts Driver',
            style: TextStyle(
                color: _C.navy, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _C.paleTint,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(firstName[0].toUpperCase(),
                      style: const TextStyle(
                          color: _C.primary, fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _C.primary,
        onRefresh: _loadDriver,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Greeting + online toggle ────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('COURIER ACTIVE',
                                style: TextStyle(
                                    color: _C.muted,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${_greeting()}, $firstName',
                                style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: _C.navy)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _C.paleTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            const Icon(Icons.star_rounded,
                                size: 15, color: _C.warning),
                            const SizedBox(width: 4),
                            Text(_rating.toStringAsFixed(2),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _C.navy)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isOnline ? _C.success : _C.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _isOnline
                                        ? 'READY FOR DISPATCH'
                                        : 'OFFLINE',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _C.navy,
                                        letterSpacing: 0.3)),
                                const SizedBox(height: 2),
                                Text(
                                  _isOnline
                                      ? 'Broadcasting open orders to you'
                                      : 'Go online to start receiving offers',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: _C.body),
                                ),
                              ],
                            ),
                          ),
                          _loadingToggle
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _C.primary))
                              : Switch.adaptive(
                                  value: _isOnline,
                                  activeThumbColor: _C.success,
                                  onChanged: _toggleOnline,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Active order card (if assigned) ─────────────────────────
              if (_activeOrder != null) ...[
                _ActiveOrderCard(order: _activeOrder!),
                const SizedBox(height: 12),
              ],

              // ── Today's earnings ─────────────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 18, color: _C.primary),
                      SizedBox(width: 8),
                      Text("Today's earnings",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _C.navy)),
                    ]),
                    const SizedBox(height: 10),
                    Text('£${_earnedToday.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: _C.navy,
                            letterSpacing: -1)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metric('Deliveries', '$_deliveriesToday',
                              'today'),
                          _vDivider(),
                          _metric('Online',
                              '${_hoursOnline.toStringAsFixed(1)}h',
                              'this shift'),
                          _vDivider(),
                          _metric('Pace', '£${pace.toStringAsFixed(2)}',
                              'per hour'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekly total',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: _C.navy)),
                        Text('£${_weeklyEarnings.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _C.navy)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Performance mini stats ──────────────────────────────────
              Row(children: [
                Expanded(
                    child: _miniStat(Icons.thumb_up_outlined, 'Acceptance',
                        '${_acceptanceRate.toInt()}%', _C.success)),
                const SizedBox(width: 8),
                Expanded(
                    child: _miniStat(Icons.cancel_outlined, 'Cancellation',
                        '${_cancellationRate.toInt()}%', _C.error)),
                const SizedBox(width: 8),
                Expanded(
                    child: _miniStat(Icons.star_rounded, 'Rating',
                        _rating.toStringAsFixed(1), _C.warning)),
              ]),

              const SizedBox(height: 12),

              // ── Busy zones — honestly not built yet ─────────────────────
              // ⚠ FIXED 7 September 2026. Used to be two separate things: a
              // CustomPaint "map" with the literal string "Google Maps here"
              // painted on it, and, in one Stitch pass, a "Peak Demand
              // Ahead" card with an invented "1.2x Boost" and a specific
              // named zone — neither backed by anything. There is no
              // order-volume history anywhere in this app yet (it has only
              // run on seeded test data), so any zone or time-window claim
              // right now would be made up. One honest coming-soon card
              // instead of two fabricated ones.
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DashboardHeatmapScreen()),
                ),
                child: _card(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _C.paleTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_fire_department,
                            color: _C.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Busy zones near you',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: _C.navy)),
                            SizedBox(height: 2),
                            Text(
                              'Coming soon — we are building real demand data for your area.',
                              style: TextStyle(color: _C.body, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: _C.muted),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Instant cash out — coming soon, real amount ─────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Instant cash out',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _C.navy)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _C.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Coming soon',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _C.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _C.paleTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.account_balance_outlined,
                            color: _C.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Cash out £${_earnedToday.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: _C.primary)),
                        ),
                        const Icon(Icons.lock_outline_rounded,
                            size: 16, color: _C.muted),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'A real payout method has not been set up yet. Once it is, instant cash out will be available here.',
                      style: TextStyle(fontSize: 11.5, color: _C.body, height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Emergency SOS ────────────────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.shield_outlined, size: 18, color: _C.error),
                      SizedBox(width: 8),
                      Text('Safety & assistance',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _C.navy)),
                    ]),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _callSos,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: _C.errorBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.phone_in_talk_rounded,
                              color: _C.error, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Emergency SOS',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: _C.error)),
                          ),
                          const Text('Dial 999',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _C.error)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Opens your phone dialler with 999 ready to call. GoOuts does not automatically contact emergency services or share your location.',
                      style: TextStyle(fontSize: 11.5, color: _C.body, height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Trip Radar quick access ─────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TripRadarScreen()),
                ),
                child: _card(
                  child: Row(children: [
                    const Icon(Icons.radar, color: _C.primary, size: 28),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trip Radar',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _C.navy)),
                          Text('Browse nearby available orders',
                              style: TextStyle(color: _C.body, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _C.muted),
                  ]),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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

  Widget _metric(String label, String value, String sublabel) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _C.muted)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _C.navy)),
          const SizedBox(height: 1),
          Text(sublabel,
              style: const TextStyle(fontSize: 10.5, color: _C.muted)),
        ],
      );

  Widget _vDivider() => Container(width: 1, height: 32, color: const Color(0xFFE2E8F0));

  Widget _miniStat(IconData icon, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: _C.muted, fontSize: 9)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          ],
        ),
      );
}

// ── Active order card widget ─────────────────────────────────────────────────
class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final restaurant = order['restaurantName'] as String? ?? 'Restaurant';
    final address    = order['restaurantAddress'] as String? ?? '';
    final fee        = (order['driverFee'] ?? 0.0).toDouble();
    final status     = order['status'] as String? ?? '';
    final orderId    = order['id'] as String? ?? '';
    final statusLabel = status == 'driver_picked_up'
        ? 'Picked up · heading to customer'
        : 'Heading to restaurant';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ActiveDeliveryScreen(orderId: orderId)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.primary.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.paleTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: const TextStyle(
                        color: _C.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text('£${fee.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _C.navy)),
            ]),
            const SizedBox(height: 10),
            Text(restaurant,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: _C.navy)),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(color: _C.body, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ActiveDeliveryScreen(orderId: orderId)),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View active delivery',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
