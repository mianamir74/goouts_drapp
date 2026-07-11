import 'package:flutter/material.dart';

import 'safety_toolkit_screen.dart';
import 'identity_verification_screen.dart';

class SupportTrainingScreen extends StatelessWidget {
  const SupportTrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('GoOuts Driver',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFF0b1a3d),
              child: const Icon(Icons.person, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── SOS Emergency button ──────────────────────────────────
            GestureDetector(
              onTap: () => _showSOS(context),
              child: Container(
                width: double.infinity,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFef4444).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency_share, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text('SOS Emergency',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 26),

            // ── Need Help? ────────────────────────────────────────────
            const Text('Need Help?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: [
                // Live Chat card
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0392ca),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_outlined,
                              color: Colors.white, size: 32),
                          SizedBox(height: 8),
                          Text('Live Chat',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // FAQs card
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1a3d),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.help_outline,
                              color: Colors.white70, size: 32),
                          SizedBox(height: 8),
                          Text('FAQs',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // ── Training & Safety ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Training & Safety',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SafetyToolkitScreen()),
                  ),
                  child: const Text('Safety Toolkit',
                      style: TextStyle(
                          color: Color(0xFF0392ca), fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _trainingItem(
              icon: Icons.play_circle_outline,
              title: 'Getting Started',
              duration: '15 mins',
              completed: true,
            ),
            const SizedBox(height: 10),
            _trainingItem(
              icon: Icons.shield_outlined,
              title: 'Road Safety Standards',
              duration: '20 mins left',
              completed: false,
              progress: 0.4,
              showResume: true,
            ),

            const SizedBox(height: 26),

            // ── Driver Perks ──────────────────────────────────────────
            const Text('Driver Perks',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _perkCard(
                    icon: Icons.local_gas_station,
                    title: 'Fuel Discount',
                    subtitle: 'Save up to 10% at select stations.',
                    cta: 'Claim Now',
                  ),
                  const SizedBox(width: 14),
                  _perkCard(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health Insurance',
                    subtitle: 'Discounted plans for top partners.',
                    cta: 'Learn More',
                  ),
                  const SizedBox(width: 14),
                  _perkCard(
                    icon: Icons.directions_bike,
                    title: 'Equipment Support',
                    subtitle: 'Subsidised gear for active drivers.',
                    cta: 'Apply',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _trainingItem({
    required IconData icon,
    required String title,
    required String duration,
    required bool completed,
    double? progress,
    bool showResume = false,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showResume
                ? const Color(0xFF0392ca).withOpacity(0.4)
                : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF031134),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0392ca), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 13, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(duration,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
                if (completed)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF10b981), size: 24)
                else if (showResume)
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF0392ca).withOpacity(0.15),
                      foregroundColor: const Color(0xFF0392ca),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Resume',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0392ca)),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _perkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String cta,
  }) =>
      Container(
        width: 230,
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Container(
                height: 110,
                color: const Color(0xFF0d1f4a),
                child: Center(
                  child: Icon(icon,
                      size: 52,
                      color: const Color(0xFF0392ca).withOpacity(0.6)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {},
                    child: Text(cta,
                        style: const TextStyle(
                            color: Color(0xFF0392ca),
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  void _showSOS(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0b1a3d),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emergency_share, color: Color(0xFFef4444)),
            SizedBox(width: 10),
            Text('SOS Emergency',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you in an emergency? Tapping continue will alert our safety team and share your location.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFef4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send SOS',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
