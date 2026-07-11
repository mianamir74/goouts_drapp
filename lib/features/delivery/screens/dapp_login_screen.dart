import 'package:flutter/material.dart';

import '../../../features/auth/auth_service.dart';
import 'dapp_otp_screen.dart';
import 'dapp_registration_screen.dart';

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
      backgroundColor: const Color(0xFF031134),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo icon ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: const Icon(Icons.electric_moped,
                    size: 48, color: Color(0xFF0392ca)),
              ),

              const SizedBox(height: 28),

              // ── Title ─────────────────────────────────────────────
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter'),
                  children: [
                    TextSpan(
                        text: 'GoOuts ',
                        style: TextStyle(color: Colors.white)),
                    TextSpan(
                        text: 'Driver',
                        style: TextStyle(color: Color(0xFF0392ca))),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter your phone number to sign in or register',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // ── Phone input card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phone Number',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // UK flag + dial code
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF031134),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Row(
                            children: [
                              Text('🇬🇧',
                                  style: TextStyle(fontSize: 18)),
                              SizedBox(width: 6),
                              Text('+44',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Number field
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF031134),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: '7700 900000',
                                hintStyle:
                                    TextStyle(color: Colors.white24),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFf43f5e), fontSize: 13)),
                    ],

                    const SizedBox(height: 20),

                    // ── Send Code button ────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _sendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0392ca),
                          foregroundColor: const Color(0xFF031134),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF031134)))
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text('Send Code',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.white)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward,
                                      size: 20, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Register link ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New driver? ',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 16)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const DappRegistrationScreen()),
                      ),
                      child: const Text('Register here',
                          style: TextStyle(
                              color: Color(0xFF0392ca),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
