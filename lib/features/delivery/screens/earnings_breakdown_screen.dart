import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Weekly Fare Breakdown (rebuilt 22 October 2026)
//
//  Replaces the old mock-up (hardcoded £1,482.50, "+12.5% vs last week",
//  stock avatar). Laid out like the Uber driver "fare breakdown" so drivers
//  see exactly where every pound of the customer's delivery payment went:
//  You / GoOuts / Other (VAT and third party charges), then earnings, tips,
//  and the base fare that counts towards their sponsor's residual income.
//
//  Reads real delivered orders for the signed in driver, Monday to Sunday.
//  Per order fields used (all optional, missing = £0):
//    deliveryFee          what the customer paid for delivery (incl. VAT)
//    deliveryPromotion    delivery discount funded by GoOuts
//    vatOnDeliveryFee     VAT on the delivery fee, paid to HMRC
//    driverFeeBreakdown   {pickupFee, dropoffFee, distancePay, timePay,
//                          multiDropFee, baseFee,          ← base fare
//                          surgePay, promotionPay, boostPay, questPay,
//                          waitTimePay, tolls, adjustments} ← extras
//    driverFee            used as base fare when no breakdown exists
//    driverTip            customer tip, always 100% the driver's
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF2F4F7);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0392CA);
  static const navy = Color(0xFF0D1B3E);
  static const body = Color(0xFF475569);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const you = Color(0xFF2563EB);
  static const goouts = Color(0xFF111827);
  static const other = Color(0xFF14B8A6);
}

const _baseKeys = [
  'pickupFee', 'dropoffFee', 'distancePay', 'timePay', 'multiDropFee', 'baseFee',
];
const _surgeKeys = ['surgePay', 'promotionPay', 'boostPay', 'questPay'];

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

class _Week {
  double deliveryFees = 0;
  double promotions = 0;
  double vat = 0;
  double base = 0;
  double surge = 0;
  double wait = 0;
  double tolls = 0;
  double adjustments = 0;
  double tips = 0;
  int orders = 0;

  double get customerPayments => deliveryFees + promotions;
  double get fareEarnings => base + surge + wait + adjustments;
  double get otherFees => vat;
  double get gooutsKept => customerPayments - vat - fareEarnings - tolls;
  double get total => fareEarnings + tolls + tips;
}

class EarningsBreakdownScreen extends StatefulWidget {
  const EarningsBreakdownScreen({super.key});

  @override
  State<EarningsBreakdownScreen> createState() =>
      _EarningsBreakdownScreenState();
}

