import 'package:flutter/material.dart';

class TripRadarScreen extends StatefulWidget {
  const TripRadarScreen({super.key});

  @override
  State<TripRadarScreen> createState() => _TripRadarScreenState();
}

class _TripRadarScreenState extends State<TripRadarScreen> {
  int _filterIdx = 0;
  static const _filters = ['All Trips', 'Highest Pay', 'Closest'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Trip Radar',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(height: 4),
                        Text('4 trips available nearby',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1a3d),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.radar,
                          color: Color(0xFF0392ca)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Map placeholder ──────────────────────────────────────
              Container(
                height: 180,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF0b1a3d),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _RadarMapPainter(),
                    child: Stack(
                      children: [
                        // Pulsing radar rings (static)
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0392ca)
                                      .withOpacity(0.15),
                                  width: 2),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0392ca)
                                      .withOpacity(0.3),
                                  width: 2),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0392ca),
                            ),
                          ),
                        ),
                        // Trip dots
                        Positioned(
                            top: 40,
                            left: 60,
                            child: _tripDot(const Color(0xFFf97316))),
                        Positioned(
                            top: 90,
                            right: 50,
                            child: _tripDot(const Color(0xFF0392ca))),
                        Positioned(
                            bottom: 40,
                            left: 80,
                            child: _tripDot(const Color(0xFF10b981))),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Filter chips ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_filters.length, (i) {
                      final sel = _filterIdx == i;
                      return Padding(
                        padding: EdgeInsets.only(right: i < _filters.length - 1 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _filterIdx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF0392ca)
                                  : const Color(0xFF0b1a3d),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: sel
                                      ? Colors.transparent
                                      : Colors.white10),
                            ),
                            child: Text(
                              _filters[i],
                              style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Trip cards ────────────────────────────────────────────
              _buildTripCard(
                price: '£18.50',
                time: '12 mins est.',
                distance: '2.4 miles',
                pickup: 'Blue Bottle Coffee, 2nd St',
                dropoff: '455 Mission District Blvd',
                tag: 'HIGH DEMAND',
                tagColor: const Color(0xFFf97316),
                isHighlighted: true,
              ),
              _buildTripCard(
                price: '£9.20',
                time: '8 mins est.',
                distance: '0.8 miles',
                pickup: 'Taco Bell, Market St',
                dropoff: '1200 Gough St, Apt 402',
              ),
              _buildTripCard(
                price: '£24.00',
                time: '25 mins est.',
                distance: '3.1 miles',
                pickup: 'Safeway Pharmacy',
                dropoff: 'Highland Hospital Plaza',
                tag: 'STACKED ORDER',
                tagColor: const Color(0xFF0392ca),
              ),

              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Orders in Trip Radar are offered to multiple drivers. '
                  'Showing interest doesn\'t guarantee the order.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripDot(Color color) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)
          ],
        ),
      );

  Widget _buildTripCard({
    required String price,
    required String time,
    required String distance,
    required String pickup,
    required String dropoff,
    String? tag,
    Color? tagColor,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0b1a3d),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isHighlighted
                ? const Color(0xFFf97316).withOpacity(0.5)
                : Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: tagColor!.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(tag,
                      style: TextStyle(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )
              else
                const SizedBox(),
              Text(distance,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10b981))),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $time',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLocationRow(
              Icons.circle, const Color(0xFF0392ca), pickup, 'Pickup'),
          const SizedBox(height: 12),
          _buildLocationRow(Icons.location_on,
              const Color(0xFFf97316), dropoff, 'Dropoff'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighlighted
                    ? const Color(0xFFf97316)
                    : const Color(0xFF031134),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.touch_app_outlined),
                  SizedBox(width: 12),
                  Text('Show Interest',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
      IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
            Text(location,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

class _RadarMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Grid lines
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
