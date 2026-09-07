import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'safety_toolkit_screen.dart';
import '../../support/help_support_screen.dart';
import '../../legal/faq_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 08_support_training_screen as the visual
//  reference.
//
//  ⚠ IMPROVED, not just reskinned. The live Training card used to show a
//  fake "Getting Started — completed" checkmark and a fake "Road Safety
//  Standards — 40% progress, Resume" bar with no video player, no
//  training_modules collection, and no way for a tap on Resume to do
//  anything — presenting an unbuilt feature as though a driver had already
//  made progress in it. The Stitch reference for this screen independently
//  arrived at the honest version of the same section — "Coming soon" / "in
//  preparation" badges instead of fake completion state — which is adopted
//  here. Same fix for the three Driver Perks cards: they used to be
//  "Claim Now" / "Learn More" / "Apply" buttons with onPressed: () {} (dead
//  taps to nowhere); now a single honestly-labelled "Coming soon" card.
//  This keeps the section present per the standing decision in
//  STANDING_CONTEXT_GOOUTS.md §1 (don't rip it out) while fixing the actual
//  violation (don't let it pretend to be live).
//
//  ⚠ NOT carried over from the Stitch mockup: the "Courier Operations
//  Status" card (Avg Reply 2 mins / Active Hub Camden / Dispute SLA 24
//  hrs — no support_tickets/courier_safety collection with these fields
//  exists), the "Transit insurance coverage remains active" claim (same
//  unverified-insurance problem as the dropped trust badge on the login
//  screen), and the fake "Helpdesk Version 3.4.2" footer. The Payment
//  Schedules knowledge article was softened to drop an unconfirmed "BACS"
//  banking-rail claim while keeping the one fact that matches the app's
//  own real constant — payouts run weekly on Monday.
//
//  All real logic — the SOS dialog and its honest phone-dialer-only
//  behaviour, and the Live Chat / FAQs navigation — is unchanged from
//  before this pass.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const softBlueBg = Color(0xFFEFF5FD);
  static const badgeBg  = Color(0xFFE2EAF8);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const emergencyBg = Color(0xFFFFECEB);
  static const emergencyBorder = Color(0xFFFFD5D2);
  static const emergencyDark = Color(0xFFB91C1C);
}

class SupportTrainingScreen extends StatefulWidget {
  const SupportTrainingScreen({super.key});

  @override
  State<SupportTrainingScreen> createState() => _SupportTrainingScreenState();
}

class _SupportTrainingScreenState extends State<SupportTrainingScreen> {
  final Map<int, bool> _expandedArticles = {0: false, 1: false, 2: false, 3: false};

