import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'achievements_grid_screen.dart';
import 'active_delivery_mini_bar.dart';
import 'weekly_recap_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  New 7 September 2026, built from 19_rewards_home_screen as a loose visual
//  reference. Dark theme is the DELIBERATE, explicitly-scoped exception for
//  the Rewards area (screens 19-24) per design/STITCH_6_DRAPP.md — the rest
//  of the app is light theme.
//
//  The Stitch reference is unusually candid about which of its own fields
//  are real vs. invented — it labels several "PROTOTYPE FIELD" in its own
//  comments (streakCount, gamificationTier/xpTotal, driver_badges
//  subcollection, a Monday aggregator cron for the weekly recap). None of
//  those exist in this app's schema. Rather than build them or fake them:
//   - The hero "12 day streak" card is replaced with an honest "Coming
//     soon" notice — there is no `streakCount`/`lastActiveDate` tracking
//     anywhere, so there is nothing true to show instead.
//   - The "Silver Driver, 340/500 to Gold, 10% surge bonus" progression
//     card is replaced with the driver's REAL `tier` field and nothing
//     invented under it — no fake point totals, no fake unlock rewards.
//   - "This Week in Numbers" is REAL: computed live from the driver's own
//     `food_orders` (driverId == uid, delivered in the last 7 days), not
//     hardcoded. No fake "+14% vs last week" — that would need a second
//     query for the prior week, and isn't worth doubling the read cost for
//     a number this screen can't otherwise back up.
//   - Achievements preview links to achievements_grid_screen.dart, which
//     computes real rule-based badges from existing driver stats (no new
//     `driver_badges` subcollection needed).
//   - "Open Weekly Recap" links to weekly_recap_screen.dart, which computes
//     a real recap client-side from the driver's own order history — no
//     cron/aggregator required.
//   - The docked mini bar is the real ActiveDeliveryMiniBar widget (see
//     active_delivery_mini_bar.dart) and simply doesn't render if the
//     driver has no active delivery, rather than always showing a fake one.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF031134);
  static const card      = Color(0xFF0B1A3D);
  static const primary   = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const accent    = Color(0xFFF97316);
  static const success   = Color(0xFF16A34A);
  static const textMuted = Color(0xFF94A3B8);
}

class RewardsHomeScreen extends StatefulWidget {
  const RewardsHomeScreen({super.key});

  @override
  State<RewardsHomeScreen> createState() => _RewardsHomeScreenState();
}

class _RewardsHomeScreenState extends State<RewardsHomeScreen> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _loadFailed = false;
  String _tier = 'Bronze';
  int _weekDeliveries = 0;
  double _weekEarnings = 0;
  double _weekTips = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loadFailed = false);
    try {
      final driverDoc = await _db.collection('food_drivers').doc(uid).get();
      final weekAgo   = DateTime.now().subtract(const Duration(days: 7));
      final ordersSnap = await _db
          .collection('food_orders')
          .where('driverId', isEqualTo: uid)
          .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .orderBy('deliveredAt', descending: true)
          .limit(200)
          .get();

      int deliveries = 0;
      double earnings = 0;
      double tips = 0;
      for (final doc in ordersSnap.docs) {
        final d = doc.data();
        if ((d['status'] as String?) != 'delivered') continue;
        deliveries++;
        earnings += (d['driverFee'] ?? 0.0).toDouble();
        earnings += (d['driverTip'] ?? 0.0).toDouble();
        tips += (d['driverTip'] ?? 0.0).toDouble();
      }

      if (!mounted) return;
      setState(() {
        _tier = (driverDoc.data()?['tier'] as String?) ?? 'Bronze';
        _weekDeliveries = deliveries;
        _weekEarnings = earnings;
        _weekTips = tips;
        _loading = false;
      });
    } catch (_) {
      // ⚠ FIXED 8 September 2026, found in the post-build failure-mode
      // review — this used to silently show an empty/zeroed screen on any
      // load failure (offline, missing index, permission error), which
      // looks identical to "you genuinely have no deliveries this week"
      // rather than "something went wrong". Now shows a real retry state.
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Your Progress',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.primary))
            : _loadFailed
                ? _errorState()
                : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _comingSoonStreakCard(),
                        const SizedBox(height: 20),
                        _tierCard(),
                        const SizedBox(height: 28),
                        const Text('This Week in Numbers',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
                        const SizedBox(height: 12),
                        _statsRow(),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Badges & Achievements',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsGridScreen())),
                              child: const Row(children: [
                                Text('View all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.primary)),
                                Icon(Icons.chevron_right_rounded, size: 16, color: _C.primary),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _achievementsTeaser(),
                        const SizedBox(height: 28),
                        _weeklyRecapCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16, right: 16, bottom: 14,
                    child: const ActiveDeliveryMiniBar(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _C.textMuted, size: 34),
            const SizedBox(height: 14),
            const Text('Couldn\'t load your progress', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Check your connection and try again.', style: TextStyle(color: _C.textMuted, fontSize: 13)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () { setState(() => _loading = true); _load(); },
              style: ElevatedButton.styleFrom(backgroundColor: _C.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comingSoonStreakCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: _C.accent.withOpacity(0.18), shape: BoxShape.circle),
            child: const Icon(Icons.local_fire_department_rounded, color: _C.accent, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily streaks', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 3),
                Text('Coming soon — we\'ll track your delivery streak here.', style: TextStyle(fontSize: 12.5, color: _C.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _C.primary.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.military_tech_rounded, color: _C.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_tier Driver', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                const Text('Tier progression details — coming soon', style: TextStyle(fontSize: 12, color: _C.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _statCard(headline: '$_weekDeliveries', label: 'Deliveries completed', icon: Icons.two_wheeler_rounded),
          const SizedBox(width: 12),
          _statCard(
            headline: '£${_weekEarnings.toStringAsFixed(2)}',
            label: 'Total earned this week',
            subtext: _weekTips > 0 ? 'incl. £${_weekTips.toStringAsFixed(2)} tips (100% kept)' : null,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statCard({required String headline, required String label, String? subtext, required IconData icon}) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _C.primary),
          const SizedBox(height: 12),
          Text(headline, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext, style: const TextStyle(fontSize: 11.5, color: _C.success, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _achievementsTeaser() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsGridScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_rounded, color: _C.textMuted, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text('See which achievements you\'ve unlocked so far',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            Icon(Icons.chevron_right_rounded, color: _C.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _weeklyRecapCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E1035), _C.card, Color(0xFF2A1508)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your week in delivery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          const Text('See your top restaurant, busiest hour, and how much you earned — all from your real order history.',
              style: TextStyle(fontSize: 13, color: _C.textMuted, height: 1.35)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyRecapScreen())),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text('Open Weekly Recap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.accent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
