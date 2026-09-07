import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rebuilt 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 18_trip_radar_screen as a loose visual
//  reference — not a literal port.
//
//  ⚠ STILL FLAGGED, STILL NOT REAL — same call as 6 September 2026, now
//  extended to the Stitch reference too. This is a competing concept from
//  the real dispatch system (acceptFoodOrder/declineFoodOrder, broadcast
//  offers via new_order_offer_screen.dart): "browse several open trips and
//  show interest" vs. "first driver to accept a broadcast alert gets it".
//  Reconciling those is a product decision, not a wiring job, so this stays
//  visual-shell demo content rather than becoming a second, conflicting
//  dispatch flow.
//
//  Not carried over from the Stitch reference for that reason: its fake
//  Firestore-shaped broadcast list (Honest Burgers Soho, Rudy's Neapolitan
//  Pizza, Dishoom Manchester — specific fabricated venues/addresses), its
//  live 5-second auto-refresh countdown (nothing is actually refreshing),
//  its "£X.XX GUARANTEED" payout labels (a financial promise this demo
//  can't back), "Accept Order" button copy (implies this really accepts an
//  order through the live dispatch pipeline — it doesn't), and its own
//  5-tab bottom nav duplicating the app's real navigation. Taps now show an
//  honest "not connected to live orders yet" message instead of doing
//  nothing at all.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F4F7);
  static const surface   = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy      = Color(0xFF0D1B3E);
  static const body      = Color(0xFF475569);
  static const muted     = Color(0xFF94A3B8);
  static const paleTint  = Color(0xFFE0F3FB);
  static const success   = Color(0xFF16A34A);
  static const accent    = Color(0xFFF97316);
  static const engineBg  = Color(0xFFE0F2FE);
}

class TripRadarScreen extends StatefulWidget {
  const TripRadarScreen({super.key});

  @override
  State<TripRadarScreen> createState() => _TripRadarScreenState();
}

class _TripRadarScreenState extends State<TripRadarScreen> {
  int _filterIdx = 0;
  static const _filters = ['All Trips', 'Highest Pay', 'Closest'];

  void _notConnected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip Radar is a preview — not connected to live orders yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Trip Radar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('PREVIEW', style: TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          SizedBox(height: 2),
                          Text('3 trips available nearby', style: TextStyle(color: _C.body, fontSize: 14)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.radar_rounded, color: _C.primaryDk),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Single dispatch engine note ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _C.engineBg.withOpacity(0.6), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 18, color: _C.primaryDk),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is a preview of what browsing open trips could look like. Right now, orders are offered one driver at a time — see your incoming alert cards.',
                          style: TextStyle(fontSize: 12, color: _C.navy, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? _C.primaryDk : _C.surface,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              _filters[i],
                              style: TextStyle(color: sel ? Colors.white : _C.body, fontWeight: FontWeight.bold, fontSize: 13),
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
                tagColor: _C.accent,
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
                tagColor: _C.primary,
              ),

              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'This is a preview screen. Trips shown here are illustrative and are not live orders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _C.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

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
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isHighlighted ? _C.accent.withOpacity(0.5) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: tagColor!.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(tag, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                const SizedBox(),
              Text(distance, style: const TextStyle(color: _C.navy, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _C.success)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $time', style: const TextStyle(color: _C.muted, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLocationRow(Icons.circle, _C.primary, pickup, 'Pickup'),
          const SizedBox(height: 12),
          _buildLocationRow(Icons.location_on, _C.accent, dropoff, 'Dropoff'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _notConnected,
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighlighted ? _C.accent : _C.paleTint,
                foregroundColor: isHighlighted ? Colors.white : _C.primaryDk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined),
                  SizedBox(width: 12),
                  Text('Show Interest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _C.muted, fontSize: 10)),
            Text(location, style: const TextStyle(color: _C.navy, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