  static final _faqs = [
    {
      'title': 'Pickup and Restaurant Wait Times',
      'content':
          'If you arrive at a partner venue and the order is delayed, use the in-app prompt to report "Order not ready" and let dispatch know.',
    },
    {
      'title': 'Parking Guidelines',
      'content':
          'Use designated bays for scooters and mopeds. Bicycles may use standard cycle racks. Never obstruct emergency exits or footpaths.',
    },
    {
      'title': 'Customer Cancellation & Wrong Address',
      'content':
          'If a customer cancels after collection or gave an unreachable address, wait at the pin, try calling, then mark the order undeliverable with a photo.',
    },
    {
      'title': 'Payment Schedules',
      'content':
          'Weekly payouts run automatically every Monday. See the Earnings tab for your current balance and recent trips.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        title: const Text('GoOuts Driver',
            style: TextStyle(
                color: _C.navy, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: _C.paleTint,
              child: const Icon(Icons.person, color: _C.primary, size: 18),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver Support',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: _C.navy)),
            const SizedBox(height: 2),
            const Text('Help, safety, and courier resources',
                style: TextStyle(fontSize: 13, color: _C.body)),

            const SizedBox(height: 18),

            // ── Quick action cards ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpSupportScreen(
                          accountType: 'driver',
                          collectionName: 'food_drivers',
                        ),
                      ),
                    ),
                    child: _quickCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Start Chat',
                      badge: 'New',
                      desc: 'Message our support team',
                      cta: 'Open chat',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    ),
                    child: _quickCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Driver FAQs',
                      badge: 'Guides',
                      desc: 'Pickup rules, cancellations, and more',
                      cta: 'Browse topics',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Emergency assistance ──────────────────────────────────
            GestureDetector(
              onTap: () => _showSOS(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.emergencyBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.emergencyBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _C.emergencyDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.emergency_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Emergency Assistance',
                                  style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: _C.emergencyDark)),
                              const SizedBox(height: 2),
                              Text('UK Emergency Services',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _C.emergencyDark.withOpacity(0.85))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Opens your phone dialer with 999 ready to call. GoOuts does not automatically place the call or monitor this button.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _showSOS(context),
                        icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                        label: const Text('Open Phone Dialer (999)',
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.emergencyDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ── Training & Safety ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Training & Safety',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: _C.navy)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SafetyToolkitScreen()),
                  ),
                  child: const Text('Safety Toolkit',
                      style: TextStyle(color: _C.primary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _comingSoonCard(
              icon: Icons.school_outlined,
              title: 'Road Safety & Food Hygiene',
              badge: 'Coming soon',
              desc: 'Interactive road safety and safe food handling modules are in preparation for UK couriers.',
            ),

            const SizedBox(height: 22),

            // ── Driver Perks ──────────────────────────────────────────
            const Text('Driver Perks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.navy)),
            const SizedBox(height: 10),
            _comingSoonCard(
              icon: Icons.local_offer_outlined,
              title: 'Fuel, Equipment & Partner Discounts',
              badge: 'Coming soon',
              desc: 'Discounts on e-bike repairs, equipment, and partner offers will be available in a future release.',
            ),

            const SizedBox(height: 22),

            // ── Knowledge articles ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Common Knowledge Articles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.navy)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final allOpen = _expandedArticles.values.every((v) => v);
                      for (int i = 0; i < _faqs.length; i++) {
                        _expandedArticles[i] = !allOpen;
                      }
                    });
                  },
                  child: const Text('Expand all',
                      style: TextStyle(color: _C.primaryDk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_faqs.length, (i) {
              final isExpanded = _expandedArticles[i] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (expanded) =>
                        setState(() => _expandedArticles[i] = expanded),
                    title: Text(_faqs[i]['title']!,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _C.navy)),
                    trailing: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _C.navy,
                      size: 22,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                        child: Text(_faqs[i]['content']!,
                            style: const TextStyle(fontSize: 12.5, color: _C.body, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String badge,
    required String desc,
    required String cta,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.softBlueBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _C.primary, size: 20),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _C.navy)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _C.badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _C.primaryDk)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(desc,
                style: const TextStyle(fontSize: 12, color: _C.body, height: 1.35)),
            const SizedBox(height: 14),
            Row(children: [
              Text(cta,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _C.primaryDk)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: _C.primaryDk),
            ]),
          ],
        ),
      );

  Widget _comingSoonCard({
    required IconData icon,
    required String title,
    required String badge,
    required String desc,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _C.paleTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _C.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700, color: _C.navy)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.softBlueBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badge,
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w700, color: _C.primaryDk)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(desc, style: const TextStyle(fontSize: 12.5, color: _C.body, height: 1.35)),
          ],
        ),
      );

  // ⚠ Logic unchanged by the 7 September 2026 visual reskin — see the
  // detailed 6 September 2026 note preserved in git history: this dialog
  // used to promise safety-team monitoring and location sharing it never
  // did. It now honestly opens the phone dialer only, on confirmation.
  void _showSOS(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.emergency_share, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('SOS Emergency',
                style: TextStyle(color: _C.navy, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you in an emergency? Tapping continue opens your phone '
          'dialer with 999 ready to call. GoOuts does not monitor this '
          'button — for non-emergency help use Live Chat.',
          style: TextStyle(color: _C.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _C.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(Uri(scheme: 'tel', path: '999'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Call 999', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