class _EarningsBreakdownScreenState extends State<EarningsBreakdownScreen> {
  late DateTime _weekStart;
  Future<_Week>? _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
    _load();
  }

  DateTime get _weekEnd =>
      DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7);

  bool get _isCurrentWeek => _weekEnd.isAfter(DateTime.now());

  void _load() {
    setState(() => _future = _fetch());
  }

  void _shift(int weeks) {
    _weekStart = DateTime(
        _weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks);
    _load();
  }

  Future<_Week> _fetch() async {
    final w = _Week();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return w;
    final snap = await FirebaseFirestore.instance
        .collection('food_orders')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_weekStart))
        .where('deliveredAt', isLessThan: Timestamp.fromDate(_weekEnd))
        .orderBy('deliveredAt', descending: true)
        .get();

    for (final doc in snap.docs) {
      final d = doc.data();
      w.orders++;
      w.deliveryFees += _n(d['deliveryFee']);
      w.promotions += _n(d['deliveryPromotion']);
      w.vat += _n(d['vatOnDeliveryFee']);
      w.tips += _n(d['driverTip']);
      final b = d['driverFeeBreakdown'];
      if (b is Map) {
        for (final k in _baseKeys) {
          w.base += _n(b[k]);
        }
        for (final k in _surgeKeys) {
          w.surge += _n(b[k]);
        }
        w.wait += _n(b['waitTimePay']);
        w.tolls += _n(b['tolls']);
        w.adjustments += _n(b['adjustments']);
      } else if (d['driverBaseFare'] != null) {
        w.base += _n(d['driverBaseFare']);
      } else {
        w.base += _n(d['driverFee']);
      }
    }
    return w;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _d(DateTime t) => '${t.day} ${_months[t.month - 1]}';

  String _money(double v, {bool sign = false}) {
    final s = '£${v.abs().toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
    if (!sign) return v < 0 ? '-$s' : s;
    return v < 0 ? '-$s' : '+$s';
  }

  @override
  Widget build(BuildContext context) {
    final lastDay =
        DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 6);
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Fare breakdown',
            style: TextStyle(
                color: _C.navy, fontWeight: FontWeight.w700, fontSize: 19)),
      ),
      body: Column(
        children: [
          Container(
            color: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: _C.navy),
                  onPressed: () => _shift(-1),
                ),
                Text('${_d(_weekStart)} - ${_d(lastDay)}',
                    style: const TextStyle(
                        color: _C.navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: _isCurrentWeek ? _C.border : _C.navy),
                  onPressed: _isCurrentWeek ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_Week>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(color: _C.primary));
                }
                if (snap.hasError) {
                  return _message(
                      'Could not load this week. Pull down to try again.');
                }
                final w = snap.data ?? _Week();
                return RefreshIndicator(
                  color: _C.primary,
                  onRefresh: () async => _load(),
                  child: w.orders == 0
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          _message('No completed deliveries this week.'),
                        ])
                      : _content(w),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String t) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.body, fontSize: 15)),
      );

  Widget _content(_Week w) {
    final pay = w.customerPayments;
    double pct(double v) => pay <= 0 ? 0 : (v / pay * 100);
    final kept = w.gooutsKept;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (pay > 0)
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: CustomPaint(
                painter: _Donut([
                  _Slice(math.max(0, w.fareEarnings), _C.you),
                  _Slice(math.max(0, kept), _C.goouts),
                  _Slice(math.max(0, w.otherFees), _C.other),
                ]),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _legend(_C.you, '${pct(w.fareEarnings).round()}% You'),
                      _legend(_C.goouts,
                          '${pct(math.max(0, kept)).round()}% GoOuts'),
                      _legend(_C.other, '${pct(w.otherFees).round()}% Other'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        _card([
          _row('Customer payments', _money(pay),
              sub: '${w.orders} deliveries', bold: true, trailing: '100%'),
          _row('Delivery fees paid by customers', _money(w.deliveryFees, sign: true),
              indent: true),
          if (w.promotions != 0)
            _row('Delivery promotions (paid by GoOuts)',
                _money(w.promotions, sign: true),
                indent: true),
          _row('of which VAT (paid to HMRC)', _money(w.vat), indent: true),
          const Divider(height: 22, color: _C.border),
          _row('Other: VAT paid to HMRC', _money(-w.otherFees),
              dot: _C.other, trailing: '${pct(w.otherFees).round()}%'),
          const Divider(height: 22, color: _C.border),
          _row(kept >= 0 ? 'Amount GoOuts kept' : 'Amount GoOuts added',
              kept >= 0 ? _money(-kept) : _money(-kept, sign: true),
              dot: _C.goouts,
              trailing: kept >= 0 ? '${pct(kept).round()}%' : null),
          const Divider(height: 22, color: _C.border),
          _row('Earnings from deliveries', _money(w.fareEarnings),
              dot: _C.you,
              bold: true,
              trailing: '${pct(w.fareEarnings).round()}%'),
          _row('Base fare', _money(w.base), indent: true),
          if (w.surge != 0)
            _row('Surge, boosts and promotions', _money(w.surge, sign: true),
                indent: true),
          if (w.wait != 0)
            _row('Wait time pay', _money(w.wait, sign: true), indent: true),
          if (w.adjustments != 0)
            _row('Adjustments', _money(w.adjustments, sign: true),
                indent: true),
          if (w.tolls != 0)
            _row('Tolls, Congestion Charge, ULEZ reimbursed',
                _money(w.tolls, sign: true)),
          _row('Tips', _money(w.tips, sign: true), sub: 'Always 100% yours'),
          const Divider(height: 22, thickness: 1.2, color: _C.navy),
          _row('Your total earnings', _money(w.total),
              sub: 'Including tips', bold: true),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F3FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Base fare this week: ${_money(w.base)}. This is the only part of '
            'your earnings that counts towards the residual income of the '
            'person who referred you. GoOuts pays that from its own share, so '
            'nothing is ever taken from your earnings. Tips, surge, boosts, '
            'wait time pay, tolls and adjustments are not counted.',
            style: const TextStyle(color: _C.body, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color c, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(t, style: const TextStyle(fontSize: 12.5, color: _C.navy)),
          ],
        ),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Column(children: children),
      );

  Widget _row(String label, String value,
      {String? sub,
      bool bold = false,
      bool indent = false,
      Color? dot,
      String? trailing}) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 22 : 0, top: 5, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: dot == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: dot, shape: BoxShape.circle)),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: indent ? _C.body : _C.navy,
                        fontSize: indent ? 13.5 : 14.5,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
                if (sub != null)
                  Text(sub,
                      style: const TextStyle(color: _C.muted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      color: _C.navy,
                      fontSize: indent ? 13.5 : 14.5,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
              if (trailing != null)
                Text(trailing,
                    style: const TextStyle(color: _C.muted, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slice {
  final double value;
  final Color color;
  const _Slice(this.value, this.color);
}

class _Donut extends CustomPainter {
  final List<_Slice> slices;
  _Donut(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    const stroke = 22.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2,
        size.width - stroke, size.height - stroke);
    double start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value / total * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.02,
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => true;
}
