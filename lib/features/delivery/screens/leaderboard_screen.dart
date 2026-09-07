import 'package:cloud_firestore/cloud_firestore.dart';
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
//  A driver can only ever read their OWN food_drivers document, and that
//  has not changed. What changed 8 September 2026 is that a real,
//  privacy-safe alternative now exists: dailyFoodDriverLeaderboard (Cloud
//  Function, Admin SDK — bypasses that rule entirely) writes a single
//  document at food_driver_leaderboard/current containing ONLY first name
//  and a count, ranked. No driver ever reads another driver's real
//  food_drivers document; they read a curated summary a Cloud Function
//  produced. See food_driver_rewards.js for the full reasoning, and
//  admin_dashboard.dart's Rewards & Leaderboard page for the on/off switch
//  — leaderboard.enabled defaults to FALSE, so this screen shows the exact
//  same honest "coming soon" state as before until an admin turns it on.
//
//  One-time .get(), not a live .snapshots() listener: the underlying data
//  only changes once a day (dailyFoodDriverLeaderboard runs once nightly),
//  so a live listener would hold a socket open for a document that is
//  correct for hours at a time — same reasoning as
//  active_delivery_mini_bar.dart's one-time fetch.
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardEntry {
  final int rank;
  final String firstName;
  final num value;
  const _LeaderboardEntry({required this.rank, required this.firstName, required this.value});
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;
  bool _enabled = false;
  String _metric = 'weekly_deliveries';
  DateTime? _generatedAt;
  List<_LeaderboardEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('food_driver_leaderboard').doc('current').get();
      final d = snap.data();
      if (d != null && d['enabled'] == true) {
        final rawEntries = (d['entries'] as List?) ?? const [];
        final ts = d['generatedAt'];
        setState(() {
          _enabled = true;
          _metric = (d['metric'] as String?) ?? 'weekly_deliveries';
          _generatedAt = ts is Timestamp ? ts.toDate() : null;
          _entries = rawEntries.whereType<Map>().map((e) => _LeaderboardEntry(
            rank: (e['rank'] as num?)?.toInt() ?? 0,
            firstName: (e['firstName'] as String?) ?? 'A driver',
            value: (e['value'] as num?) ?? 0,
          )).toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // Falls through to the honest "coming soon" state below — same as a
      // disabled leaderboard. A read failure must never look like an empty
      // #1-to-last ranking; it must look like what it is, unavailable.
    }
    if (mounted) setState(() { _enabled = false; _loading = false; });
  }

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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0392CA)))
            : _enabled
                ? _rankedList()
                : _comingSoon(),
      ),
    );
  }

  Widget _comingSoon() {
    return Padding(
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
    );
  }

  Widget _rankedList() {
    if (_entries.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No rankings yet — check back once more drivers have completed deliveries this week.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), height: 1.45)),
      ));
    }
    final metricLabel = _metric == 'all_time_deliveries' ? 'All-time deliveries' : 'This week\'s deliveries';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(
            _generatedAt != null
                ? '$metricLabel · updated ${_generatedAt!.toLocal()}'.split('.').first
                : metricLabel,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = _entries[i];
              final isTop3 = e.rank <= 3;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1A3D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(isTop3 ? 0.15 : 0.06)),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: Text('#${e.rank}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: isTop3 ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.firstName,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white))),
                  Text('${e.value}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0392CA))),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}
