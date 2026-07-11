import 'package:flutter/material.dart';

class EarningsBreakdownScreen extends StatelessWidget {
  const EarningsBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0392ca)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Earnings Breakdown',
            style: TextStyle(
                color: Color(0xFF0392ca),
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundImage:
                  const NetworkImage('https://i.pravatar.cc/150?img=12'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Total gross card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Gross Earnings',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('£1,482.50',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
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
                            Text('+12.5% vs last week',
                                style: TextStyle(
                                    color: Color(0xFF10b981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 52,
                      color: Colors.white.withOpacity(0.08)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Financial Transparency header ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Financial Transparency',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Text('UK VAT Compliant',
                    style: TextStyle(
                        color: Color(0xFF10b981), fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(height: 14),

            // ── Take-home ratio ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 0.75,
                          strokeWidth: 9,
                          backgroundColor: Colors.white10,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0392ca)),
                        ),
                        const Text('75%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Take-home Ratio',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 4),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: '£1,111.88',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            TextSpan(
                              text: '  Net',
                              style: TextStyle(
                                  color: Color(0xFF0392ca),
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Breakdown items ───────────────────────────────────────
            // Driver receives their full NET FARE — no VAT deducted from pay.
            // GoOuts deducts its service commission from the ORDER total,
            // not from the driver's earned fare.
            // VAT is GoOuts' own liability on its commission — invisible to driver.
            _breakdownItem('Your Net Fare (100% yours)', '£1,111.88', 0.75,
                const Color(0xFF10b981)),
            const SizedBox(height: 10),
            _breakdownItem('GoOuts Commission (deducted from order)', '£296.50', 0.2,
                const Color(0xFFf97316)),
            const SizedBox(height: 10),
            _breakdownItem('Tips Earned (100% yours)', '£74.12', 0.05,
                const Color(0xFF0392ca)),

            const SizedBox(height: 12),

            // ── VAT note ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.white24, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'VAT (20%) applies to GoOuts service fee only. '
                      'Your driver earnings are not subject to VAT unless your '
                      'annual income exceeds the £90,000 HMRC registration threshold. '
                      'Hot food orders include 20% VAT collected by the restaurant.',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Incentives row ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                    child: _incentiveCard('Cashback', '+£45.20',
                        const Color(0xFF10b981))),
                const SizedBox(width: 12),
                Expanded(
                    child: _incentiveCard(
                        'Tips', '£124.00', const Color(0xFF0392ca))),
              ],
            ),

            const SizedBox(height: 20),

            // ── Download button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download Statement',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Statement generated for period Oct 1 - Oct 7, 2023',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _breakdownItem(
      String label, String amount, double progress, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline,
                    size: 15, color: Colors.white38),
                const Spacer(),
                Text(amount,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      );

  Widget _incentiveCard(String title, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.info_outline,
                    size: 14, color: Colors.white24),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );
}
