import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rebuilt 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 12_dashboard_heatmap_screen as a loose
//  visual reference — not a literal port.
//
//  ⚠ REPLACED, not just reskinned. The screen this file used to contain was
//  entirely fabricated: hardcoded "£142.50" earnings / "5h 12m" active hours
//  / "14" total orders / "4.95 ★" rating stat cards (none read from Firestore
//  — just static numbers), a fake CustomPaint "heatmap" with hardcoded demand
//  blobs, a fake fixed-data peak-hours bar chart (12PM–9PM), and a claim of
//  "12 active orders near your location right now" backed by nothing.
//
//  No real zone-demand/heatmap backend exists (no `zone_analytics` collection,
//  no live broadcast-density pipeline). The Stitch reference for this screen
//  independently reaches the same honest conclusion the fake live file
//  should have — that this feature isn't built yet — so its "Coming soon"
//  framing is what's kept. Not carried over from the reference: its own
//  fabricated specifics (a "64% statistical significance" figure, a
//  "Telemetry v2.4" debug pill, a "1.2x boost" multiplier, named
//  Soho/Fitzrovia/Camden "recommended shifts" presented as if from real
//  courier survey data, a live-notification toggle with no notification
//  pipeline behind it, and its mislabelled app-bar title "Phone
//  Verification" — an apparent copy-paste error in the reference file).
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F4F7);
  static const surface   = Color(0xFFFFFFFF);
  static const primaryDk = Color(0xFF006488);
  static const navy      = Color(0xFF0D1B3E);
  static const body      = Color(0xFF475569);
  static const muted     = Color(0xFF94A3B8);
  static const ringOuter = Color(0xFFBAE6FD);
  static const ringInner = Color(0xFF7DD3FC);
  static const core      = Color(0xFF0284C7);
  static const comingSoonBg = Color(0xFFDCEBFA);
  static const comingSoonText = Color(0xFF0284C7);
  static const safeguardBg = Color(0xFFEFF6FF);
  static const safeguardBorder = Color(0xFFBFDBFE);
}

class DashboardHeatmapScreen extends StatelessWidget {
  const DashboardHeatmapScreen({super.key});

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
        title: const Text('Demand Map',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _C.ringOuter.withOpacity(0.7), width: 1.5),
                            ),
                          ),
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _C.ringInner, width: 2),
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: _C.core, width: 2.5),
                            ),
                            child: Center(
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: const BoxDecoration(color: _C.core, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(color: _C.comingSoonBg, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: _C.comingSoonText),
                          const SizedBox(width: 6),
                          Text('COMING SOON',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _C.comingSoonText, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'We\'re building real demand data for your area',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.4, height: 1.25),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We\'re expanding restaurant partner coverage across London. Live demand heatmaps will switch on once there\'s enough real order data to be accurate — no guesswork in the meantime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _C.body, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.safeguardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _C.safeguardBorder.withOpacity(0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.verified_user_outlined, size: 18, color: _C.primaryDk),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Zero speculative projections. We\'ll only ever show verified order data — never a guess dressed up as one.',
                              style: TextStyle(fontSize: 12, color: _C.navy, height: 1.4, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
