import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'active_delivery_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  New 7 September 2026, built from 20_active_delivery_mini_bar as a loose
//  visual reference. Docked persistent mini bar — the DELIBERATE light-theme
//  exception inside the otherwise-dark Rewards area (per
//  design/STITCH_6_DRAPP.md), so it visually matches the 5 core light
//  screens even when shown inside rewards_home_screen.dart.
//
//  Not carried over from the Stitch mockup: the hardcoded "Honest Burgers
//  Soho • ETA 6 mins" — this widget now does a real one-time Firestore read
//  for the signed-in driver's own in-flight order (status
//  driver_heading_to_restaurant / driver_picked_up) and renders nothing at
//  all if there isn't one, rather than always showing a fake active
//  delivery. No ETA is shown — no ETA is computed anywhere in this app.
//
//  Deliberately a one-time `.get()`, not a `.snapshots()` listener: this bar
//  can be embedded on more than one screen at once (e.g. Rewards Home), and
//  a live listener per embed would mean N duplicate open Firestore listeners
//  for the same query. Callers that already have the driver's active-order
//  data in hand (e.g. a future dashboard rebuild) should prefer passing it
//  in via [order] instead of letting this widget re-query.
// ─────────────────────────────────────────────────────────────────────────────
class ActiveDeliveryMiniBar extends StatefulWidget {
  /// Optional pre-fetched order map (must include 'orderId' and
  /// 'restaurantName' keys) to avoid a duplicate query when the parent
  /// screen already has this data loaded.
  final Map<String, dynamic>? order;

  const ActiveDeliveryMiniBar({super.key, this.order});

  @override
  State<ActiveDeliveryMiniBar> createState() => _ActiveDeliveryMiniBarState();
}

class _ActiveDeliveryMiniBarState extends State<ActiveDeliveryMiniBar> {
  static const _activeStatuses = ['driver_heading_to_restaurant', 'driver_picked_up'];

  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _order = widget.order;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('food_orders')
          .where('driverId', isEqualTo: uid)
          .where('status', whereIn: _activeStatuses)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        _order = snap.docs.isEmpty
            ? null
            : {'orderId': snap.docs.first.id, ...snap.docs.first.data()};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) return const SizedBox.shrink();

    final orderId    = _order!['orderId'] as String? ?? '';
    final restaurant  = _order!['restaurantName'] as String? ?? 'Restaurant';
    final status      = _order!['status'] as String? ?? '';
    final statusLabel = status == 'driver_picked_up' ? 'PICKED UP' : 'HEADING TO PICKUP';

    return GestureDetector(
      onTap: () {
        if (orderId.isEmpty) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(orderId: orderId),
        ));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF006488), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFDCEBFA), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusLabel,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7), letterSpacing: 0.4)),
                  ),
                  const SizedBox(height: 2),
                  Text(restaurant,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0D1B3E), letterSpacing: -0.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0D1B3E), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
