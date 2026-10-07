import 'package:flutter/material.dart';

import '../delivery/screens/dapp_onboarding_screen.dart';
import 'auth/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEW 11 September 2026, added as part of the goouts_drapp / driver_app
//  merge (design/PARTNER_ECOSYSTEM_ARCHITECTURE.md §4). This is the new true
//  entry point for signed-out users: it mirrors driver_app's current
//  RoleSelectionScreen options exactly (Delivery Driver / Lead Partner, Cab
//  Driver still hidden until post-launch activation — out of scope here),
//  styled to match goouts_drapp's existing light-theme visual system
//  (see DappOnboardingScreen / design/STITCH_6_DRAPP.md) rather than
//  reproducing driver_app's own screen chrome.
//
//  Driver  → goouts_drapp's existing DappOnboardingScreen → DappLoginScreen
//            → DappOtpScreen → DappRegistrationScreen → MainDeliveryScaffold
//            chain, completely unchanged.
//  Lead Partner → the new LeadPartnerLoginScreen → LeadPartnerOtpVerification
//            Screen → BusinessRegistrationScreen → BusinessHomeScreen chain
//            under features/lead_partner/.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
}

class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  void _chooseDriver(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DappOnboardingScreen()),
    );
  }

  void _chooseLeadPartner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeadPartnerLoginScreen()),
    );
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
              Row(
                children: [
                  // ⚠ 16 September 2026, requested directly: logo reduced
                  // 20% (36→29, 22→17.6) to free vertical room so the whole
                  // screen fits in one mobile canvas without scrolling.
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text('G',
                        style: TextStyle(
                            fontSize: 17.6,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  const RichText(
                    text: TextSpan(
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
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ⚠ 16 September 2026, requested directly: reduced 35%
                    // (22→14.3) for the same one-screen-fit reason as the
                    // logo above.
                    const Text(
                      'Select your role',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.3,
                        fontWeight: FontWeight.w800,
                        color: _C.navy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the option that matches you best.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: _C.body,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _RoleCard(
                      title: 'Delivery Driver',
                      subtitle: 'Continue as Delivery Driver',
                      icon: Icons.delivery_dining_rounded,
                      color: _C.primary,
                      onTap: () => _chooseDriver(context),
                    ),
                    // ── CAB DRIVER — hidden until post-launch activation ──
                    // const SizedBox(height: 14),
                    // _RoleCard(
                    //   title: 'Rider Driver',
                    //   subtitle: 'Continue as Rider Driver',
                    //   icon: Icons.local_taxi_rounded,
                    //   color: Color(0xFF22C55E),
                    //   onTap: () => _chooseCabDriver(context),
                    // ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      title: 'Lead Partner',
                      subtitle: 'Continue as Lead Partner',
                      icon: Icons.storefront_rounded,
                      color: _C.accent,
                      onTap: () => _chooseLeadPartner(context),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                'You can switch roles later from your account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _C.muted),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
