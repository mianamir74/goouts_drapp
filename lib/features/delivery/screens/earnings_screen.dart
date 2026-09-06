import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'earnings_breakdown_screen.dart';
import 'weekly_residual_summary_screen.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _tab = 0; // 0 = Delivery Pay, 1 = Residual Income

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Delivery Pay data
  double _totalThisWeek   = 0;
  double _residualTotal   = 0;
  int    _driverReferrals = 0;
  int    _merchantReferrals = 0;
  double _driverResidual  = 0;
  double _merchantResidual = 0;
  List<Map<String, dynamic>> _recentTrips = [];
  List<Map<String, dynamic>> _driverRefs  = [];
  List<Map<String, dynamic>> _merchantRefs = [];
  bool _loading = true;
  bool _payoutLoading = false;
  double _pendingPayout = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Driver doc
    final driverDoc = await _db.collection('food_drivers').doc(uid).get();
    final d = driverDoc.data() ?? {};

    // Recent completed orders (last 5)
    final ordersSnap = await _db
        .collection('food_orders')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .orderBy('deliveredAt', descending: true)
        .limit(5)
        .get();

    // Referral sub-docs
    final driverRefsSnap = await _db
        .collection('food_drivers')
        .doc(uid)
        .collection('driverReferrals')
        .limit(10)
        .get();

    final merchantRefsSnap = await _db
        .collection('food_drivers')
        .doc(uid)
        .collection('merchantReferrals')
        .limit(10)
        .get();

    if (!mounted) return;
    setState(() {
      _totalThisWeek    = (d['weeklyEarnings']          as num?)?.toDouble() ?? 0.0;
      _residualTotal    = (d['residualTotal']            as num?)?.toDouble() ?? 0.0;
      _driverReferrals  = (d['driverReferralCount']      as int?) ?? 0;
      _merchantReferrals = (d['merchantReferralCount']   as int?) ?? 0;
      _driverResidual   = (d['driverResidualEarned']     as num?)?.toDouble() ?? 0.0;
      _merchantResidual = (d['merchantResidualEarned']   as num?)?.toDouble() ?? 0.0;
      _pendingPayout    = (d['pendingPayout']             as num?)?.toDouble() ?? 0.0;

      _recentTrips = ordersSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'restaurant': data['restaurantName'] ?? 'Restaurant',
          'address':    data['restaurantAddress'] ?? '',
          'time':       data['deliveredAt'],
          'distance':   data['distance'] ?? '—',
          'amount':     (data['driverFee'] ?? 0.0).toDouble(),
        };
      }).toList();

      _driverRefs = driverRefsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      _merchantRefs = merchantRefsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      _loading = false;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  INSTANT PAY IS NOT BUILT. Audited 4 August 2026.
  //
  //  This flow showed a driver a fee breakdown, a "Transfer Now" button, and
  //  on success the message "£X transferred to your bank. Arrives within 30
  //  minutes." It called `driverRequestInstantPayout`, WHICH DOES NOT EXIST,
  //  through FirebaseFunctions.instance — no region, so it defaulted to
  //  us-central1 while every GoOuts function is europe-west1. Wrong function,
  //  wrong region.
  //
  //  It failed safely, because a missing function throws and the catch showed
  //  "Transfer Failed". But the success path did this:
  //
  //      setState(() { _pendingPayout = 0; ... });
  //
  //  It zeroed the driver's pending balance in the UI on the strength of the
  //  call returning — before re-reading anything from the server. Any future
  //  function that resolved without actually moving money would have shown a
  //  driver a zero balance and a message saying it had reached their bank.
  //
  //  NOT FIXED BY BUILDING THE FUNCTION. Paying money into someone's bank
  //  account needs payment rails, verified bank details and a reconciliation
  //  path, none of which exist here. Writing a plausible-looking payout
  //  function would be the most dangerous thing in this repository.
  //
  //  So the button now says what is true. When the rails exist, delete this
  //  guard — do not delete the fee breakdown below it, which is still correct.
  // ───────────────────────────────────────────────────────────────────────────
  static const bool instantPayAvailable = false;

  // ── The payout terms, defined ONCE ─────────────────────────────────────────
  //
  // Set 4 August 2026 from the agreed model, which matches how Uber and
  // Deliveroo work:
  //
  //   * the weekly automatic transfer is FREE, on MONDAY
  //   * a driver may cash out their balance at any time for a £0.50 fee
  //
  // Applies to BOTH driver types in this app — food delivery and cab.
  //
  // SET FROM THE MARKET, checked 4 August 2026:
  //   Deliveroo  50p per cash-out, no published minimum, free weekly (Tuesday)
  //   Uber Eats  50p per instant cashout, free at 1-2 business days,
  //              £1,600 weekly cap on early withdrawal
  //
  // The screen said £1.00, which would have made GoOuts the most expensive of
  // the three. Drivers compare these directly — many work for all three on the
  // same shift — so being double the market on a fee they see every time they
  // cash out is not a small difference.
  //
  // The fee was hardcoded in three separate places that each had to agree: the
  // arithmetic, the fee-breakdown row, and the summary line under the button.
  // Three copies of a number a driver is charged is three chances to show one
  // figure and deduct another. One constant now feeds all of them.
  //
  // ⚠ These belong in platform_config, like the Short Stay economics, so they
  //   can be changed without an App Store release. Hardcoding a fee means
  //   changing it costs a review cycle. Raised as a follow-up, not done here.
  static const double instantPayFee = 0.50;

  // GoOuts pays weekly on Monday. Deliveroo uses Tuesday — that is their
  // operational choice, not a competitive term, so this stays as agreed.
  static const String weeklyPayoutDay = 'Monday';

  // NO FIXED MINIMUM, matching Deliveroo and Uber Eats.
  //
  // There was a £1.00 minimum against a £1.00 fee, so a driver cashing out the
  // smallest permitted amount received EXACTLY £0.00 — the screen would have
  // shown them "You receive £0.00" and taken the entire balance as the fee.
  //
  // Raising the minimum was one fix. Removing it is the better one, because it
  // is what the market actually does: Deliveroo lets a rider cash out their
  // current balance, whatever it is. The only rule that has to hold is that
  // the driver ends up with something, so the guard below refuses a cash-out
  // that would not clear the fee, rather than enforcing an arbitrary floor.
  static bool canCashOut(double balance) => balance > instantPayFee;

  // Uber caps early withdrawals at £1,600 a week — a float and fraud control,
  // not a fee. GoOuts needs an equivalent before instant pay goes live.
  //
  // NOT DECLARED AS A CONSTANT HERE, deliberately. It was, and the analyzer
  // correctly called it an unused field: a cap that no code reads enforces
  // nothing, and a named constant sitting in a screen file gives the false
  // impression that a limit exists.
  //
  // The check belongs in the payout Cloud Function, because a client-side cap
  // is advisory — anyone calling the function directly ignores it. The
  // requirement is recorded in the task list, which is where a requirement
  // with no implementation should live.

  Future<void> _requestInstantPayout() async {
    if (!instantPayAvailable) {
      GoOutsSheet.warning(
        context,
        title: 'Instant Pay is not available yet',
        message:
            'Your earnings are safe and are included in the weekly payout on '
            '$weeklyPayoutDay. Instant transfer is coming once bank payouts '
            'are live.',
      );
      return;
    }
    if (!canCashOut(_pendingPayout)) {
      // Deliberately phrased as what they'd receive, not as a rule they broke.
      GoOutsSheet.warning(context,
          title: 'Balance too low to cash out',
          message:
              'The £${instantPayFee.toStringAsFixed(2)} fee would take your '
              'whole balance. Your earnings transfer free every '
              '$weeklyPayoutDay.');
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0b1a3d),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Instant Transfer',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Builder(builder: (context) {
          final net =
              (_pendingPayout - instantPayFee).clamp(0.0, double.infinity);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fee breakdown
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF031134),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _feeRow('Your balance', '£${_pendingPayout.toStringAsFixed(2)}', Colors.white),
                    const SizedBox(height: 8),
                    _feeRow(
                        'GoOuts admin fee',
                        '- £${instantPayFee.toStringAsFixed(2)}',
                        const Color(0xFFf97316)),
                    const Divider(color: Colors.white12, height: 20),
                    _feeRow('You receive', '£${net.toStringAsFixed(2)}', const Color(0xFF10b981), bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Before 17:30 Mon-Fri your money arrives immediately. '
                'Otherwise it lands the next working day.\n'
                'Your weekly transfer on $weeklyPayoutDay is always free.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              ),
            ],
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10b981),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Transfer Now',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _payoutLoading = true);
    try {
      // europe-west1. This was FirebaseFunctions.instance with no region,
      // which defaults to us-central1 — so even once the function exists it
      // would not have been found.
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('driverRequestInstantPayout');
      final result = await fn.call();
      if (!mounted) return;
      setState(() => _payoutLoading = false);

      // The balance is NOT zeroed here any more.
      //
      // It used to be set to 0 the instant the call returned. A function that
      // resolved without actually moving the money — a partial failure, a
      // provider timeout treated as success — would have shown the driver a
      // zero balance and told them it had reached their bank. _load() re-reads
      // the real figure from the server, which is the only number worth
      // showing for somebody's wages.
      final net = result.data['netAmount'];
      GoOutsSheet.success(
        context,
        title: 'Transfer requested',
        message: net is num
            ? '£${net.toStringAsFixed(2)} is on its way to your bank. '
                'Your balance will update once it settles.'
            : 'Your transfer has been requested.',
      );
      await _load(); // authoritative balance, from the server
    } catch (e) {
      if (!mounted) return;
      setState(() => _payoutLoading = false);
      // Was GoOutsSheet.success titled 'Transferred!' on the FAILURE path,
      // and terminated with ',' instead of ';'.
      GoOutsSheet.error(
        context,
        title: 'Transfer Failed',
        message: 'Transfer failed: $e',
      );
    }
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
        children: [
          // ── Tab toggle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _tabBtn('DELIVERY PAY', 0),
                  _tabBtn('RESIDUAL INCOME', 1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0392ca)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFF0392ca),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _tab == 0
                          ? _buildDeliveryPay()
                          : _buildResidualIncome(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? idx == 1
                    ? const Color(0xFFf97316)
                    : const Color(0xFF031134)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active && idx == 0
                ? Border.all(
                    color: const Color(0xFF0392ca).withOpacity(0.5))
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12)),
        ),
      ),
    );
  }

  // ── Delivery Pay tab ────────────────────────────────────────────────
  Widget _buildDeliveryPay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total this week card
        Container(
          padding: const EdgeInsets.all(18),
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
                  const Text('TOTAL EARNED THIS WEEK',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 0.8)),
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.white24, size: 22),
                ],
              ),
              const SizedBox(height: 6),
              Text('\$${_totalThisWeek.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10b981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up,
                        color: Color(0xFF10b981), size: 14),
                    SizedBox(width: 4),
                    Text('+12% vs last week',
                        style: TextStyle(
                            color: Color(0xFF10b981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Instant Pay ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AVAILABLE TO TRANSFER',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                letterSpacing: 0.6)),
                        const SizedBox(height: 2),
                        Text(
                          '£${_pendingPayout.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10b981)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                            '£${instantPayFee.toStringAsFixed(2)} admin fee applies · Weekly free',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed:
                          _payoutLoading ? null : _requestInstantPayout,
                      icon: _payoutLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.bolt, size: 18),
                      label: const Text('Instant Pay',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                            text: 'Standard Payout: ',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                        TextSpan(
                            text: 'Tue, Oct 24',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const EarningsBreakdownScreen()),
                    ),
                    child: const Text('Details',
                        style: TextStyle(
                            color: Color(0xFF0392ca),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RESIDUAL GROWTH TREND',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 0.5)),
                  const Text('+24% MoM',
                      style: TextStyle(
                          color: Color(0xFF10b981),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Earnings bar chart
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0b1a3d),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings Breakdown',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white)),
              const SizedBox(height: 20),
              SizedBox(
                height: 90,
                child: _MiniBarChart(
                    data: const [42, 58, 65, 84, 71, 38, 20],
                    todayIdx: 3),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .asMap()
                    .entries
                    .map((e) => Text(e.value,
                        style: TextStyle(
                            color: e.key == 3
                                ? const Color(0xFF0392ca)
                                : Colors.white38,
                            fontSize: 10,
                            fontWeight: e.key == 3
                                ? FontWeight.bold
                                : FontWeight.normal)))
                    .toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Recent trips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Trips',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            const Icon(Icons.tune, color: Colors.white54, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentTrips.isEmpty)
          ...[
            _tripCard(
              restaurant: 'Burger King - Main St',
              time: 'Today, 2:15 PM',
              distance: '3.2 mi',
              amount: 12.50,
            ),
          ]
        else
          ..._recentTrips.map((t) => _tripCard(
                restaurant: t['restaurant'],
                time: 'Today',
                distance: '${t['distance']} mi',
                amount: t['amount'],
              )),
      ],
    );
  }

  Widget _tripCard({
    required String restaurant,
    required String time,
    required String distance,
    required double amount,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF031134),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: Color(0xFF0392ca), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14)),
                  Text('$time • $distance',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Text('\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10b981),
                    fontSize: 16)),
          ],
        ),
      );

  // ── Fee breakdown row helper ────────────────────────────────────────
  Widget _feeRow(String label, String value, Color valueColor,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: bold ? 15 : 13,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  // ── Residual Income tab ─────────────────────────────────────────────
  Widget _buildResidualIncome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total passive income
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0b1a3d),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('TOTAL PASSIVE INCOME',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Text('\$${_residualTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                'Earn a percentage of revenue from drivers\nand merchants you refer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white38, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const WeeklyResidualSummaryScreen()),
                  ),
                  icon: const Icon(Icons.bar_chart,
                      color: Color(0xFFf97316), size: 16),
                  label: const Text('View Weekly Summary',
                      style: TextStyle(
                          color: Color(0xFFf97316),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                            const Color(0xFFf97316).withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  // Drivers box
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF031134),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.people_outline,
                                color: Color(0xFFf97316), size: 16),
                            const SizedBox(width: 6),
                            const Text('DRIVERS',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 6),
                          Text('$_driverReferrals Referred',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14)),
                          Text(
                              '\$${_driverResidual.toStringAsFixed(0)} total',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Merchants box
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF031134),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.storefront_outlined,
                                color: Color(0xFF0392ca), size: 16),
                            const SizedBox(width: 6),
                            const Text('MERCHANTS',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 6),
                          Text('$_merchantReferrals Referred',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14)),
                          Text(
                              '\$${_merchantResidual.toStringAsFixed(0)} total',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // My Driver Referrals
        _sectionHeader('MY DRIVER REFERRALS',
            badge: '${_driverReferrals > 0 ? _driverReferrals : 2} Active'),
        const SizedBox(height: 10),
        if (_driverRefs.isEmpty) ...[
          _referralItem(
              name: 'Alex Johnson',
              subtitle: 'Active • New last Sat',
              amount: '+\$45.20',
              avatarColor: Colors.purpleAccent.shade100),
          _referralItem(
              name: 'Sarah Miller',
              subtitle: 'Active • New last Sat',
              amount: '+\$12.80',
              initials: 'SM',
              avatarColor: Colors.teal),
        ] else
          ..._driverRefs.map((r) => _referralItem(
                name: r['name'] ?? 'Driver',
                subtitle: 'Active',
                amount: '+\$${(r['earned'] ?? 0.0).toStringAsFixed(2)}',
              )),

        const SizedBox(height: 16),

        _sectionHeader('MY MERCHANT REFERRALS',
            badge: '${_merchantReferrals > 0 ? _merchantReferrals : 1} Active'),
        const SizedBox(height: 10),
        if (_merchantRefs.isEmpty)
          _referralItem(
              name: "Joe's Pizza Corner",
              subtitle: 'No orders • New last Tue',
              amount: '+\$184.00',
              isShop: true)
        else
          ..._merchantRefs.map((r) => _referralItem(
                name: r['name'] ?? 'Merchant',
                subtitle: 'Active',
                amount: '+\$${(r['earned'] ?? 0.0).toStringAsFixed(2)}',
                isShop: true,
              )),

        const SizedBox(height: 20),

        // CTA buttons
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Invite a Driver',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Sign Up a Merchant',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionHeader(String title, {String? badge}) => Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const Spacer(),
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10b981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      color: Color(0xFF10b981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      );

  Widget _referralItem({
    required String name,
    required String subtitle,
    required String amount,
    String? initials,
    Color avatarColor = const Color(0xFF0392ca),
    bool isShop = false,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isShop
                  ? const Color(0xFF031134)
                  : avatarColor.withOpacity(0.3),
              child: isShop
                  ? const Icon(Icons.storefront,
                      color: Color(0xFF0392ca), size: 20)
                  : Text(
                      initials ??
                          (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                      style: TextStyle(
                          color: avatarColor,
                          fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Text(amount,
                style: const TextStyle(
                    color: Color(0xFF10b981),
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
      );
}

// ── Small bar chart for weekly ────────────────────────────────────────────────
class _MiniBarChart extends StatelessWidget {
  final List<double> data;
  final int todayIdx;
  const _MiniBarChart({required this.data, required this.todayIdx});

  @override
  Widget build(BuildContext context) {
    final max = data.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: data.asMap().entries.map((e) {
        final isToday = e.key == todayIdx;
        final h = max > 0 ? (e.value / max) * 80 : 0.0;
        return Container(
          width: 24,
          height: h,
          decoration: BoxDecoration(
            color: isToday
                ? const Color(0xFF0392ca)
                : const Color(0xFF0392ca).withOpacity(0.25),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        );
      }).toList(),
    );
  }
}
