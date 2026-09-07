import 'package:flutter/material.dart';

import 'dapp_login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 01_onboarding_screen as the visual
//  reference. Dropped from the mockup: the "SPECS: 01_ONBOARDING_SCREEN"
//  developer annotation pill (a Stitch authoring artifact, never meant to
//  ship), and two marketing claims this app cannot back up yet — "keep
//  100% of your tips" (there is no tip field anywhere in the schema; see
//  design/DRIVER_PAY_ALGORITHM_SPEC.md §4.3) and "zero platform fee"
//  (whether GoOuts takes a commission at all is an open decision in that
//  same document, §4.2). Copy below stays to what is actually true today.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const success  = Color(0xFF16A34A);
}

class DappOnboardingScreen extends StatefulWidget {
  const DappOnboardingScreen({super.key});

  @override
  State<DappOnboardingScreen> createState() => _DappOnboardingScreenState();
}

class _DappOnboardingScreenState extends State<DappOnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPage(
      asset: 'assets/delivery/motorcycle.png',
      icon: Icons.electric_moped_rounded,
      badge: 'UK Network',
      title: 'Deliver with GoOuts',
      desc: 'Join our fleet and deliver across the city, taking live order broadcasts from partner restaurants on your own schedule.',
    ),
    _OnboardPage(
      asset: 'assets/delivery/bicycle.png',
      icon: Icons.currency_pound_rounded,
      badge: 'Clear Pay',
      title: 'Know your earnings before you accept',
      desc: 'Every order offer shows your guaranteed fee upfront in £, along with distance to the venue and estimated time.',
    ),
    _OnboardPage(
      asset: 'assets/delivery/motorcycle.png',
      icon: Icons.schedule_rounded,
      badge: 'Flexible Shifts',
      title: 'Flexibility first',
      desc: 'Go online whenever you\'re ready and offline whenever you\'re not. Be your own boss.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      _goLogin();
    }
  }

  void _goLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DappLoginScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // ── Header: logo + Skip ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _C.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text('G',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                                text: 'GoOuts ',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _C.navy)),
                            TextSpan(
                                text: 'DRAPP',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _C.primary,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _goLogin,
                    child: const Text('Skip',
                        style: TextStyle(
                            color: _C.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Card ──────────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: _C.navy.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Hero illustration
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 24,
                                bottom: 16,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE4E2).withOpacity(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  _pages[_page].asset,
                                  height: 140,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    _pages[_page].icon,
                                    size: 84,
                                    color: _C.primary,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 16,
                                top: 40,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                          color: _C.navy.withOpacity(0.08),
                                          blurRadius: 10),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: _C.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Live Radar',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _C.navy)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Slide copy carousel
                      Expanded(
                        flex: 4,
                        child: PageView.builder(
                          controller: _ctrl,
                          onPageChanged: (p) => setState(() => _page = p),
                          itemCount: _pages.length,
                          itemBuilder: (_, i) {
                            final p = _pages[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _C.paleTint,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(p.badge,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _C.primary)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(p.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _C.navy,
                                          letterSpacing: -0.3)),
                                  const SizedBox(height: 10),
                                  Text(p.desc,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          color: _C.body,
                                          height: 1.45)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final active = _page == i;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? _C.primary : _C.muted.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Next / Get Started ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accent,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: _C.accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _page == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16.5),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Footer login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(fontSize: 13.5, color: _C.body)),
                  GestureDetector(
                    onTap: _goLogin,
                    child: const Text('Log In',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _C.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String asset;
  final IconData icon;
  final String badge;
  final String title;
  final String desc;
  const _OnboardPage({
    required this.asset,
    required this.icon,
    required this.badge,
    required this.title,
    required this.desc,
  });
}
