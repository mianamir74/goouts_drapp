import 'package:flutter/material.dart';

class SafetyToolkitScreen extends StatefulWidget {
  const SafetyToolkitScreen({super.key});

  @override
  State<SafetyToolkitScreen> createState() => _SafetyToolkitScreenState();
}

class _SafetyToolkitScreenState extends State<SafetyToolkitScreen> {
  bool _voiceActive = true;

  void _triggerSos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0b1a3d),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('🚨 Emergency SOS',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will contact 999 emergency services and share your live location with GoOuts support.\n\nAre you sure?',
          style: TextStyle(color: Colors.white70, height: 1.5),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Call 999',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Safety Toolkit',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            SizedBox(height: 4),
                            Text('Help is always available',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 14)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFef4444).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFef4444)
                                  .withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: Color(0xFFef4444)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Location card ────────────────────────────────────
                  _safetyTile(
                    icon: Icons.location_on_outlined,
                    title: 'Current Location',
                    subtitle: '582 Market St, London EC1A 1BB',
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('Copy',
                          style: TextStyle(color: Color(0xFF0392ca))),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── SOS ──────────────────────────────────────────────
                  GestureDetector(
                    onTap: _triggerSos,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFef4444),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFef4444).withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.emergency_share,
                              color: Colors.white, size: 28),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Emergency Assistance',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                SizedBox(height: 4),
                                Text(
                                    'Call 999 • Say "Hey GoOuts, Emergency"',
                                    style: TextStyle(
                                        color: Colors.white80,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Colors.white54),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _safetyTile(
                    icon: Icons.ios_share,
                    title: 'Share My Trip',
                    subtitle: 'Send live location to a contact',
                    showChevron: true,
                  ),
                  const SizedBox(height: 14),
                  _safetyTile(
                    icon: Icons.report_problem_outlined,
                    title: 'Report a Safety Issue',
                    subtitle: 'Non-emergency report to GoOuts',
                    showChevron: true,
                  ),
                  const SizedBox(height: 14),
                  _safetyTile(
                    icon: Icons.mic_none_outlined,
                    title: 'Record Audio',
                    subtitle: 'Encrypted recording for safety',
                    showChevron: true,
                  ),

                  const SizedBox(height: 28),

                  // ── Mini map ─────────────────────────────────────────
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF0b1a3d),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: _SafetyMapPainter(),
                            size: Size.infinite,
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF031134)
                                    .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0392ca),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Tracking Active',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Resources ────────────────────────────────────────
                  const Text('Safety Resources',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  _resourceLink('Community Guidelines'),
                  const Divider(color: Colors.white10),
                  _resourceLink('Insurance Coverage Info'),
                  const Divider(color: Colors.white10),
                  _resourceLink('How We Protect You'),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ── Floating voice indicator ─────────────────────────────────
          if (_voiceActive)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color:
                          const Color(0xFF0392ca).withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0392ca).withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic,
                        color: Color(0xFF0392ca), size: 18),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Voice Monitoring Active',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _voiceActive = !_voiceActive),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10b981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _safetyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool showChevron = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0392ca), size: 24),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (showChevron)
            const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _resourceLink(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          const Icon(Icons.open_in_new, color: Colors.white24, size: 18),
        ],
      ),
    );
  }
}

class _SafetyMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Location dot
    final dot = Paint()..color = const Color(0xFF0392ca);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 6, dot);
    // Pulse rings
    final ring = Paint()
      ..color = const Color(0xFF0392ca).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 20, ring);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 35, ring);
  }

  @override
  bool shouldRepaint(_) => false;
}
