import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/auth/auth_service.dart';
import 'main_delivery_scaffold.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 03_otp_screen as the visual reference.
//
//  ⚠ NOT carried over from the Stitch mockup: the "Fill Code: 482-901"
//  auto-fill suggestion pill (it pre-populated a fake, made-up code — the
//  single most dangerous thing to fake on an auth screen), the "Expires in
//  04:58" countdown (Firebase controls real code expiry; this app has no
//  visibility into the real remaining time, so it can't display one
//  honestly), the "Automated call" backup button (no Twilio Voice or any
//  calling provider exists in this project — see the identical note on the
//  customer-phone button in active_delivery_screen.dart), and the
//  "Protected with GoOuts Driver Authenticator & TLS 1.3" footer (neither
//  is a real, named product/claim this app can back up).
//
//  ⚠ WIRED 7 September 2026. Resend SMS used to not exist as a concept
//  anywhere on this screen. It now really re-sends via AuthService.sendOtp
//  and swaps in the fresh verificationId, gated by a real local cooldown
//  (a client-side rate limit we control, not a claim about server-side code
//  expiry) so a driver can't spam Firebase's phone-auth quota.
//
//  All other real logic — the 6-cell OTP entry, SMS autofill via
//  AutofillHints.oneTimeCode, the backspace-across-boxes handling, and
//  AuthService.verifyOtp — is unchanged from before this pass.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const error    = Color(0xFFEF4444);
}

class DappOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  const DappOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<DappOtpScreen> createState() => _DappOtpScreenState();
}

class _DappOtpScreenState extends State<DappOtpScreen> {
  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());
  // CRITICAL FIX: separate FocusNodes for the KeyboardListener wrappers — a
  // FocusNode can only be attached to one widget at a time. Sharing one
  // between the KeyboardListener and its TextField makes them fight over
  // attaching it, looping unbounded and blowing memory until iOS kills the
  // app. Same crash pattern as driver_app's referral code screen.
  final List<FocusNode> _keyEventFocus =
      List.generate(6, (_) => FocusNode(skipTraversal: true));
  final _authSvc = AuthService();
  bool   _loading = false;
  String? _error;

  late String _verificationId = widget.verificationId;
  bool _resending = false;
  int  _resendCooldown = 30;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
    for (final f in _keyEventFocus) f.dispose();
    super.dispose();
  }

  void _fillFromString(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return;
    for (int i = 0; i < 6; i++) {
      _ctrl[i].text = digits[i];
    }
    _focus[5].requestFocus();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 150), _verify);
  }

  // Backspace pressed while a box is already empty — jump back to the
  // previous box and clear it, so backspace works continuously without
  // the user needing to manually tap each box.
  void _handleBackspaceOnEmpty(int index) {
    if (index <= 0) return;
    _ctrl[index - 1].clear();
    _focus[index - 1].requestFocus();
    setState(() {});
  }

  Future<void> _verify() async {
    final code = _ctrl.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _authSvc.verifyOtp(
          verificationId: _verificationId, smsCode: code);
      if (!mounted) return;
      // Check if driver doc exists
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      // Navigate to main or registration
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDeliveryScaffold()),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Invalid code. Please try again.';
      });
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() { _resending = true; _error = null; });
    await _authSvc.sendOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (vid) {
        if (!mounted) return;
        setState(() {
          _verificationId = vid;
          _resending = false;
        });
        for (final c in _ctrl) {
          c.clear();
        }
        _focus[0].requestFocus();
        _startCooldown();
        GoOutsSheet.success(context,
            title: 'Code resent',
            message: 'A new verification code has been sent to ${widget.phoneNumber}.');
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _resending = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainDeliveryScaffold()),
        );
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() { _resending = false; _error = msg; });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Phone Verification',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _C.paleTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.sms_outlined, size: 40, color: _C.primary),
              ),
              const SizedBox(height: 24),
              const Text('Enter Verification Code',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.body, fontSize: 14.5, height: 1.4),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit_outlined, size: 15, color: _C.primary),
                    SizedBox(width: 4),
                    Text('Edit mobile number',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _C.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // OTP boxes card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _C.navy.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: AutofillGroup(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (i) => _otpBox(i)),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!,
                    style: const TextStyle(color: _C.error, fontSize: 13)),
              ],

              const SizedBox(height: 20),

              // Resend card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _C.navy.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: const [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 15, color: _C.body),
                          SizedBox(width: 6),
                          Text("Didn't receive a message?",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _C.navy)),
                        ]),
                        Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Available now',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _resendCooldown > 0 ? _C.muted : _C.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: (_resendCooldown == 0 && !_resending) ? _resend : null,
                        icon: _resending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _C.primary))
                            : Icon(Icons.refresh_rounded,
                                size: 16,
                                color: _resendCooldown == 0 ? _C.primary : _C.muted),
                        label: Text('Resend SMS',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _resendCooldown == 0 ? _C.navy : _C.muted)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F6FB),
                          side: BorderSide(color: _C.muted.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
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
                            Text('Verify & Continue',
                                style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 46,
      height: 54,
      child: KeyboardListener(
        focusNode: _keyEventFocus[i],
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _ctrl[i].text.isEmpty) {
            _handleBackspaceOnEmpty(i);
          }
        },
        child: TextField(
        controller: _ctrl[i],
        focusNode: _focus[i],
        textAlign: TextAlign.center,
        // box 0 accepts 6 chars so SMS autofill / paste can insert the full
        // code at once; _fillFromString then distributes it across all boxes
        maxLength: i == 0 ? 6 : 1,
        autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
        keyboardType: TextInputType.number,
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _C.navy),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFEFF5FD),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBCE1F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBCE1F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.primary, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.length == 6) {
            // Full paste OR SMS autofill into box 0 — distribute across all boxes
            _fillFromString(val);
            return;
          }
          if (val.isNotEmpty && i < 5) {
            _focus[i + 1].requestFocus();
          }
          if (i == 5 && val.isNotEmpty) _verify();
        },
        ),
      ),
    );
  }
}
