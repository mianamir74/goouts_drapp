import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  New 7 September 2026, built from 23_streak_milestone_celebration as a
//  loose visual reference. Dark theme — deliberate Rewards-area exception.
//
//  The Stitch reference is, again, upfront that its whole premise needs
//  backend that doesn't exist ("PROTOTYPE FIELD: Streak milestone trigger
//  condition and automated boost voucher grant logic are not yet deployed"
//  — its own words). Specifically not carried over:
//   - The daily-streak concept itself (no `streakCount`/`lastActiveDate`
//     tracking exists — see rewards_home_screen.dart for the same call).
//   - The "+10% Surge Boost, 3 Left" voucher card. This is a real-money
//     fare multiplier with no ledger, no grant logic, and no expiry
//     tracking behind it — building or faking a payout-adjacent reward is
//     exactly what this project's standing rule says never to do without
//     being explicitly asked. Dropped outright, not just relabelled.
//   - The fabricated "Central Manchester" scope claim and the fake
//     "Level 4" chip / 5-tab Quests-Perks-Tiers-Wallet bottom nav.
//
//  What's kept is the celebratory visual shell (flame graphic, particles,
//  stat tiles), repointed at something this app can actually back: a
//  driver's real `totalDeliveries` crossing a round-number milestone
//  (50 / 100 / 250 / 500 / 1000...). The caller supplies the real numbers
//  — this widget renders them, it doesn't invent them.
//
//  Not wired to an automatic trigger this pass — deciding exactly where to
//  hook "just crossed a milestone, show this screen" (e.g. after
//  DeliveryVerificationScreen confirms a delivery) is left for whoever
//  wires it up, so a milestone can't be shown twice or skipped by a race
//  condition without that being thought through first.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF031134);
  static const card      = Color(0xFF0B1A3D);
  static const primary   = Color(0xFF0392CA);
  static const accent    = Color(0xFFF97316);
  static const accentDk  = Color(0xFFEA580C);
  static const amber     = Color(0xFFF59E0B);
  static const textMuted = Color(0xFF94A3B8);
}

class MilestoneCelebrationScreen extends StatelessWidget {
  /// The round-number milestone just reached, e.g. 100.
  final int milestone;
  /// The driver's real totalDeliveries at the time this is shown.
  final int totalDeliveries;
  /// Optional real all-time earnings, if the caller already has it loaded.
  final double? totalEarned;

  const MilestoneCelebrationScreen({
    super.key,
    required this.milestone,
    required this.totalDeliveries,
    this.totalEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              _heroFlame(),
              const SizedBox(height: 20),
              _milestonePill(),
              const SizedBox(height: 14),
              _headline(),
              const SizedBox(height: 22),
              _statGrid(),
              const SizedBox(height: 30),
              _keepGoingCta(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroFlame() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.4), blurRadius: 50, spreadRadius: 15)],
            ),
          ),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFB923C), _C.accent, Color(0xFFC2410C)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Center(child: Icon(Icons.emoji_events_rounded, size: 54, color: Colors.white)),
          ),
          Positioned(
            right: 8, top: 6,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: _C.card, shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
              child: const Icon(Icons.star_rounded, color: _C.amber, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestonePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _C.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.amber.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.verified_rounded, size: 14, color: _C.amber),
        const SizedBox(width: 6),
        Text('$milestone DELIVERY MILESTONE',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _C.amber, letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _headline() {
    return Column(
      children: [
        Text('$milestone DELIVERIES!', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.6, height: 1.12)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: const Text(
            'That\'s a real milestone — thanks for keeping GoOuts running.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _C.textMuted, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _statGrid() {
    return Row(
      children: [
        Expanded(child: _statTile(icon: Icons.two_wheeler_rounded, value: '$totalDeliveries', label: 'Total Deliveries')),
        if (totalEarned != null) ...[
          const SizedBox(width: 10),
          Expanded(child: _statTile(icon: Icons.payments_outlined, value: '£${totalEarned!.toStringAsFixed(0)}', label: 'Total Earned')),
        ],
      ],
    );
  }

  Widget _statTile({required IconData icon, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFF0E1E46), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _C.textMuted),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textMuted)),
        ],
      ),
    );
  }

  Widget _keepGoingCta(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).maybePop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.accent,
          elevation: 3,
          shadowColor: _C.accent.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Keep Going', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
