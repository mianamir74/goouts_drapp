import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color _blue = Color(0xFF0392CA);
  static const Color _navy = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _bg = Color(0xFFF8FAFF);

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<Map<String, dynamic>> _referredMerchants = [];
  int _totalReferred = 0;
  int _activeMerchants = 0;
  double _totalEarningsAllTime = 0;
  double _thisMonthEarnings = 0;

  // ── Tier config ────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _tiers = [
    {
      'tier': 1,
      'label': 'Tier 1',
      'min': 1,
      'max': 5,
      'commission': 3.0,
      'color': Color(0xFF0392CA),
      'icon': Icons.emoji_events_outlined,
    },
    {
      'tier': 2,
      'label': 'Tier 2',
      'min': 6,
      'max': 10,
      'commission': 4.0,
      'color': Color(0xFF7C3AED),
      'icon': Icons.workspace_premium_outlined,
    },
    {
      'tier': 3,
      'label': 'Tier 3',
      'min': 11,
      'max': 999,
      'commission': 5.0,
      'color': Color(0xFFF59E0B),
      'icon': Icons.military_tech_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('businesses')
          .where('referredBy', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .get();

      final merchants = snap.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();

      final active = merchants
          .where((m) =>
              (m['status'] ?? '').toString().toUpperCase() == 'APPROVED')
          .length;

      // Sum earnings from commission records
      double allTime = 0;
      double thisMonth = 0;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (final m in merchants) {
        final docId = m['docId'] as String;
        try {
          final commSnap = await FirebaseFirestore.instance
              .collection('businesses')
              .doc(docId)
              .collection('driver_commissions')
              .get();
          double merchantTotal = 0;
          double merchantMonth = 0;
          for (final c in commSnap.docs) {
            final cd = c.data();
            final amount = (cd['amount'] as num?)?.toDouble() ?? 0.0;
            final ts = cd['createdAt'];
            DateTime? date;
            if (ts is Timestamp) date = ts.toDate();
            merchantTotal += amount;
            if (date != null && date.isAfter(startOfMonth)) {
              merchantMonth += amount;
            }
          }
          m['commissionEarned'] = merchantTotal;
          m['commissionThisMonth'] = merchantMonth;
          allTime += merchantTotal;
          thisMonth += merchantMonth;
        } catch (_) {
          m['commissionEarned'] = 0.0;
          m['commissionThisMonth'] = 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _referredMerchants = merchants;
          _totalReferred = merchants.length;
          _activeMerchants = active;
          _totalEarningsAllTime = allTime;
          _thisMonthEarnings = thisMonth;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Tier helpers ───────────────────────────────────────────────────────────
  Map<String, dynamic> _currentTier() {
    for (final t in _tiers.reversed) {
      if (_activeMerchants >= (t['min'] as int)) return t;
    }
    return _tiers[0];
  }

  Map<String, dynamic>? _nextTier() {
    final cur = _currentTier();
    final idx = _tiers.indexOf(cur);
    if (idx < _tiers.length - 1) return _tiers[idx + 1];
    return null;
  }

  double _tierProgress() {
    final cur = _currentTier();
    final min = cur['min'] as int;
    final max = cur['max'] as int;
    if (max >= 999) return 1.0;
    final progress = (_activeMerchants - min + 1) / (max - min + 1);
    return progress.clamp(0.0, 1.0);
  }

  // ── Status display ─────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return _green;
      case 'PENDING':
        return _amber;
      case 'REJECTED':
        return Colors.red;
      default:
        return _textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Live';
      case 'PENDING':
        return 'Pending';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  // ── Format ─────────────────────────────────────────────────────────────────
  String _fmt(double v) => NumberFormat.currency(
        locale: 'en_GB',
        symbol: '£',
        decimalDigits: 2,
      ).format(v);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text(
          'My Earnings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _blue),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tierCard(),
                    const SizedBox(height: 16),
                    _earningsSummaryRow(),
                    const SizedBox(height: 24),
                    _allTiersRow(),
                    const SizedBox(height: 24),
                    const Text(
                      'Referred Businesses',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You earn ${(_currentTier()['commission'] as double).toStringAsFixed(0)}% of GoOuts\' monthly profit from each business you sign up.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_referredMerchants.isEmpty)
                      _emptyState()
                    else
                      ..._referredMerchants
                          .map((m) => _merchantCard(m))
                          .toList(),
                    const SizedBox(height: 24),
                    _howItWorksCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Tier card ──────────────────────────────────────────────────────────────
  Widget _tierCard() {
    final tier = _currentTier();
    final next = _nextTier();
    final progress = _tierProgress();
    final tierColor = tier['color'] as Color;
    final commission = tier['commission'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, tierColor.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tier['icon'] as IconData,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      tier['label'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$_activeMerchants active',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${commission.toStringAsFixed(0)}% commission',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'of GoOuts profit from each referred business',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Progress bar
          if (next != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_activeMerchants / ${next['min'] as int} to ${next['label']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(next['commission'] as double).toStringAsFixed(0)}% at ${next['label']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: _amber, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Maximum tier reached — 5% forever',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Earnings summary ───────────────────────────────────────────────────────
  Widget _earningsSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            label: 'This Month',
            value: _fmt(_thisMonthEarnings),
            icon: Icons.calendar_month_rounded,
            color: _blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            label: 'All Time',
            value: _fmt(_totalEarningsAllTime),
            icon: Icons.account_balance_wallet_outlined,
            color: _green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            label: 'Total Signed Up',
            value: '$_totalReferred',
            icon: Icons.store_rounded,
            color: _purple,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          AutoSizeText(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── All tiers row ──────────────────────────────────────────────────────────
  Widget _allTiersRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commission Structure',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _tiers.map((t) {
              final isCurrent = _currentTier()['tier'] == t['tier'];
              final color = t['color'] as Color;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: t == _tiers.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color.withOpacity(0.1)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? color.withOpacity(0.4)
                          : _border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              isCurrent ? color : _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(t['commission'] as double).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isCurrent ? color : _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t['min']}–${t['max'] as int >= 999 ? '∞' : t['max']} merchants',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrent
                              ? color.withOpacity(0.7)
                              : _textSecondary,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Merchant card ──────────────────────────────────────────────────────────
  Widget _merchantCard(Map<String, dynamic> m) {
    final name = (m['tradingName'] ?? m['legalBusinessName'] ?? 'Unknown Business')
        .toString();
    final category = (m['category'] ?? '').toString();
    final city = (m['city'] ?? '').toString();
    final status = (m['status'] ?? 'PENDING').toString();
    final commission = (m['commissionEarned'] as num?)?.toDouble() ?? 0.0;
    final monthlyComm =
        (m['commissionThisMonth'] as num?)?.toDouble() ?? 0.0;
    final ts = m['submittedAt'];
    String dateStr = '';
    if (ts is Timestamp) {
      dateStr = DateFormat('d MMM yyyy').format(ts.toDate());
    }
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store_rounded, color: _blue, size: 22),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [if (category.isNotEmpty) category, if (city.isNotEmpty) city]
                      .join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Submitted $dateStr',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat('This month', _fmt(monthlyComm), _blue),
                    const SizedBox(width: 12),
                    _miniStat('All time', _fmt(commission), _green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.store_outlined, color: _blue, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'No businesses signed up yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Visit a local business and sign them up to GoOuts. Every approved business earns you residual commission every month.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── How it works ───────────────────────────────────────────────────────────
  Widget _howItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How your earnings work',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _howStep('1',
              'You sign up a business using the onboarding form.'),
          _howStep('2',
              'GoOuts approves the business — they go live in the app.'),
          _howStep('3',
              'GoOuts users pay at that business and earn cashback.'),
          _howStep('4',
              'At month end, GoOuts calculates profit from that business.'),
          _howStep('5',
              'You earn ${(_currentTier()['commission'] as double).toStringAsFixed(0)}% of that profit — every month, forever.'),
          const SizedBox(height: 4),
          Text(
            'Sign up more businesses to reach Tier 2 (4%) and Tier 3 (5%).',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.55),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _howStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
