import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rewired 9 September 2026. Every number on this screen used to be hardcoded
//  Stitch-mockup filler (£482.50, "+12%", "42 active referrals", a 7-day bar
//  chart, and a "Top Performers" leaderboard naming two people —
//  "Marcus Thompson" and "Golden Fork Bistro" — who do not exist). That was
//  fine as a UI-build placeholder, but this screen is reachable from a real
//  driver's earnings tab, so it must show that driver's real numbers now.
//
//  This screen no longer fetches anything itself — earnings_screen.dart
//  already loads exactly this data (food_drivers/{uid} plus the
//  driverReferrals/merchantReferrals subcollections) for its own Residual
//  Income tab, so the caller passes it straight through. That avoids a
//  second, possibly-inconsistent Firestore read for the same numbers a
//  driver just saw on the screen before this one.
//
//  REMOVED, not faked with a "coming soon" placeholder either:
//    - The Weekly/Monthly toggle and "+12%" trend — there is no per-period
//      residual history anywhere in the schema, only running totals
//      (residualTotal, driverResidualEarned, merchantResidualEarned,
//      pendingPayout on food_drivers/{uid}). A trend needs two points in
//      time; only one exists.
//    - The 7-day "Residual Growth" bar chart — same reason.
//    - "Top Performers" — even once real, this would mean showing one
//      driver another driver's or merchant's earnings, which is someone
//      else's financial data. Replaced with THIS driver's own referral
//      list, which is the real equivalent of what that section was trying
//      to show.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F4F7);
  static const surface   = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy      = Color(0xFF0D1B3E);
  static const accent    = Color(0xFFF97316);
  static const paleTint  = Color(0xFFE0F3FB);
  static const body      = Color(0xFF475569);
  static const muted     = Color(0xFF94A3B8);
  static const success   = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const border    = Color(0xFFE2E8F0);
}

class WeeklyResidualSummaryScreen extends StatelessWidget {
  const WeeklyResidualSummaryScreen({
    super.key,
    required this.residualTotal,
    required this.pendingPayout,
    required this.driverReferralCount,
    required this.merchantReferralCount,
    required this.driverResidualEarned,
    required this.merchantResidualEarned,
    required this.driverRefs,
    required this.merchantRefs,
  });

  final double residualTotal;
  final double pendingPayout;
  final int driverReferralCount;
  final int merchantReferralCount;
  final double driverResidualEarned;
  final double merchantResidualEarned;
  final List<Map<String, dynamic>> driverRefs;
  final List<Map<String, dynamic>> merchantRefs;

  void _onShare() {
    final totalReferrals = driverReferralCount + merchantReferralCount;
    final buffer = StringBuffer()
      ..writeln('My GoOuts residual income')
      ..writeln('Total earned: £${residualTotal.toStringAsFixed(2)}')
      ..writeln('From $totalReferrals referral${totalReferrals == 1 ? '' : 's'} '
          '($driverReferralCount driver${driverReferralCount == 1 ? '' : 's'}, '
          '$merchantReferralCount merchant${merchantReferralCount == 1 ? '' : 's'})');
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final totalReferrals = driverReferralCount + merchantReferralCount;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Residual Summary',
            style: TextStyle(
                color: _C.navy, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Total residual earned ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(18),
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
                  const Text('TOTAL RESIDUAL EARNED',
                      style: TextStyle(
                          color: _C.muted,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text('£${residualTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: _C.navy,
                          letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text(
                    totalReferrals == 0
                        ? 'No referrals yet.'
                        : 'Calculated from $totalReferrals referral${totalReferrals == 1 ? '' : 's'}.',
                    style: const TextStyle(color: _C.body, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending payout',
                            style: TextStyle(
                                color: _C.body,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text('£${pendingPayout.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: _C.success,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Referral breakdown ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _referralCard(
                    'Driver Referrals',
                    '$driverReferralCount Referred',
                    '£${driverResidualEarned.toStringAsFixed(2)}',
                    _C.primary,
                    Icons.local_shipping,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _referralCard(
                    'Merchant Referrals',
                    '$merchantReferralCount Referred',
                    '£${merchantResidualEarned.toStringAsFixed(2)}',
                    _C.accent,
                    Icons.storefront,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Honest note replacing the fake growth chart ──────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.paleTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: _C.primaryDk),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Day-by-day residual history isn\'t tracked yet — the '
                      'totals above are accurate as of right now.',
                      style: TextStyle(
                          fontSize: 12, color: _C.body, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Your referrals — real people, not a fake leaderboard ─
            const Text('Your Driver Referrals',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _C.navy)),
            const SizedBox(height: 10),
            if (driverRefs.isEmpty)
              _emptyState('No driver referrals yet.')
            else
              ...driverRefs.map((r) => _referralItem(
                    name: (r['name'] as String?) ?? 'Driver',
                    amount: '+£${((r['earned'] as num?) ?? 0).toStringAsFixed(2)}',
                  )),

            const SizedBox(height: 20),

            const Text('Your Merchant Referrals',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _C.navy)),
            const SizedBox(height: 10),
            if (merchantRefs.isEmpty)
              _emptyState('No merchant referrals yet.')
            else
              ...merchantRefs.map((r) => _referralItem(
                    name: (r['name'] as String?) ?? 'Merchant',
                    amount: '+£${((r['earned'] as num?) ?? 0).toStringAsFixed(2)}',
                    isShop: true,
                  )),

            const SizedBox(height: 24),

            // ── Share button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _onShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _referralCard(String title, String subtitle, String amount,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: _C.navy)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _C.muted, fontSize: 11)),
          const SizedBox(height: 10),
          Text(amount,
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _emptyState(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: _C.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: _C.muted, fontSize: 13))),
        ]),
      );

  Widget _referralItem({
    required String name,
    required String amount,
    bool isShop = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isShop
                ? _C.paleTint
                : _C.primary.withOpacity(0.15),
            child: isShop
                ? const Icon(Icons.storefront, color: _C.primaryDk, size: 18)
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: _C.primary, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: _C.navy)),
          ),
          Text(amount,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: _C.success)),
        ],
      ),
    );
  }
}
