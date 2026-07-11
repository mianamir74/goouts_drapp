import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../features/auth/auth_service.dart';
import 'main_delivery_scaffold.dart';
import 'dapp_registration_screen.dart';

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
  final _authSvc = AuthService();
  bool   _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
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
          verificationId: widget.verificationId, smsCode: code);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.sms_outlined,
                size: 60, color: Color(0xFF0392ca)),
            const SizedBox(height: 24),
            const Text('Enter Verification Code',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              'We sent a 6-digit code to\n${widget.phoneNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 40),
            // OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => _otpBox(i)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFf43f5e), fontSize: 13)),
            ],
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0392ca),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Verify Code',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {},
              child: const Text("Didn't receive it? Resend",
                  style: TextStyle(
                      color: Color(0xFF0392ca), fontSize: 14)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _ctrl[i],
        focusNode: _focus[i],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFF0b1a3d),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF0392ca), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && i < 5) {
            _focus[i + 1].requestFocus();
          } else if (val.isEmpty && i > 0) {
            _focus[i - 1].requestFocus();
          }
          if (i == 5 && val.isNotEmpty) _verify();
        },
      ),
    );
  }
}
