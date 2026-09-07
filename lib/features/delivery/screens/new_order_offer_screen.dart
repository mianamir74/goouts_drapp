import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'active_delivery_screen.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 13_new_order_offer_screen (the winning
//  pass — the other numbered-folder pass used a real map screenshot as the
//  route background, violating the "decorative route illustration only, not
//  a live tracking view" rule) as the visual reference.
//
//  ⚠ NOT carried over from the Stitch mockup, because none of it is a real
//  field on `food_orders`: the "High Surge" badge, the base-fee/tip
//  breakdown (no tip field exists anywhere in the schema), the full street
//  addresses, the pickup phone number, the "Buzz Apt 402" access note, and
//  the itemised manifest. This screen only shows what `widget.order` really
//  carries — restaurantName, cuisineType, driverFee, pickupDistance,
//  dropDistance, estimatedMins, dropPostcode, exclusive — reskinned to the
//  new visual language. The route card below is intentionally decorative
//  (two pins and a dashed line, not a real map), per the standing rule.
//
//  All real logic — the 30s countdown → auto-decline, the CRITICAL ACTION
//  SAFEGUARD asymmetric small-circular-decline / wide-accept button pair,
//  and the acceptFoodOrder / declineFoodOrder callable wiring — is
//  unchanged from before this pass.
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
  static const successBg = Color(0xFFDCFCE7);
  static const border    = Color(0xFFE2E8F0);
  static const softBox   = Color(0xFFF8FAFC);
  static const softBoxBorder = Color(0xFFEDF2F7);
}

class NewOrderOfferScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const NewOrderOfferScreen({super.key, required this.order});

  @override
  State<NewOrderOfferScreen> createState() => _NewOrderOfferScreenState();
}

class _NewOrderOfferScreenState extends State<NewOrderOfferScreen> {
  static const _timeoutSecs = 30;
  int _remaining = _timeoutSecs;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  // ⚠ Logic unchanged by the 7 September 2026 visual reskin. Was a direct
  // client-side food_orders.doc(id).update({...}) — firestore.rules has
  // always had `allow update: if false` on food_orders ("the callables
  // above only"), so every real driver tapping Accept on a real order hit
  // permission-denied here, silently caught by the try/catch below and
  // shown as a generic "Accept Failed" with no indication it could never
  // have worked. See food_dispatch.js for the real callable and why this
  // is a broadcast offer — another driver may win the race, and that
  // failure is now told to the driver honestly rather than folded into
  // "please try again".
  Future<void> _accept() async {
    _timer?.cancel();
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('acceptFoodOrder')
          .call({'orderId': widget.order['id']});
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(orderId: widget.order['id']),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final bool takenByAnother = e.code == 'failed-precondition';
      GoOutsSheet.error(
        context,
        title: takenByAnother ? 'Already Taken' : 'Accept Failed',
        message: takenByAnother
            ? 'Another driver got there first. We\'ll show you the next order.'
            : (e.message ?? 'Failed to accept order. Please try again.'),
      );
      if (takenByAnother && mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      GoOutsSheet.error(context, title: 'Accept Failed', message: 'Failed to accept order. Please try again.',
      );
    }
  }

  // ⚠ Logic unchanged by the 7 September 2026 visual reskin. declineFoodOrder
  // records this driver in declinedBy so the dashboard's offer query filters
  // it out; it does not need to be awaited before leaving this screen, and a
  // failure here must not trap the driver on a declined offer.
  void _decline() {
    _timer?.cancel();
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('declineFoodOrder')
        .call({'orderId': widget.order['id']})
        .catchError((_) {});
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

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Urgency banner ────────────────────────────────────────
              _urgencyBanner(isExclusive),
              const SizedBox(height: 12),

              // ── Guaranteed payout hero card ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOU\'LL EARN',
                        style: TextStyle(
                            color: _C.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('£${earnings.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: _C.navy,
                                letterSpacing: -1)),
                        const SizedBox(width: 8),
                        const Text('for this delivery',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _C.body)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Restaurant row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.softBox,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.softBoxBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _C.paleTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant_rounded,
                                color: _C.primaryDk, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(restaurant,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: _C.navy)),
                                Text(cuisine,
                                    style: const TextStyle(
                                        color: _C.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Decorative route card ─────────────────────────────────
              // Two pins and a dashed connector — decorative only, not a
              // live map. There is no restaurant/customer geocoding in the
              // schema yet, so a real route cannot be drawn.
              _routeCard(restaurant: restaurant, dropArea: dropArea),

              const SizedBox(height: 14),

              // ── Stats row (real fields only) ─────────────────────────
              Row(
                children: [
                  _stat(Icons.storefront_rounded, '$pickupDist mi', 'Pickup'),
                  const SizedBox(width: 8),
                  _stat(Icons.route_rounded, '${estMins}m', 'Journey'),
                  const SizedBox(width: 8),
                  _stat(Icons.location_on_rounded, '$dropArea', 'Dropoff'),
                ],
              ),

              const SizedBox(height: 20),

              // ── CRITICAL ACTION SAFEGUARD ─────────────────────────────
              // Small circular decline, wide prominent accept — mandatory
              // asymmetric pattern for any accept/decline decision, per
              // design/STITCH_6_DRAPP.md.
              Row(
                children: [
                  InkWell(
                    onTap: _decline,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: _C.navy, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accent,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: _C.accent.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('TAP TO ACCEPT',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white.withOpacity(0.9),
                                              letterSpacing: 0.5)),
                                      Text(
                                          'ACCEPT ORDER · £${earnings.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white)),
                                    ],
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Acceptance locks this order exclusively to your route.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: _C.muted),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urgencyBanner(bool isExclusive) {
    final progress = _remaining / _timeoutSecs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isExclusive ? _C.primary : const Color(0xFFB45309),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                        isExclusive ? 'ONLY FOR YOU' : 'BROADCAST OFFER',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isExclusive
                                ? _C.primaryDk
                                : const Color(0xFFB45309),
                            letterSpacing: 0.5)),
                    if (!isExclusive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Shared pool',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _C.body)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isExclusive
                      ? 'This order is reserved for you until the timer runs out.'
                      : 'First driver to tap accept gets the order.',
                  style: const TextStyle(fontSize: 12, color: _C.body),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: _C.orangeTint,
                  color: progress > 0.4 ? _C.accent : Colors.redAccent,
                ),
              ),
              Text('${_remaining}s',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeCard({required String restaurant, required String dropArea}) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 120),
            painter: _DashedRoutePainter(),
          ),
          Positioned(
            left: 20,
            bottom: 16,
            child: _routePin(
              icon: Icons.storefront_rounded,
              color: _C.primaryDk,
              label: restaurant,
            ),
          ),
          Positioned(
            right: 20,
            top: 14,
            child: _routePin(
              icon: Icons.location_on_rounded,
              color: _C.accentDk,
              label: '$dropArea',
            ),
          ),
        ],
      ),
    );
  }

  Widget _routePin({required IconData icon, required Color color, required String label}) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          constraints: const BoxConstraints(maxWidth: 100),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
            ],
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: _C.primaryDk),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: _C.navy)),
              Text(label,
                  style: const TextStyle(color: _C.muted, fontSize: 10)),
            ],
          ),
        ),
      );
}

// Decorative dashed line between the two pins — never a real map render.
class _DashedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.5,
          size.width * 0.84, size.height * 0.22);
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          p,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
