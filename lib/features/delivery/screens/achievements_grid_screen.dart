import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  New 7 September 2026, built from 22_achievements_grid_screen as a loose
//  visual reference. Dark theme — deliberate Rewards-area exception.
//
//  The Stitch reference is upfront that its whole badge system needs a
//  `driver_badges` subcollection with unlock-event triggers that doesn't
//  exist ("PROTOTYPE FIELD" notice at the bottom of its own file) — along
//  with fake earned dates ("Earned 14 Feb 2025"), a fake XP/rank system
//  (+250 XP, "Gold Master", "Top 14%"), and a 5-tab bottom nav for
//  Quests/Perks/Tiers/Wallet that don't exist anywhere in this app.
//
//  None of that is carried over. Instead, every badge below is computed
//  live from real `food_drivers` fields the driver already has —
//  totalDeliveries, rating, acceptanceRate, tier, driverReferralCount — so
//  "unlocked" always means "true right now", not a stored unlock event. No
//  XP, no earned-on date (this app doesn't track when a threshold was
//  crossed), no percentile ranking against other drivers (see
//  leaderboard_screen.dart for why that's a real backend gap, not just a
//  missing UI).
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF031134);
  static const card      = Color(0xFF0B1A3D);
  static const lockedBg  = Color(0x660B1A3D);
  static const primary   = Color(0xFF0392CA);
  static const success   = Color(0xFF16A34A);
  static const textMuted = Color(0xFF94A3B8);
  static const track     = Color(0x26FFFFFF);
}

class _Achievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final num current;
  final num target;
  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.current,
    required this.target,
  });
  bool get isUnlocked => current >= target;
}

class AchievementsGridScreen extends StatefulWidget {
  const AchievementsGridScreen({super.key});

  @override
  State<AchievementsGridScreen> createState() => _AchievementsGridScreenState();
}

class _AchievementsGridScreenState extends State<AchievementsGridScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  List<_Achievement> _achievements = [];
  String _tier = 'Bronze';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loadFailed = false);
    try {
      final doc = await FirebaseFirestore.instance.collection('food_drivers').doc(uid).get();
      final d = doc.data() ?? {};
      final totalDeliveries = (d['totalDeliveries'] ?? 0) as int;
      final rating = (d['rating'] ?? 0).toDouble();
      final acceptanceRate = (d['acceptanceRate'] ?? 0).toDouble();
      final referrals = (d['driverReferralCount'] ?? 0) as int;
      final tier = (d['tier'] as String?) ?? 'Bronze';

      // ⚠ ADDED 8 September 2026, building the Food Delivery Drivers admin
      // section. These six numbers used to be hardcoded here — an admin
      // wanting to change "First 50" to "First 40" needed an app release.
      // config/food_driver_rewards now holds the real values; this is a
      // BEST-EFFORT read on its own try/catch, separate from the food_drivers
      // read above, so a config outage degrades to the shipped defaults
      // rather than blanking the whole achievements screen — the same
      // "flag don't fake, but don't fail the page either" rule applied
      // everywhere else this session.
      num first50 = 50, first250 = 250, fiveStar = 4.8, reliableRate = 90, teamBuilder = 5;
      String goldTierName = 'Gold';
      try {
        final cfgDoc = await FirebaseFirestore.instance
            .collection('config').doc('food_driver_rewards').get();
        final at = cfgDoc.data()?['achievementThresholds'];
        if (at is Map) {
          first50 = (at['first50Deliveries'] as num?) ?? first50;
          first250 = (at['first250Deliveries'] as num?) ?? first250;
          fiveStar = (at['fiveStarRating'] as num?) ?? fiveStar;
          reliableRate = (at['reliableAcceptanceRate'] as num?) ?? reliableRate;
          teamBuilder = (at['teamBuilderReferrals'] as num?) ?? teamBuilder;
          goldTierName = (at['goldTierName'] as String?) ?? goldTierName;
        }
      } catch (_) {
        // Defaults above already match what this screen shipped with —
        // nothing to do here but keep them.
      }

      if (!mounted) return;
      setState(() {
        _tier = tier;
        _achievements = [
          _Achievement(title: 'First $first50', description: '$first50 completed deliveries',
              icon: Icons.two_wheeler_rounded, color: const Color(0xFF0284C7),
              current: totalDeliveries, target: first50),
          _Achievement(title: 'First $first250', description: '$first250 completed deliveries',
              icon: Icons.shield_rounded, color: const Color(0xFFEA580C),
              current: totalDeliveries, target: first250),
          _Achievement(title: 'Five Star', description: 'Maintain a $fiveStar+ rating',
              icon: Icons.star_rounded, color: const Color(0xFFF59E0B),
              current: rating, target: fiveStar),
          _Achievement(title: 'Reliable Partner', description: '$reliableRate%+ order acceptance rate',
              icon: Icons.verified_rounded, color: const Color(0xFF16A34A),
              current: acceptanceRate, target: reliableRate),
          _Achievement(title: 'Team Builder', description: 'Refer $teamBuilder drivers who join GoOuts',
              icon: Icons.groups_rounded, color: const Color(0xFF6366F1),
              current: referrals, target: teamBuilder),
          _Achievement(title: '$goldTierName Tier', description: 'Reach $goldTierName driver tier',
              icon: Icons.emoji_events_rounded, color: const Color(0xFFEA580C),
              current: tier == goldTierName ? 1 : 0, target: 1),
        ];
        _loading = false;
      });
    } catch (_) {
      // ⚠ FIXED 8 September 2026, post-build failure-mode review — a failed
      // load used to silently render an empty "0 of 6 unlocked" grid,
      // indistinguishable from a driver who genuinely has zero achievements.
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Badges & Achievements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.primary))
            : _loadFailed
                ? _errorState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryCard(unlockedCount),
                        const SizedBox(height: 20),
                        ..._achievements.map(_badgeCard),
                      ],
                    ),
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
            const Text('Couldn\'t load your achievements', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _summaryCard(int unlockedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFEA580C), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_tier Driver', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text('$unlockedCount of ${_achievements.length} achievements unlocked',
                    style: const TextStyle(fontSize: 12.5, color: _C.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(_Achievement a) {
    final unlocked = a.isUnlocked;
    final progress = a.target == 0 ? 0.0 : (a.current / a.target).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? _C.card : _C.lockedBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unlocked ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: unlocked ? a.color.withOpacity(0.18) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: unlocked ? a.color.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
                ),
                child: Icon(a.icon, size: 24, color: unlocked ? a.color : _C.textMuted.withOpacity(0.45)),
              ),
              if (!unlocked)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: _C.bg, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_rounded, size: 11, color: _C.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: unlocked ? Colors.white : _C.textMuted.withOpacity(0.7))),
                const SizedBox(height: 3),
                Text(a.description,
                    style: TextStyle(fontSize: 12, color: unlocked ? _C.textMuted : _C.textMuted.withOpacity(0.45), height: 1.25)),
                const SizedBox(height: 6),
                if (unlocked)
                  const Row(children: [
                    Icon(Icons.check_circle_outline_rounded, size: 13, color: _C.success),
                    SizedBox(width: 4),
                    Text('Unlocked', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.textMuted)),
                  ])
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          width: 130, height: 4, color: _C.track,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(color: _C.primary.withOpacity(0.8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${a.current} of ${a.target}',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.textMuted.withOpacity(0.6))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
