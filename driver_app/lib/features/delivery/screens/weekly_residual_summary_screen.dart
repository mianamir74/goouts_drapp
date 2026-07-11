import 'package:flutter/material.dart';

class WeeklyResidualSummaryScreen extends StatefulWidget {
  const WeeklyResidualSummaryScreen({super.key});

  @override
  State<WeeklyResidualSummaryScreen> createState() =>
      _WeeklyResidualSummaryScreenState();
}

class _WeeklyResidualSummaryScreenState
    extends State<WeeklyResidualSummaryScreen> {
  int _toggleIdx = 0; // 0=Weekly, 1=Monthly

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Residual Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Weekly / Monthly toggle ───────────────────────────────
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _toggleItem('Weekly', 0),
                  _toggleItem('Monthly', 1),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Reporting period ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reporting Period',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _toggleIdx == 0
                          ? 'Oct 16 – Oct 22, 2023'
                          : 'October 2023',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0b1a3d),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today,
                      size: 20, color: Color(0xFF0392ca)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Total residual earned card ────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0b1a3d), Color(0xFF031134)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.payments,
                        size: 80,
                        color: Colors.white.withOpacity(0.05)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Residual Earned',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('£482.50',
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: const [
                                Icon(Icons.trending_up,
                                    color: Color(0xFF10b981), size: 16),
                                SizedBox(width: 4),
                                Text('+12%',
                                    style: TextStyle(
                                        color: Color(0xFF10b981),
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Calculated from 42 active referrals',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Referral breakdown grid ───────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _referralCard(
                    'Driver Referrals',
                    '28 Active',
                    '£310.20',
                    const Color(0xFF0392ca),
                    Icons.local_shipping,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _referralCard(
                    'Merchant Referrals',
                    '14 Active',
                    '£172.30',
                    const Color(0xFFf97316),
                    Icons.storefront,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Residual growth chart ─────────────────────────────────
            const Text('Residual Growth',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Earnings Trend',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text('7 Day Trend',
                          style: TextStyle(
                              color: Colors.white30, fontSize: 10)),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(40, 'M'),
                      _bar(60, 'T'),
                      _bar(55, 'W'),
                      _bar(80, 'T'),
                      _bar(45, 'F'),
                      _bar(90, 'S'),
                      _bar(100, 'S', active: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Top performers ────────────────────────────────────────
            const Text('Top Performers',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            _performerItem('1', 'Marcus Thompson',
                'Fleet Leader (12 referrals)', '£84.20', 'Earnings Hub'),
            _performerItem('2', 'Golden Fork Bistro',
                'Merchant Partner', '£62.15', 'Commission'),

            const SizedBox(height: 24),

            // ── Share button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.share_outlined),
                    SizedBox(width: 12),
                    Text('Share Summary',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(String label, int idx) {
    final sel = _toggleIdx == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _toggleIdx = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF0392ca) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: sel ? Colors.white : Colors.white54,
              fontWeight:
                  sel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _referralCard(String title, String subtitle, String amount,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(20),
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),
          Text(amount,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _bar(double height, String label, {bool active = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: height,
          width: 24,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0392ca)
                : const Color(0xFF031134),
            borderRadius: BorderRadius.circular(6),
            border: active
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.05)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white24,
                fontSize: 10)),
      ],
    );
  }

  Widget _performerItem(String rank, String name, String subtitle,
      String amount, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF031134),
                child: Text(
                  name[0],
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                top: -5,
                left: -5,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFf97316),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(rank,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white)),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF10b981), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
