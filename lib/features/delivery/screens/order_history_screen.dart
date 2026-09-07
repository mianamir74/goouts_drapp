import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 06_order_history_screen as the visual
//  reference.
//
//  ⚠ FIXED 7 September 2026. `_demoList()` used to render three entirely
//  fake orders (Burger King, Starbucks, Taco Bell — with a fake cancelled
//  Taco Bell order) permanently whenever a driver's real order list was
//  empty, in $ when the rest of the app is £. Same "flag, don't fake"
//  pattern already fixed in earnings_screen.dart and referral_link_screen
//  earlier this session. Replaced with an honest empty state.
//
//  ⚠ NOT carried over from the Stitch mockup: the "£412.80 October
//  Activity" summary card with its 6-bar sparkline (no per-day earnings
//  breakdown exists — see driver_dashboard_screen.dart's identical note),
//  the fare-breakdown modal's "Base Trip Fare" / "Dynamic Demand Boost"
//  split (there is one flat `driverFee` field, not a base+boost split —
//  see design/DRIVER_PAY_ALGORITHM_SPEC.md), and the "£0.00 (0%) Platform
//  Courier Fee" claim (whether GoOuts takes a commission at all is an open
//  business decision, not a settled fact). The activity summary below is
//  computed instead from the real orders this screen already loads, and
//  the breakdown modal only shows the two fields that are real: delivery
//  fee and tip.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const softBlueBg = Color(0xFFEFF5FD);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const success  = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const error    = Color(0xFFEF4444);
  static const border   = Color(0xFFE2E8F0);
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  int _filterIdx = 0; // 0=Today, 1=This Week, 2=This Month
  final _filters = ['Today', 'This Week', 'This Month'];

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final now  = DateTime.now();
    final from = _filterIdx == 0
        ? DateTime(now.year, now.month, now.day)
        : _filterIdx == 1
            ? now.subtract(const Duration(days: 7))
            : DateTime(now.year, now.month, 1);

    final snap = await _db
        .collection('food_orders')
        .where('driverId', isEqualTo: uid)
        .where('deliveredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('deliveredAt', descending: true)
        .limit(30)
        .get();

    if (!mounted) return;
    setState(() {
      _orders = snap.docs.map((doc) {
        final d = doc.data();
        final items = (d['items'] as List?)?.cast<Map>() ?? const [];
        return {
          'id':         doc.id,
          'restaurant': d['restaurantName']  ?? 'Restaurant',
          'time':       _formatTime(d['deliveredAt']),
          'distance':   d['distance']        ?? '—',
          'amount':     (d['driverFee']      ?? 0.0).toDouble(),
          'tip':        (d['driverTip']      ?? 0.0).toDouble(),
          'itemCount':  items.length,
          'orderId':    d['orderId']         ?? doc.id.substring(0, 4).toUpperCase(),
          'status':     d['status']          ?? 'delivered',
          'cancelled':  d['status'] == 'cancelled',
          'cancelReason': d['cancelReason']  ?? '',
        };
      }).toList();
      _loading = false;
    });
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '—';
    final dt = (ts as Timestamp).toDate();
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  void _showBreakdown(Map<String, dynamic> o) {
    final amount = (o['amount'] ?? 0.0) as double;
    final tip    = (o['tip'] ?? 0.0) as double;
    final total  = amount + tip;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o['restaurant'] ?? '',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: _C.navy)),
                      const SizedBox(height: 2),
                      Text('${o['orderId']} • ${o['time']}',
                          style: const TextStyle(fontSize: 12.5, color: _C.body)),
                    ],
                  ),
                ),
                Text('£${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: _C.navy)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            _fareRow('Delivery fee', '£${amount.toStringAsFixed(2)}'),
            if (tip > 0) ...[
              const SizedBox(height: 8),
              _fareRow('Customer tip', '+£${tip.toStringAsFixed(2)}'),
            ],
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total paid to you',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _C.navy)),
                Text('£${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _C.primary)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fareRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: _C.body)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: _C.navy)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final delivered = _orders.where((o) => o['cancelled'] != true).toList();
    final totalEarned = delivered.fold<double>(
        0, (sum, o) => sum + (o['amount'] as double) + (o['tip'] as double));
    final avgPerDrop = delivered.isNotEmpty ? totalEarned / delivered.length : 0.0;

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
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: _C.paleTint,
              child: const Icon(Icons.person, color: _C.primary, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Text('Order History',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _C.navy)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Text('Your delivered and cancelled orders',
                style: TextStyle(fontSize: 13, color: _C.body)),
          ),

          // ── Filter chips ─────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: _filters.asMap().entries.map((e) {
                final active = _filterIdx == e.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _filterIdx = e.key);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 11),
                    decoration: BoxDecoration(
                      color: active ? _C.primary : _C.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: active ? Colors.transparent : _C.border,
                      ),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                            color: active ? Colors.white : _C.body,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14)),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // ── Activity summary (computed from real loaded orders) ─────
          if (!_loading && _orders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _C.softBlueBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month_outlined,
                            color: _C.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_filters[_filterIdx].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _C.body,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text('${delivered.length} deliveries',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: _C.navy)),
                        ],
                      ),
                    ]),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Earned',
                            style: TextStyle(fontSize: 12, color: _C.body)),
                        Text('£${totalEarned.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _C.navy,
                                letterSpacing: -0.5)),
                        if (delivered.isNotEmpty)
                          Text('Avg £${avgPerDrop.toStringAsFixed(2)} / drop',
                              style: const TextStyle(fontSize: 11.5, color: _C.muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),

          // ── Orders list ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _C.primary,
                    child: _orders.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            itemCount: _orders.length,
                            itemBuilder: (_, i) => _orderCard(_orders[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
        children: [
          Column(
            children: const [
              Icon(Icons.receipt_long_outlined, size: 40, color: _C.muted),
              SizedBox(height: 12),
              Text('No orders in this period',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _C.navy)),
              SizedBox(height: 4),
              Text('Delivered and cancelled orders will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _C.muted)),
            ],
          ),
        ],
      );

  Widget _orderCard(Map<String, dynamic> o) {
    final cancelled = o['cancelled'] == true;
    final tip       = (o['tip'] ?? 0.0) as double;
    final amount    = (o['amount'] ?? 0.0) as double;
    final itemCount = (o['itemCount'] ?? 0) as int;
    final status    = cancelled ? 'Cancelled' : 'Delivered';
    final statusColor = cancelled ? _C.error : _C.success;
    final statusBg     = cancelled ? const Color(0xFFFEE2E2) : _C.successBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _C.softBlueBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: _C.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o['restaurant'] ?? '',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.navy,
                            decoration: cancelled ? TextDecoration.lineThrough : null,
                            decorationColor: _C.muted)),
                    const SizedBox(height: 2),
                    Text('${o['time'] ?? '—'}  •  Order #${o['orderId']}',
                        style: const TextStyle(color: _C.body, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cancelled ? '£0.00' : '£${(amount + tip).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cancelled ? _C.muted : _C.navy),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          if (!cancelled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 15, color: _C.body),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemCount > 0 ? '$itemCount item${itemCount == 1 ? '' : 's'}' : 'Order details',
                      style: const TextStyle(fontSize: 12.5, color: _C.body),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: _C.muted),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tip > 0 ? 'Includes £${tip.toStringAsFixed(2)} tip' : 'Delivery fee',
                    style: const TextStyle(fontSize: 12, color: _C.body)),
                GestureDetector(
                  onTap: () => _showBreakdown(o),
                  child: Row(children: const [
                    Icon(Icons.receipt_long_rounded, size: 14, color: _C.primary),
                    SizedBox(width: 4),
                    Text('View breakdown',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.primary)),
                  ]),
                ),
              ],
            ),
          ] else if ((o['cancelReason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(o['cancelReason'],
                style: const TextStyle(color: _C.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
