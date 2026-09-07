import 'package:flutter/material.dart';

import '../../../features/auth/auth_service.dart';
import 'dapp_otp_screen.dart';
import 'dapp_registration_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 02_login_screen as the visual reference.
//
//  ⚠ NOT carried over from the Stitch mockup: the "AUTH PIPELINE ACTIVE"
//  developer annotation pill (an authoring artifact), the "10 minutes"
//  specific OTP-expiry claim (not a confirmed figure), and the
//  "Instant payouts" / "Free rider insurance" trust badges — instant pay is
//  explicitly NOT live yet (see earnings_screen.dart's instantPayAvailable
//  guard) and there is no evidence rider insurance is a real, live benefit,
//  so claiming either here would be the exact kind of false promise this
//  codebase has been removing all session. The "London, Manchester, and
//  Birmingham" specific city claim was also dropped — not a confirmed
//  launch-city commitment.
//
//  Passkey / Face ID sign-in has no biometric backend behind it (there is
//  no WebAuthn/passkey infra anywhere in this app), so — same as the
//  customer-phone button in active_delivery_screen.dart — it stays visible
//  but honestly disabled rather than faking a success snackbar.
//
//  All real logic — AuthService.sendOtp, the E.164 phone formatting, and
//  the OTP-screen handoff — is unchanged from before this pass.
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
  static const error    = Color(0xFFEF4444);
}

class DappLoginScreen extends StatefulWidget {
  const DappLoginScreen({super.key});

  @override
  State<DappLoginScreen> createState() => _DappLoginScreenState();
}

class _DappLoginScreenState extends State<DappLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _authSvc   = AuthService();
  bool   _loading  = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = '+44${_phoneCtrl.text.trim().replaceAll(' ', '')}';
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    await _authSvc.sendOtp(
      phoneNumber: phone,
      onCodeSent: (vid) {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DappOtpScreen(
              verificationId: vid,
              phoneNumber: phone,
            ),
          ),
        );
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pushReplacementNamed(context, '/delivery');
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() { _loading = false; _error = msg; });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        title: const Text('Sign In',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Brand wordmark ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: _C.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('G',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                            text: 'GoOuts ',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _C.navy)),
                        TextSpan(
                            text: 'DRAPP',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _C.primary,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Driver sign in',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.navy,
                      letterSpacing: -0.4)),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Enter your UK mobile number. We\'ll text you a verification code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _C.body, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),

              // ── Phone input card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _C.navy.withOpacity(0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('UK Mobile Number',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _C.navy)),
                        Row(
                          children: const [
                            Icon(Icons.lock_outline_rounded,
                                size: 14, color: _C.primary),
                            SizedBox(width: 4),
                            Text('Secure SMS',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _C.primary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.primary.withOpacity(0.15)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _C.muted.withOpacity(0.2)),
                            ),
                            child: const Row(
                              children: [
                                Text('🇬🇧', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 6),
                                Text('+44',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _C.navy)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: _C.navy,
                                  letterSpacing: 0.5),
                              decoration: InputDecoration(
                                hintText: '7700 900000',
                                hintStyle: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: _C.muted.withOpacity(0.6)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: const [
                        Icon(Icons.electric_bike_rounded,
                            size: 18, color: _C.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Supports bicycle, e-bike, scooter, and car courier accounts.',
                            style: TextStyle(fontSize: 12, color: _C.body),
                          ),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(color: _C.error, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Rate notice banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _C.paleTint.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 17, color: _C.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Standard SMS message and data rates may apply.',
                        style: TextStyle(fontSize: 11.5, color: _C.body, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Send Code button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accent,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: _C.accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Send verification code',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Passkey / Face ID — no biometric backend exists yet.
              // Honestly disabled rather than faking a success snackbar.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: _C.muted.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, color: _C.muted, size: 22),
                      const SizedBox(width: 10),
                      Text('Passkey / Face ID — coming soon',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _C.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Registration card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _C.navy.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.circle, size: 8, color: _C.accent),
                        SizedBox(width: 8),
                        Text('New to GoOuts Drapp?',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _C.navy)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Earn on your own schedule, wherever you deliver.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _C.body, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DappRegistrationScreen()),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('Register as a courier',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _C.primary)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 16, color: _C.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
