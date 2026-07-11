import 'package:flutter/material.dart';

class DashboardHeatmapScreen extends StatelessWidget {
  const DashboardHeatmapScreen({super.key});

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
        title: const Text('Demand Heatmap',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stats grid ────────────────────────────────────────────
            Row(
              children: [
                _statCard("Today's Earnings", '£142.50',
                    const Color(0xFF10b981)),
                const SizedBox(width: 14),
                _statCard('Active Hours', '5h 12m', Colors.white),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statCard('Total Orders', '14', Colors.white),
                const SizedBox(width: 14),
                _statCard('Rating', '4.95 ★', const Color(0xFFf97316)),
              ],
            ),

            const SizedBox(height: 28),

            // ── Earnings forecaster header ─────────────────────────────
            Row(
              children: [
                const Icon(Icons.explore_outlined,
                    color: Color(0xFFf97316)),
                const SizedBox(width: 10),
                const Text('Earnings Forecaster',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf97316).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('High Demand',
                      style: TextStyle(
                          color: Color(0xFFf97316),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Heatmap ───────────────────────────────────────────────
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF0b1a3d),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: _HeatmapPainter(),
                      size: Size.infinite,
                    ),
                    // Legend
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF031134).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legend(const Color(0xFFf97316), 'High (£££)'),
                            const SizedBox(height: 4),
                            _legend(const Color(0xFF0392ca), 'Moderate (££)'),
                            const SizedBox(height: 4),
                            _legend(const Color(0xFF10b981), 'Low (£)'),
                          ],
                        ),
                      ),
                    ),
                    // Layer / location buttons
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          _mapBtn(Icons.layers_outlined),
                          const SizedBox(height: 8),
                          _mapBtn(Icons.my_location),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Peak hours chart ──────────────────────────────────────
            const Text("Today's Peak Hours",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Expect surges between 18:00 and 20:00',
                style:
                    TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              height: 190,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _chartBar(30, '12PM'),
                  _chartBar(50, '1PM'),
                  _chartBar(40, '2PM'),
                  _chartBar(35, '3PM'),
                  _chartBar(60, '4PM'),
                  _chartBar(80, '5PM'),
                  _chartBar(100, '6PM', peak: true),
                  _chartBar(100, '7PM', peak: true),
                  _chartBar(100, '8PM', peak: true),
                  _chartBar(70, '9PM'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Go Online CTA ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0392ca), Color(0xFF0b1a3d)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('Go Online to start earning',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text(
                    'There are 12 active orders near your location right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF031134),
                        foregroundColor: const Color(0xFF0392ca),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('START DASHING',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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

  Widget _statCard(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _mapBtn(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _chartBar(double heightFraction, String label,
      {bool peak = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 22,
          height: heightFraction * 1.2,
          decoration: BoxDecoration(
            color: peak
                ? const Color(0xFFf97316)
                : const Color(0xFF0392ca).withOpacity(0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: peak ? Colors.white70 : Colors.white24,
                fontSize: 8)),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Heat blobs
    _blob(canvas, size, 0.25, 0.35, 60, const Color(0xFFf97316), 0.3);
    _blob(canvas, size, 0.65, 0.55, 70, const Color(0xFFf97316), 0.25);
    _blob(canvas, size, 0.45, 0.7, 50, const Color(0xFF0392ca), 0.25);
    _blob(canvas, size, 0.15, 0.75, 40, const Color(0xFF10b981), 0.2);
    _blob(canvas, size, 0.8, 0.25, 45, const Color(0xFF0392ca), 0.2);
    _blob(canvas, size, 0.55, 0.2, 35, const Color(0xFF10b981), 0.18);

    // Driver dot (you)
    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(
        Offset(size.width * 0.45, size.height * 0.45), 5, dot);
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
        Offset(size.width * 0.45, size.height * 0.45), 12, ring);
  }

  void _blob(Canvas canvas, Size size, double rx, double ry,
      double radius, Color color, double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * rx, size.height * ry),
          radius: radius));
    canvas.drawCircle(
        Offset(size.width * rx, size.height * ry), radius, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
