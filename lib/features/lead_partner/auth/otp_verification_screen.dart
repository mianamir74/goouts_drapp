import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/business_home_screen.dart';
import 'auth_flow_guard.dart';
import 'business_referral_code_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Adapted from driver_app/lib/features/auth/otp_verification_screen.dart,
//  11 September 2026, as part of the goouts_drapp / driver_app merge
//  (design/PARTNER_ECOSYSTEM_ARCHITECTURE.md §4). Driver / cab-driver
//  branches removed — this screen only ever follows LeadPartnerLoginScreen,
//  so it only checks the 'lead_partners' collection.
// ─────────────────────────────────────────────────────────────────────────────
class LeadPartnerOtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String localMobileNumber;
  final int? resendToken;

  const LeadPartnerOtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.localMobileNumber,
    required this.resendToken,
  });

  @override
  State<LeadPartnerOtpVerificationScreen> createState() =>
      _LeadPartnerOtpVerificationScreenState();
}

class _LeadPartnerOtpVerificationScreenState
    extends State<LeadPartnerOtpVerificationScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const String _pendingAccountTypeKey = 'pending_account_type';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();

  late String _verificationId;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _hasNavigated = false; // guard against double navigation (verificationCompleted + manual OTP race)

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String? _otpValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required';
    }

    final String cleaned = value.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(cleaned)) {
      return 'Enter the 6-digit OTP';
    }

    return null;
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'The OTP you entered is invalid.';
      case 'session-expired':
        return 'The OTP has expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'invalid-phone-number':
        return 'The mobile number format is invalid.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for this project. Please try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePendingAccountType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAccountTypeKey, 'business');
  }

  // Breadcrumbs — written to Crashlytics so a failed verification can be
  // traced to the exact step afterwards.
  void _bc(String step) {
    FirebaseCrashlytics.instance.log('LEAD-PARTNER-OTP-VERIFY: $step');
  }

  Future<void> _completeSuccessfulVerification() async {
    // Guard against double navigation (verificationCompleted firing after codeSent on Android).
    // If we've already run once for this attempt, that earlier run's own
    // try/finally below already released AuthFlowGuard — nothing left to do.
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Everything below can exit early (unmounted widget, no signed-in user),
    // throw or time out (the Firestore lead_partners lookup), or complete
    // normally. Whichever happens, AuthFlowGuard.end() below in `finally`
    // guarantees the guard started in LeadPartnerLoginScreen._handleContinue()
    // is always released — otherwise the root app gate is stuck on its
    // spinner for the rest of this app process even though sign-in succeeded.
    try {
      _bc('completeVerification: start');
      await _savePendingAccountType();
      _bc('completeVerification: saved pending account type');

      if (!mounted) return;

      final User? user = FirebaseAuth.instance.currentUser;
      _bc('completeVerification: currentUser=${user?.uid ?? "null"}');

      if (user == null) {
        // Sign-in completed but no user returned — release guard and pop to root
        AuthFlowGuard.end();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      _bc('completeVerification: querying lead_partners');
      final DocumentSnapshot<Map<String, dynamic>> businessResult =
          await FirebaseFirestore.instance
              .collection('lead_partners')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 6));
      _bc('completeVerification: firestore lookup done');

      final bool isBusiness = businessResult.exists;

      if (!mounted) return;

      // Release guard just before navigation.
      AuthFlowGuard.end();

      if (isBusiness) {
        _bc('completeVerification: navigating to BusinessHomeScreen');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
          (route) => false,
        );
      } else {
        // New user — send to Lead Partner registration.
        _bc('completeVerification: navigating to BusinessReferralCodeScreen');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessReferralCodeScreen()),
          (route) => false,
        );
      }
      _bc('completeVerification: navigation call returned');
    } finally {
      // Safety net for every early-return / exception / timeout path above.
      // On both success sub-paths AuthFlowGuard.end() was already called
      // above; calling it again here is a harmless no-op (AuthFlowGuard.end()
      // is idempotent).
      AuthFlowGuard.end();
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      _bc('verifyOtp: building credential');
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      _bc('verifyOtp: calling signInWithCredential');
      // Timeout added as a safety net — if Firebase's native handshake here
      // hangs/spins instead of returning cleanly, this at least stops OUR
      // code from waiting forever and surfaces a catchable error instead of
      // the app going blank and dying.
      await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 8));
      _bc('verifyOtp: signInWithCredential returned successfully');

      await _completeSuccessfulVerification();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      await _showErrorDialog(
        'Verification Failed',
        _firebaseErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _showErrorDialog(
        'Error',
        'Failed to verify OTP.\n\n$e',
      );
    } finally {
      // A `return` inside `finally` silently discards whatever the try/catch
      // above was doing — use a plain `if (mounted)` guard instead.
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        // Don't auto-sign-in on resend either — same race as the initial
        // send: user resends, then manually types the new code and hits
        // Continue (_verifyOtp) while this callback is still alive.
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) async {
          if (!mounted) {
            return;
          }

          await _showErrorDialog(
            'Resend Failed',
            _firebaseErrorMessage(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) {
            return;
          }

          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
          });

          GoOutsSheet.info(context, title: 'Code Sent', message: 'A new OTP has been sent to your phone.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) {
            return;
          }

          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      await _showErrorDialog(
        'Resend Failed',
        _firebaseErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _showErrorDialog(
        'Error',
        'Failed to resend OTP.\n\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _goOutsBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'Verify OTP',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Image.asset(
                'assets/logo/goouts_logo_white.png',
                height: 160,
                fit: BoxFit.contain,
                color: _goOutsBlue,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.verified_user_rounded,
                  size: 80,
                  color: _goOutsBlue,
                ),
              ),
              const SizedBox(height: 24),
              const AutoSizeText(
                'Enter Verification Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              AutoSizeText(
                'We sent a 6-digit code to ${widget.localMobileNumber}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const AutoSizeText(
                'You are continuing as a Lead Partner.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              AutofillGroup(
                child: Form(
                key: _formKey,
                child: TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: _inputDecoration('6-digit OTP').copyWith(
                    hintText: '123456',
                    hintStyle: const TextStyle(letterSpacing: 4),
                  ),
                  validator: _otpValidator,
                ),
              ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goOutsBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const AutoSizeText(
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isResending || _isVerifying ? null : _resendCode,
                child: _isResending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Resend OTP',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
