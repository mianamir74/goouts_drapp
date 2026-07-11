import 'package:flutter/material.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _scanning = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _verified = false; });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() { _scanning = false; _verified = true; });
  }

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
        title: const Text('Identity Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Secure Your Account',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 12),
            const Text(
              'To prevent unauthorized use and ensure community safety, '
              'please verify your identity with a quick facial scan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 15, height: 1.5),
            ),

            const Spacer(),

            // ── Face scanner ─────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _scanning ? _pulse.value : 1.0,
                child: child,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 290,
                    height: 290,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _verified
                            ? const Color(0xFF10b981).withOpacity(0.4)
                            : const Color(0xFF0392ca).withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ),
                  // Face area (oval clip)
                  ClipOval(
                    child: Container(
                      width: 260,
                      height: 260,
                      color: const Color(0xFF0b1a3d),
                      child: CustomPaint(
                          painter: _FaceScanPainter(
                              _scanning, _verified)),
                    ),
                  ),
                  // Status badge
                  Positioned(
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1a3d).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _verified
                              ? const Color(0xFF10b981)
                              : const Color(0xFF0392ca),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _verified
                                  ? const Color(0xFF10b981)
                                  : _scanning
                                      ? const Color(0xFFf97316)
                                      : const Color(0xFF0392ca),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _verified
                                ? 'Identity Verified ✓'
                                : _scanning
                                    ? 'Scanning...'
                                    : 'Looking for face...',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              _verified
                  ? 'Verification complete!'
                  : 'Position your face within the frame',
              style: TextStyle(
                  color:
                      _verified ? const Color(0xFF10b981) : Colors.white70,
                  fontSize: 16),
            ),

            const Spacer(),

            // ── Guidelines card ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GUIDELINES',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  _guideline(Icons.wb_sunny_outlined, 'Ensure good lighting',
                      'Avoid harsh shadows or backlights.'),
                  const SizedBox(height: 12),
                  _guideline(Icons.visibility_off_outlined,
                      'Remove glasses or masks',
                      'Your full face must be clearly visible.'),
                  const SizedBox(height: 12),
                  _guideline(Icons.stay_current_portrait_outlined,
                      'Hold steady',
                      'Keep your phone at eye level.'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _scanning ? null : _startScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verified
                      ? const Color(0xFF10b981)
                      : const Color(0xFFf97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _scanning
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_verified
                              ? Icons.check_circle_outline
                              : Icons.camera_alt_outlined),
                          const SizedBox(width: 12),
                          Text(
                            _verified ? 'Continue' : 'Start Scan',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _guideline(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF031134),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF0392ca), size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FaceScanPainter extends CustomPainter {
  final bool scanning;
  final bool verified;
  const _FaceScanPainter(this.scanning, this.verified);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background gradient
    final bg = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0b1a3d),
          const Color(0xFF031134),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy), radius: size.width / 2));
    canvas.drawCircle(Offset(cx, cy), size.width / 2, bg);

    // Face outline oval
    final facePaint = Paint()
      ..color = verified
          ? const Color(0xFF10b981).withOpacity(0.4)
          : scanning
              ? const Color(0xFFf97316).withOpacity(0.3)
              : const Color(0xFF0392ca).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy - 10),
          width: size.width * 0.55,
          height: size.height * 0.65),
      facePaint,
    );

    // Scan line (when scanning)
    if (scanning) {
      final linePaint = Paint()
        ..color = const Color(0xFF0392ca).withOpacity(0.6)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(cx - size.width * 0.3, cy),
        Offset(cx + size.width * 0.3, cy),
        linePaint,
      );
    }

    // Checkmark (when verified)
    if (verified) {
      final checkPaint = Paint()
        ..color = const Color(0xFF10b981)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(cx - 20, cy)
        ..lineTo(cx - 5, cy + 15)
        ..lineTo(cx + 20, cy - 15);
      canvas.drawPath(path, checkPaint);
    }

    // Scan dots (corner markers)
    final dotPaint = Paint()
      ..color = (verified
              ? const Color(0xFF10b981)
              : const Color(0xFF0392ca))
          .withOpacity(0.5)
      ..style = PaintingStyle.fill;
    const r = 3.0;
    final points = [
      Offset(cx - 50, cy - 60),
      Offset(cx + 50, cy - 60),
      Offset(cx - 50, cy + 50),
      Offset(cx + 50, cy + 50),
    ];
    for (final p in points) {
      canvas.drawCircle(p, r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceScanPainter old) =>
      old.scanning != scanning || old.verified != verified;
}
