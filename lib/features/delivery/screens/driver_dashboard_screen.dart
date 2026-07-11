import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'new_order_offer_screen.dart';
import 'dashboard_heatmap_screen.dart';
import 'trip_radar_screen.dart';

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
  Map<String, dynamic>? _pendingOrder;
  StreamSubscription? _orderSub;

  int    _deliveriesToday = 0;
  double _earnedToday     = 0;
  double _tipsToday       = 0;
  double _hoursOnline     = 0;
  double _acceptanceRate  = 94;
  double _cancellationRate = 2;
  double _rating          = 4.9;

  // Weekly bar chart data (Mon–Sun)
  final List<double> _weeklyEarnings = [42, 58, 65, 84, 71, 38, 20];

  @override
  void initState() {
    super.initState();
    _loadDriver();
    _listenForOrders();
  }

  @override
  void dispose() {
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
      _isOnline         = data['isOnline']        ?? false;
      _deliveriesToday  = data['deliveriesToday']  ?? 0;
      _earnedToday      = (data['earnedToday']     ?? 0).toDouble();
      _tipsToday        = (data['tipsToday']       ?? 0).toDouble();
      _hoursOnline      = (data['hoursOnline']     ?? 0).toDouble();
      _acceptanceRate   = (data['acceptanceRate']  ?? 94).toDouble();
      _cancellationRate = (data['cancellationRate'] ?? 2).toDouble();
      _rating           = (data['rating']          ?? 4.9).toDouble();
    });
  }

  void _listenForOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // Listen for orders assigned to this driver OR broadcast pending orders
    _orderSub = _db
        .collection('food_orders')
        .where('status', whereIn: ['driver_assigned', 'pending'])
        .where('driverId', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isNotEmpty) {
        final order = {'id': snap.docs.first.id, ...snap.docs.first.data()};
        setState(() => _pendingOrder = order);
        if (!_offerShowing) _showOrderOffer(order);
      } else {
        setState(() => _pendingOrder = null);
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
        _isOnline     = value;
        _loadingToggle = false;
      });
    } catch (_) {
      setState(() => _loadingToggle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name  = _driverData?['name'] as String? ?? 'Driver';
    final photo = _driverData?['profilePhotoUrl'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('GoOuts Driver',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0b1a3d),
              backgroundImage:
                  photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0392ca),
        onRefresh: _loadDriver,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── CURRENT STATUS ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('CURRENT STATUS',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    // Toggle pill
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF031134),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          // OFFLINE
                          Expanded(
                            child: GestureDetector(
                              onTap: _loadingToggle
                                  ? null
                                  : () => _toggleOnline(false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_isOnline
                                      ? Colors.transparent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text('OFFLINE',
                                    style: TextStyle(
                                        color: !_isOnline
                                            ? Colors.white70
                                            : Colors.white38,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ),
                            ),
                          ),
                          // ONLINE
                          Expanded(
                            child: GestureDetector(
                              onTap: _loadingToggle
                                  ? null
                                  : () => _toggleOnline(true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isOnline
                                      ? const Color(0xFF10b981)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: _loadingToggle
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Text('ONLINE',
                                        style: TextStyle(
                                            color: _isOnline
                                                ? Colors.white
                                                : Colors.white38,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on,
                            size: 14,
                            color: _isOnline
                                ? const Color(0xFF10b981)
                                : Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          _isOnline
                              ? 'Receiving orders'
                              : 'You are offline',
                          style: TextStyle(
                              color: _isOnline
                                  ? const Color(0xFF10b981)
                                  : Colors.white38,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Active order card (if assigned) ────────────────────────
              if (_pendingOrder != null) ...[
                _ActiveOrderCard(order: _pendingOrder!),
                const SizedBox(height: 16),
              ],

              // ── Busy Zones / Map ───────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Color(0xFFf97316), size: 20),
                          const SizedBox(width: 8),
                          const Text('Busy Zones Near You',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const DashboardHeatmapScreen()),
                            ),
                            child: const Text('View Full',
                                style: TextStyle(
                                    color: Color(0xFF0392ca),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.my_location,
                              color: Colors.white54, size: 18),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                      child: Container(
                        height: 200,
                        color: const Color(0xFF0d1f4a),
                        child: CustomPaint(
                          painter: _MapPlaceholderPainter(),
                          child: const Center(
                            child: Text('Google Maps here',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Stats grid ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child: _statTile(
                          'Deliveries', '$_deliveriesToday')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _statTile(
                          'Hours Online',
                          '${_hoursOnline.toStringAsFixed(1)}h')),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Earned Today',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('£${_earnedToday.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10b981))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Tips',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('£${_tipsToday.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Mini stats row ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child: _miniStat(Icons.thumb_up_outlined,
                          'Acceptance',
                          '${_acceptanceRate.toInt()}%',
                          const Color(0xFF10b981))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _miniStat(Icons.cancel_outlined,
                          'Cancellation',
                          '${_cancellationRate.toInt()}%',
                          const Color(0xFFf43f5e))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _miniStat(Icons.star,
                          'Rating',
                          _rating.toStringAsFixed(1),
                          Colors.amber)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Weekly Earnings chart ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekly Earnings',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                        GestureDetector(
                          onTap: () {},
                          child: const Text('View All',
                              style: TextStyle(
                                  color: Color(0xFF0392ca),
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 100,
                      child: _WeeklyBarChart(data: _weeklyEarnings),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                          .asMap()
                          .entries
                          .map((e) => Text(e.value,
                              style: TextStyle(
                                  color: e.key == 3
                                      ? const Color(0xFF0392ca)
                                      : Colors.white38,
                                  fontSize: 11,
                                  fontWeight: e.key == 3
                                      ? FontWeight.bold
                                      : FontWeight.normal)))
                          .toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Trip Radar quick-access ────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TripRadarScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0b1a3d),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF0392ca).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.radar,
                          color: Color(0xFF0392ca), size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trip Radar',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white)),
                            Text('Browse nearby available orders',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white24),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(String title, String value) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      );

  Widget _miniStat(
          IconData icon, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 9)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15)),
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
    final restaurant = order['restaurantName'] ?? 'Restaurant';
    final address    = order['restaurantAddress'] ?? '';
    final customer   = order['customerName'] ?? '';
    final notes      = order['deliveryNotes'] ?? 'Leave at door';
    final fee        = (order['driverFee'] ?? 0.0).toDouble();
    final estMins    = order['estimatedMins'] ?? 12;
    final orderId    = order['id'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0392ca).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0392ca).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'NEW ORDER #${orderId.length > 4 ? orderId.substring(orderId.length - 4).toUpperCase() : orderId}',
                  style: const TextStyle(
                      color: Color(0xFF0392ca),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('£${fee.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10b981))),
                Text('Est. $estMins mins',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          Text(restaurant,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Expanded(
                child: Text(address,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13))),
          ]),
          const SizedBox(height: 10),
          // Dropoff customer
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF031134),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFf97316),
                child: Text(
                  customer.isNotEmpty ? customer[0].toUpperCase() : 'C',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dropoff: $customer',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(notes,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('Navigate to Restaurant',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly bar chart ─────────────────────────────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<double> data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    const todayIdx = 3; // Thursday (0-based)

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: data.asMap().entries.map((e) {
        final isToday = e.key == todayIdx;
        final frac    = maxVal > 0 ? e.value / maxVal : 0.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isToday)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0392ca).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('£${e.value.toInt()}',
                      style: const TextStyle(
                          color: Color(0xFF0392ca),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              width: 28,
              height: 80 * frac,
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF0392ca)
                    : const Color(0xFFf97316).withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6)),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Map placeholder painter ──────────────────────────────────────────────────
class _MapPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF0392ca).withOpacity(0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Hot zones
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.55),
        44, Paint()..color = Colors.redAccent.withOpacity(0.13));
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.38),
        30, Paint()..color = Colors.redAccent.withOpacity(0.10));
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.7),
        20, Paint()..color = Colors.amber.withOpacity(0.10));
  }

  @override
  bool shouldRepaint(_) => false;
}
