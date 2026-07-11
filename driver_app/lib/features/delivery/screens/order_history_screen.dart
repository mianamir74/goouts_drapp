import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        return {
          'id':         doc.id,
          'restaurant': d['restaurantName']  ?? 'Restaurant',
          'time':       _formatTime(d['deliveredAt']),
          'distance':   d['distance']        ?? '—',
          'amount':     (d['driverFee']      ?? 0.0).toDouble(),
          'tip':        (d['driverTip']      ?? 0.0).toDouble(),
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

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFF0b1a3d),
              child: const Icon(Icons.person, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Text('Order History',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
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
                      color: active
                          ? const Color(0xFF0392ca)
                          : const Color(0xFF0b1a3d),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: active
                            ? Colors.transparent
                            : Colors.white12,
                      ),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                            color: active ? Colors.white : Colors.white70,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14)),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Orders list ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0392ca)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFF0392ca),
                    child: _orders.isEmpty
                        ? _demoList()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18),
                            itemCount: _orders.length,
                            itemBuilder: (_, i) => _orderCard(_orders[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // Demo list shown when Firestore returns nothing
  Widget _demoList() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          _orderCard({
            'restaurant': 'Burger King - Downtown',
            'time': '10:45 AM',
            'distance': '2.4',
            'amount': 8.50,
            'tip': 2.00,
            'orderId': '8832',
            'cancelled': false,
          }),
          _orderCard({
            'restaurant': 'Starbucks - Uptown',
            'time': '09:15 AM',
            'distance': '1.1',
            'amount': 5.20,
            'tip': 1.50,
            'orderId': '8831',
            'cancelled': false,
          }),
          _orderCard({
            'restaurant': 'Taco Bell - Westside',
            'time': '08:30 AM',
            'distance': '3.5',
            'amount': 0.00,
            'tip': 0.0,
            'orderId': 'Customer request',
            'cancelled': true,
          }),
        ],
      );

  Widget _orderCard(Map<String, dynamic> o) {
    final cancelled = o['cancelled'] == true;
    final tip       = (o['tip'] ?? 0.0) as double;
    final amount    = (o['amount'] ?? 0.0) as double;
    final status    = cancelled ? 'Cancelled' : 'Completed';
    final statusColor = cancelled
        ? const Color(0xFFf43f5e)
        : const Color(0xFF10b981);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o['restaurant'] ?? '',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: cancelled
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white54)),
                    const SizedBox(height: 3),
                    Text(
                        '${o['time'] ?? '—'} • ${o['distance'] ?? '—'} mi',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cancelled ? '\$0.00' : '+\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cancelled
                            ? Colors.white54
                            : const Color(0xFF10b981)),
                  ),
                  if (tip > 0)
                    Text('incl. \$${tip.toStringAsFixed(2)} tip',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      cancelled
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
              Text(
                cancelled
                    ? (o['cancelReason']?.toString().isNotEmpty == true
                        ? o['cancelReason']
                        : 'Customer request')
                    : 'Order #${o['orderId']}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
