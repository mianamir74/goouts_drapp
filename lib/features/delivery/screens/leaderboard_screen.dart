import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  New 7 September 2026, built from 24_leaderboard_screen as a loose visual
//  reference. Dark theme — deliberate Rewards-area exception.
//
//  ⚠ SECURITY CALL, NOT JUST A "NOT BUILT YET" NOTE. The Stitch reference
//  itself flags this correctly: "Needs scheduled Cloud Function to
//  aggregate regional rankings. Showing driver activity to other couriers
//  requires legal and product privacy review prior to public launch." That
//  disclosure is accurate and was checked against this app's actual
//  Firestore rules (admin_panel/firestore.rules):
//
//      match /food_drivers/{driverId} {
//        allow read: if ownsDoc(driverId) || isAdmin();
//      }
//
//  A driver can only ever read their OWN food_drivers document. There is no
//  aggregated/anonymized rankings collection and no Cloud Function that
//  produces one. The only way to build a real leaderboard client-side right
//  now would be to either (a) loosen that rule so any signed-in driver can
//  read every other driver's document — which leaks names, ratings, tier,
//  and delivery counts (and via those, earnings patterns) to every other
//  driver, a real privacy regression — or (b) query a collection that
//  doesn't exist and silently fail. Neither is acceptable as a side effect
//  of a visual reskin pass.
//
//  So this screen intentionally makes NO Firestore query at all — not even
//  a scoped or "safe-looking" one — and shows none of the Stitch reference's
//  fabricated names, ranks, zones, or drop counts (Dave K., Amina R., "Top
//  1% Central Manchester", etc.). It also drops the opt-in visibility
//  toggle: a toggle for a feature that doesn't exist yet has nothing real
//  to switch on or off. When a real ranking system ships — backed by a
//  Cloud Function that returns pre-aggregated, privacy-reviewed data rather
//  than raw driver documents — this screen is where it plugs in.
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF94A3B8), size: 34),
                ),
                const SizedBox(height: 20),
                const Text('Leaderboards are coming soon',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                const Text(
                  'We want to get driver privacy right before showing anyone else\'s activity — so rankings will only launch once that\'s been properly reviewed, with anonymised, opt-in data only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
