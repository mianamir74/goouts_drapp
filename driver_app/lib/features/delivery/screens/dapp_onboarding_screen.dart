import 'package:flutter/material.dart';

import 'dapp_login_screen.dart';

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
      title: 'Deliver with GoOuts',
      desc: 'Join our fleet and deliver smiles across the city on your own schedule.',
    ),
    _OnboardPage(
      asset: 'assets/delivery/bicycle.png',
      title: 'Earn Great Money',
      desc: 'Get competitive pay for every delivery and keep 100% of your tips.',
    ),
    _OnboardPage(
      asset: 'assets/delivery/motorcycle.png',
      title: 'Flexibility First',
      desc: 'Be your own boss. Work whenever and wherever you want.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 350),
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
      backgroundColor: const Color(0xFF031134),
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ─────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: TextButton(
                  onPressed: _goLogin,
                  child: const Text('Skip',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 16)),
                ),
              ),
            ),

            // ── Pages ───────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (p) => setState(() => _page = p),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            p.asset,
                            height: 300,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              height: 300,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0b1a3d),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                i == 1
                                    ? Icons.directions_bike
                                    : Icons.moped,
                                size: 100,
                                color: const Color(0xFFf97316)
                                    .withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0392ca))),
                        const SizedBox(height: 14),
                        Text(p.desc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Dots ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = _page == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? const Color(0xFF0392ca)
                        : Colors.white24,
                  ),
                );
              }),
            ),

            // ── Next / Get Started ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0b1a3d),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    side:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _page == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String asset;
  final String title;
  final String desc;
  const _OnboardPage(
      {required this.asset, required this.title, required this.desc});
}
