import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  New 7 September 2026, built from 21_weekly_recap_screen as a loose visual
//  reference. Dark theme — deliberate Rewards-area exception.
//
//  The Stitch reference is upfront that "every metric on this screen is
//  PROTOTYPE FIELD" (its own header comment) — a fabricated recap ID, date
//  range, earnings, tip total, busiest day, a fully invented "74.8 miles /
//  2.3 mi per delivery" distance card (no odometer or route-distance
//  tracking exists anywhere in this app), a fake prior-week comparison, and
//  a share button that only shows a "pending deployment" snackbar. It also
//  keeps a 5-tab Quests/Perks/Tiers/Wallet bottom nav that doesn't exist.
//
//  Rebuilt as a real 4-card story using one Firestore query covering the
//  last 14 days of the driver's own delivered `food_orders`, bucketed
//  client-side into "this week" vs "the week before" — no separate
//  aggregator job needed:
//   - Card 1: intro (no city-specific claim — this driver's own numbers).
//   - Card 2: real total earned + real deliveries + real tips this week.
//   - Card 3: real busiest day (by delivery count) and real top venue (by
//     frequency), both computed from this driver's own orders.
//   - Card 4: real week-over-week earnings comparison against the prior
//     7-day window from the same query.
//  The distance card is dropped entirely rather than inventing mileage.
//  Share is wired for real via share_plus (already a pubspec dependency),
//  sharing only the real numbers computed above.
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

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final PageController _pageController = PageController();
  int _currentCardIndex = 0;
  int _totalCards = 4;
  bool _loading = true;
  bool _loadFailed = false;

  int _thisWeekDeliveries = 0;
  double _thisWeekEarnings = 0;
  double _thisWeekTips = 0;
  double _lastWeekEarnings = 0;
  String? _busiestDay;
  int _busiestDayCount = 0;
  double _busiestDayEarnings = 0;
  String? _topVenue;
  int _topVenueCount = 0;

  static const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loadFailed = false);
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 7));
      final twoWeeksStart = now.subtract(const Duration(days: 14));

      final snap = await FirebaseFirestore.instance
          .collection('food_orders')
          .where('driverId', isEqualTo: uid)
          .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twoWeeksStart))
          .orderBy('deliveredAt', descending: true)
          .limit(400)
          .get();

      int thisWeekCount = 0;
      double thisWeekEarnings = 0;
      double thisWeekTips = 0;
      double lastWeekEarnings = 0;
      final perDayCount = <int, int>{};
      final perDayEarnings = <int, double>{};
      final perVenueCount = <String, int>{};

      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['status'] as String?) != 'delivered') continue;
        final deliveredAt = (d['deliveredAt'] as Timestamp?)?.toDate();
        if (deliveredAt == null) continue;
        final fee = (d['driverFee'] ?? 0.0).toDouble();
        final tip = (d['driverTip'] ?? 0.0).toDouble();
        final venue = (d['restaurantName'] as String?) ?? '';

        if (deliveredAt.isAfter(weekStart)) {
          thisWeekCount++;
          thisWeekEarnings += fee + tip;
          thisWeekTips += tip;
          final weekday = deliveredAt.weekday - 1; // 0=Mon
          perDayCount[weekday] = (perDayCount[weekday] ?? 0) + 1;
          perDayEarnings[weekday] = (perDayEarnings[weekday] ?? 0) + fee + tip;
          if (venue.isNotEmpty) perVenueCount[venue] = (perVenueCount[venue] ?? 0) + 1;
        } else {
          lastWeekEarnings += fee + tip;
        }
      }

      String? busiestDay;
      int busiestCount = 0;
      double busiestEarnings = 0;
      perDayCount.forEach((day, count) {
        if (count > busiestCount) {
          busiestCount = count;
          busiestDay = _weekdayNames[day];
          busiestEarnings = perDayEarnings[day] ?? 0;
        }
      });

      String? topVenue;
      int topVenueCount = 0;
      perVenueCount.forEach((venue, count) {
        if (count > topVenueCount) {
          topVenueCount = count;
          topVenue = venue;
        }
      });

      if (!mounted) return;
      setState(() {
        _thisWeekDeliveries = thisWeekCount;
        _thisWeekEarnings = thisWeekEarnings;
        _thisWeekTips = thisWeekTips;
        _lastWeekEarnings = lastWeekEarnings;
        _busiestDay = busiestDay;
        _busiestDayCount = busiestCount;
        _busiestDayEarnings = busiestEarnings;
        _topVenue = topVenue;
        _topVenueCount = topVenueCount;
        _totalCards = thisWeekCount > 0 ? 4 : 1;
        _loading = false;
      });
    } catch (_) {
      // ⚠ FIXED 8 September 2026, post-build failure-mode review — a failed
      // load used to silently fall through to the "no delivered orders yet"
      // empty state, which reads as "you haven't delivered anything" rather
      // than "this failed to load" — misleading on a screen a driver would
      // otherwise trust as an accurate record.
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  void _onNextCard() {
    if (_currentCardIndex < _totalCards - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeInOut);
    }
  }

  void _onPrevCard() {
    if (_currentCardIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 260), curve: Curves.easeInOut);
    }
  }

  void _onShareRecap() {
    final buffer = StringBuffer()
      ..writeln('My week on GoOuts:')
      ..writeln('$_thisWeekDeliveries deliveries')
      ..writeln('£${_thisWeekEarnings.toStringAsFixed(2)} earned');
    if (_busiestDay != null) buffer.writeln('Busiest day: $_busiestDay ($_busiestDayCount drops)');
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Weekly Recap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.primary))
            : _loadFailed
                ? _errorState()
                : _thisWeekDeliveries == 0
                ? _emptyState()
                : Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Color(0xFF0F2656), _C.card, Color(0xFF061436)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Stack(
                            children: [
                              PageView(
                                controller: _pageController,
                                onPageChanged: (i) => setState(() => _currentCardIndex = i),
                                children: [
                                  _cardIntro(),
                                  _cardTotalEarnings(),
                                  if (_busiestDay != null) _cardBusiestDay(),
                                  _cardGrowth(),
                                ],
                              ),
                              Positioned.fill(
                                child: Row(children: [
                                  Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _onPrevCard)),
                                  Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _onNextCard)),
                                ]),
                              ),
                              Positioned(top: 14, left: 14, right: 14, child: _storyProgressBars()),
                              Positioned(
                                bottom: 16, left: 16, right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${_currentCardIndex + 1} of $_totalCards',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85))),
                                    if (_currentCardIndex == _totalCards - 1)
                                      GestureDetector(
                                        onTap: _onShareRecap,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(20)),
                                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.share_rounded, size: 14, color: Colors.white),
                                            SizedBox(width: 6),
                                            Text('Share', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                          ]),
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: _onNextCard,
                                        child: Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                                          child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
            const Text('Couldn\'t load your recap', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Text('No delivered orders in the last 7 days yet — your recap will appear here once you have some.',
            textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted, fontSize: 14, height: 1.4)),
      ),
    );
  }

  Widget _storyProgressBars() {
    return Row(
      children: List.generate(_totalCards, (i) {
        final passed = i <= _currentCardIndex;
        return Expanded(
          child: Container(
            height: 3.5,
            margin: EdgeInsets.only(right: i < _totalCards - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: passed ? Colors.white : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _cardIntro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF38BDF8).withOpacity(0.9),
                const Color(0xFF0284C7).withOpacity(0.6),
                const Color(0xFF0369A1).withOpacity(0.1),
              ]),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 28),
          const Text('WEEKLY DIGEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _C.accent, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          const Text('Your week in\ndelivery', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8, height: 1.15)),
          const SizedBox(height: 14),
          const Text('Here\'s how your last 7 days on GoOuts stacked up.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _C.textMuted, height: 1.45)),
        ],
      ),
    );
  }

  Widget _cardTotalEarnings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('TOTAL EARNED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _C.primary, letterSpacing: 0.8)),
          const SizedBox(height: 16),
          Text('£${_thisWeekEarnings.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5)),
          const SizedBox(height: 10),
          Text('Across $_thisWeekDeliveries completed deliveries', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _C.textMuted, height: 1.35)),
          if (_thisWeekTips > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _C.success.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.volunteer_activism_rounded, color: _C.success, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('£${_thisWeekTips.toStringAsFixed(2)} in customer tips this week',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardBusiestDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _C.accent.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: _C.accent.withOpacity(0.5))),
            child: const Icon(Icons.local_fire_department_rounded, color: _C.accent, size: 38),
          ),
          const SizedBox(height: 20),
          const Text('BUSIEST DAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _C.accent, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Text('$_busiestDay was your\nbest day', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.6, height: 1.15)),
          const SizedBox(height: 12),
          Text('$_busiestDayCount deliveries • £${_busiestDayEarnings.toStringAsFixed(2)} earned', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _C.textMuted, height: 1.35)),
          if (_topVenue != null) ...[
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.storefront_rounded, size: 20, color: _C.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Top pickup: $_topVenue ($_topVenueCount drops)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardGrowth() {
    final delta = _thisWeekEarnings - _lastWeekEarnings;
    final hasPrior = _lastWeekEarnings > 0;
    final pct = hasPrior ? (delta / _lastWeekEarnings * 100) : 0.0;
    final isUp = delta >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: (isUp ? _C.success : _C.textMuted).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: (isUp ? _C.success : _C.textMuted).withOpacity(0.5)),
            ),
            child: Icon(isUp ? Icons.trending_up_rounded : Icons.trending_flat_rounded, color: isUp ? _C.success : _C.textMuted, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('WEEK-OVER-WEEK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _C.success, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          if (hasPrior)
            Text('${isUp ? '+' : ''}${pct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isUp ? _C.success : _C.textMuted, letterSpacing: -0.8))
          else
            const Text('First week on record', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 10),
          Text(
            hasPrior
                ? '£${_thisWeekEarnings.toStringAsFixed(2)} this week vs £${_lastWeekEarnings.toStringAsFixed(2)} the week before'
                : 'We\'ll show a comparison once you have a prior week to compare against.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _C.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}
