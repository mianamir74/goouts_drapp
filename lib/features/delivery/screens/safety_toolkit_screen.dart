import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rebuilt 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 11_safety_toolkit_screen as a loose
//  visual reference — not a literal port.
//
//  Real, kept from the 6 September 2026 fix: the 999 confirmation dialog
//  (honestly states GoOuts does not auto-contact emergency services or
//  share location — it just opens the dialer) and Current Location (the
//  device's real GPS coordinates via Geolocator, not a hardcoded address).
//  Added this pass: the real GPS accuracy reading (`Position.accuracy`,
//  in metres) replacing the Stitch reference's fabricated "±4m" figure.
//
//  Dropped this pass, previously present but false: a permanent floating
//  "Voice Monitoring Active" pill and a "Tracking Active" badge on a fake
//  map — both asserted live monitoring that doesn't exist (no audio
//  pipeline, no live-location broadcast outside an active delivery). The
//  Stitch reference's own "Coming soon" framing for its three prototype
//  features (Share Trip, Report Incident, Record Audio) is the honest
//  version of the same idea and is what's used here instead. Also dropped:
//  the Stitch reference's resolved street address (no reverse-geocoding is
//  wired up), its fabricated "v2.1 • UK Road Standards" compliance-sounding
//  version footer, and its mislabelled app-bar title ("Phone Verification"
//  — an apparent copy-paste error in the reference file).
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
  static const gpsBox    = Color(0xFFF0F6FF);
  static const copyBg    = Color(0xFFDBEAFE);
  static const emergency = Color(0xFFB91C1C);
  static const alertBg   = Color(0xFFFEE2E2);
  static const advisoryBg = Color(0xFFEFF6FF);
  static const advisoryBorder = Color(0xFFBFDBFE);
  static const comingSoonBg = Color(0xFFE0F2FE);
  static const comingSoonText = Color(0xFF0369A1);
}

class SafetyToolkitScreen extends StatefulWidget {
  const SafetyToolkitScreen({super.key});

  @override
  State<SafetyToolkitScreen> createState() => _SafetyToolkitScreenState();
}

class _SafetyToolkitScreenState extends State<SafetyToolkitScreen> {
  String _coords = 'Fetching your location…';
  String? _accuracy;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _coords = 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _coords =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _accuracy = '±${pos.accuracy.toStringAsFixed(0)}m accuracy';
      });
    } catch (_) {
      if (mounted) setState(() => _coords = 'Location not available');
    }
  }

  void _copyCoordinates() {
    Clipboard.setData(ClipboardData(text: _coords));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location copied')),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  void _triggerSos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Emergency Services (999)',
            style: TextStyle(color: _C.navy, fontWeight: FontWeight.bold)),
        content: const Text(
          'Tapping Call 999 opens your phone dialer with 999 ready to '
          'call. GoOuts does not automatically contact emergency services '
          'or share your location — you place the call yourself.',
          style: TextStyle(color: _C.body, height: 1.5),
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
              backgroundColor: _C.emergency,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Call 999',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
        title: const Text('Safety Toolkit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── GPS card ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CURRENT LOCATION',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w800, color: _C.muted, letterSpacing: 0.6)),
                        if (_accuracy != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _C.paleTint,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(_accuracy!,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _C.primaryDk)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.gpsBox,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_coords,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy, height: 1.2)),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.my_location_rounded, color: _C.primaryDk, size: 22),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Share exact coordinates with emergency services or dispatch if needed in low-signal areas.',
                      style: TextStyle(fontSize: 12, color: _C.body, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _coords.contains(',') ? _copyCoordinates : null,
                        icon: const Icon(Icons.copy_rounded, size: 16, color: _C.primaryDk),
                        label: const Text('Copy GPS coordinates',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.primaryDk)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.copyBg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Emergency card ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: _C.alertBg, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.emergency_rounded, color: _C.emergency, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Emergency Services (999)',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _C.navy)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _C.emergency, borderRadius: BorderRadius.circular(10)),
                          child: const Text('URGENT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.advisoryBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.advisoryBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline_rounded, color: _C.emergency, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tapping opens your phone dialer pre-filled with 999. GoOuts does not automatically place the call, monitor this button, or track your live location.',
                              style: TextStyle(fontSize: 12, color: _C.body, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _triggerSos,
                        icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                        label: const Text('Open Phone Dialer (999)',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.emergency,
                          elevation: 2,
                          shadowColor: _C.emergency.withOpacity(0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Safety in development ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Safety In Development',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.navy)),
                  Text('Prototypes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.muted)),
                ],
              ),
              const SizedBox(height: 12),
              _prototypeCard(
                icon: Icons.radar_rounded,
                title: 'Share Live Trip',
                description: 'Share a live tracking link with trusted contacts while active on delivery shifts.',
              ),
              const SizedBox(height: 12),
              _prototypeCard(
                icon: Icons.error_outline_rounded,
                title: 'Report Safety Incident',
                description: 'Dedicated reporting for road hazards, aggressive behaviour, or vehicle accidents. Currently handled via Live Chat.',
              ),
              const SizedBox(height: 12),
              _prototypeCard(
                icon: Icons.mic_none_rounded,
                title: 'Safety Audio Recording',
                description: 'Encrypted on-device audio recording for peace of mind during pickups and handoffs.',
              ),

              const SizedBox(height: 18),

              // ── Advisory box ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.advisoryBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.advisoryBorder.withOpacity(0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.verified_user_outlined, color: _C.primaryDk, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'In an emergency involving personal safety or injury, call 999 immediately before contacting GoOuts Support.',
                        style: TextStyle(fontSize: 12, color: _C.navy, height: 1.35, fontWeight: FontWeight.w600),
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

  Widget _prototypeCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return InkWell(
      onTap: () => _showComingSoon(title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _C.comingSoonBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _C.primaryDk, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _C.navy)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: _C.comingSoonBg, borderRadius: BorderRadius.circular(12)),
                        child: Text('Coming soon',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.comingSoonText)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: _C.body, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
