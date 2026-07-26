import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'active_delivery_screen.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class NewOrderOfferScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const NewOrderOfferScreen({super.key, required this.order});

  @override
  State<NewOrderOfferScreen> createState() => _NewOrderOfferScreenState();
}

class _NewOrderOfferScreenState extends State<NewOrderOfferScreen>
    with SingleTickerProviderStateMixin {
  static const _timeoutSecs = 30;
  int _remaining = _timeoutSecs;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        _decline();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    _timer?.cancel();
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await FirebaseFirestore.instance
          .collection('food_orders')
          .doc(widget.order['id'])
          .update({'status': 'driver_heading_to_restaurant', 'driverId': uid});
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(orderId: widget.order['id']),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      GoOutsSheet.error(context, title: 'Accept Failed', message: 'Failed to accept order. Please try again.',
      );
    }
  }

  void _decline() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final restaurant  = o['restaurantName']  ?? 'Restaurant';
    final cuisine     = o['cuisineType']     ?? 'Food';
    final earnings    = (o['driverFee']      ?? 0.0).toDouble();
    final pickupDist  = o['pickupDistance']  ?? '—';
    final dropDist    = o['dropDistance']    ?? '—';
    final estMins     = o['estimatedMins']   ?? '—';
    final dropArea    = o['dropPostcode']    ?? '—';
    final isExclusive = o['exclusive']       ?? false;

    final progress = _remaining / _timeoutSecs;

    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      body: Stack(
        children: [
          // Subtle grid bg
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0b1a3d),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Timer row ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Circular countdown
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white10,
                                  color: progress > 0.4
                                      ? const Color(0xFF0392ca)
                                      : Colors.redAccent,
                                ),
                                Text('$_remaining',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),

                          // Exclusive / shared badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isExclusive
                                  ? const Color(0xFF0392ca).withOpacity(0.2)
                                  : Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isExclusive ? Icons.stars : Icons.group,
                                  size: 14,
                                  color: isExclusive
                                      ? const Color(0xFF0392ca)
                                      : Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isExclusive ? 'ONLY FOR YOU' : 'SHARED OFFER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isExclusive
                                        ? const Color(0xFF0392ca)
                                        : Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Earnings ───────────────────────────────────────────
                      const Text("You'll earn",
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        '£${earnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10b981),
                        ),
                      ),
                      const Text(
                        'FOR THIS DELIVERY',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Restaurant card ────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000b2d),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF0b1a3d),
                              child: const Icon(Icons.restaurant,
                                  color: Color(0xFF0392ca), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(restaurant,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(cuisine,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Stats row ──────────────────────────────────────────
                      Row(
                        children: [
                          _stat(Icons.directions_car,
                              '$pickupDist mi', 'Pickup'),
                          const SizedBox(width: 8),
                          _stat(Icons.route, '${estMins}m', 'Journey'),
                          const SizedBox(width: 8),
                          _stat(Icons.location_on, '$dropArea', 'Dropoff'),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Accept ─────────────────────────────────────────────
                      ElevatedButton(
                        onPressed: _loading ? null : _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10b981),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline),
                                  SizedBox(width: 8),
                                  Text('ACCEPT DELIVERY',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                      ),

                      const SizedBox(height: 12),

                      // ── Decline ────────────────────────────────────────────
                      OutlinedButton(
                        onPressed: _decline,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white12),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          foregroundColor: Colors.white54,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 18),
                            SizedBox(width: 8),
                            Text('DECLINE',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF000b2d),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0392ca)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF0392ca).withOpacity(0.04)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
