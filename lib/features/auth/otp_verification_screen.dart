import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/business_home_screen.dart';
import '../home/driver_home_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String localMobileNumber;
  final int? resendToken;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.localMobileNumber,
    required this.resendToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const String _pendingAccountTypeKey = 'pending_account_type';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();

  late String _verificationId;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _hasReadRouteArgs = false;
  String _accountType = 'driver';

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasReadRouteArgs) {
      return;
    }

    _hasReadRouteArgs = true;

    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final String accountType = (args['accountType'] ?? 'driver')
          .toString()
          .trim()
          .toLowerCase();

      if (accountType == 'business') {
        _accountType = 'business';
      } else if (accountType == 'cab_driver') {
        _accountType = 'cab_driver';
      } else {
        _accountType = 'driver';
      }
    }
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
    await prefs.setString(_pendingAccountTypeKey, _accountType);
  }

  String _accountTypeText() {
    return _accountType == 'business'
        ? 'Business Partner'
        : 'Driver';
  }

  Future<void> _completeSuccessfulVerification() async {
    await _savePendingAccountType();

    if (!mounted) return;

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // Check if this is an existing user (forgot password / re-login)
    // or a brand new signup that still needs registration.
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final List<DocumentSnapshot<Map<String, dynamic>>> results =
        await Future.wait([
      firestore.collection('drivers').doc(user.uid).get(),
      firestore.collection('cab_drivers').doc(user.uid).get(),
      firestore.collection('businesses').doc(user.uid).get(),
    ]);

    if (!mounted) return;

    final bool isDriver    = results[0].exists;
    final bool isCabDriver = results[1].exists;
    final bool isBusiness  = results[2].exists;

    if (isBusiness) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
        (route) => false,
      );
    } else if (isDriver || isCabDriver) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        (route) => false,
      );
    } else {
      // New user — pop to root so AuthProfileGate handles registration routing
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

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
      if (!mounted) {
        return;
      }

      setState(() {
        _isVerifying = false;
      });
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
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await _completeSuccessfulVerification();
          } catch (_) {}
        },
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A new OTP has been sent.'),
            ),
          );
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
      if (!mounted) {
        return;
      }

      setState(() {
        _isResending = false;
      });
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
              SizedBox(height: 12),
              Image.asset(
                'assets/logo/goouts_logo_login.png',
                height: 160,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 24),
              AutoSizeText(
                'Enter Verification Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              AutoSizeText(
                'We sent a 6-digit code to ${widget.localMobileNumber}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 10),
              AutoSizeText(
                'You are continuing as a ${_accountTypeText()}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
              SizedBox(height: 24),
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
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : AutoSizeText(
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