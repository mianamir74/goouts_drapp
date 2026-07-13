import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/business_home_screen.dart';
import '../home/driver_home_screen.dart';
import 'otp_verification_screen.dart';
import 'referral_code_screen.dart';
import 'business_referral_code_screen.dart';
import 'widgets/pre_auth_support_sheet.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);

  static const String _pendingAccountTypeKey = 'pending_account_type';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _selectedAccountType = 'driver';
  bool _hasReadRouteArgs = false;
  bool _isReturningUser = false;
  bool _obscurePassword = true;

  // Simple country picker state
  String _selectedDialCode = '+44';
  String _selectedFlag = '🇬🇧';

  StreamSubscription<User?>? _authSubscription;
  bool _skipFirstAuthEvent = true;

  @override
  void initState() {
    super.initState();
    // Skip the first emission (current state on subscribe) — we only want to
    // react when the user actively signs in via OTP on this screen.
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (_skipFirstAuthEvent) {
        _skipFirstAuthEvent = false;
        return;
      }
      if (user != null && mounted) {
        await _navigateToHomeForExistingUser(user);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        _selectedAccountType = 'business';
      } else if (accountType == 'cab_driver') {
        _selectedAccountType = 'cab_driver';
      } else {
        _selectedAccountType = 'driver';
      }

      // Pre-fill mobile number if passed (e.g. after logout)
      final String mobile = (args['mobile'] ?? '').toString().trim();
      if (mobile.isNotEmpty) {
        _mobileController.text = mobile;
      }

      // Show password field if this is a returning user (came from logout)
      final bool returningUser = args['isReturningUser'] == true;
      if (returningUser) {
        _isReturningUser = true;
      }
    }
  }

  String? _mobileValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }

    final String cleaned = value.trim().replaceAll(RegExp(r'\s+'), '');

    if (cleaned.length != 11) {
      return 'Mobile number must be 11 digits';
    }

    if (!RegExp(r'^07\d{9}$').hasMatch(cleaned)) {
      return 'Enter a valid UK mobile number';
    }

    return null;
  }

  String _toE164UkNumber(String localNumber) {
    final String cleaned = localNumber.replaceAll(RegExp(r'\s+'), '');

    // If UK selected and number is UK format, convert 07xxxxxxxxx to +44xxxxxxxxx
    if (_selectedDialCode == '+44' &&
        cleaned.startsWith('07') &&
        cleaned.length == 11) {
      return '+44${cleaned.substring(1)}';
    }

    // For other codes, just prepend selected dial code to digits
    if (_selectedDialCode.isNotEmpty && !cleaned.startsWith('+')) {
      final String digitsOnly =
          cleaned.replaceAll(RegExp(r'[^0-9]'), '');
      return '$_selectedDialCode$digitsOnly';
    }

    return cleaned;
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The mobile number format is invalid.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for this project. Please try again later.';
      case 'captcha-check-failed':
        return 'App verification failed. Please try again.';
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication.';
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToHomeForExistingUser(User user) async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
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
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (_isLoading) return;

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    final String localMobile = _mobileController.text.trim();
    final String e164 = _toE164UkNumber(localMobile);
    final String emailForAuth =
        '${e164.replaceAll('+', '').replaceAll(' ', '')}@goouts.app';

    setState(() => _isLoading = true);

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailForAuth,
        password: _passwordController.text,
      );

      // Mirror the OTP flow — save account type so main.dart routes correctly
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingAccountTypeKey, _selectedAccountType);

      if (!mounted) return;

      final User? user = credential.user;
      if (user != null) {
        await _navigateToHomeForExistingUser(user);
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Incorrect PIN. Please try again or tap "Forgot PIN?" to reset via OTP.';
        case 'user-not-found':
          message =
              'No account linked to this number. Please use OTP login.';
        case 'too-many-requests':
          message = 'Too many attempts. Please wait a moment and try again.';
        default:
          message = e.message ?? 'Something went wrong. Please try again.';
      }
      await _showErrorDialog('Login Failed', message);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Error', 'Login failed.\n\n$e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _forgotPin() {
    setState(() {
      _isReturningUser = false;
      _passwordController.clear();
    });
  }

  Future<void> _handleContinue() async {
    if (_isLoading) {
      return;
    }

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String localMobile = _mobileController.text.trim();
    final String e164PhoneNumber = _toE164UkNumber(localMobile);

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164PhoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);

            if (!mounted) {
              return;
            }

            GoOutsSheet.success(context, title: 'Verified', message: 'Phone number verified successfully.');
          } on FirebaseAuthException catch (e) {
            if (!mounted) {
              return;
            }

            await _showErrorDialog(
              'Verification Failed',
              _firebaseErrorMessage(e),
            );
          } finally {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = false;
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) async {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
          });

          await _showErrorDialog(
            'OTP Failed',
            _firebaseErrorMessage(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
          });

          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: RouteSettings(
                arguments: <String, dynamic>{
                  'accountType': _selectedAccountType,
                },
              ),
              builder: (_) => OtpVerificationScreen(
                verificationId: verificationId,
                phoneNumber: e164PhoneNumber,
                localMobileNumber: localMobile,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      await _showErrorDialog(
        'OTP Failed',
        _firebaseErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      await _showErrorDialog(
        'Error',
        'Failed to start phone verification.\n\n$e',
      );
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
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
    );
  }

  String _accountTypeHelperText() {
    if (_selectedAccountType == 'business') {
      return 'Business Partner login';
    }

    return 'Driver login';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Image.asset(
                            'assets/logo/goouts_logo_login.png',
                            height: 190,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: 20),
                          AutoSizeText(
                            _isReturningUser
                                ? 'Welcome Back!'
                                : 'Welcome to GoOuts',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10),
                          AutoSizeText(
                            _isReturningUser
                                ? 'Enter your password to sign back in'
                                : 'Enter your mobile number to continue',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 10),
                          AutoSizeText(
                            _accountTypeHelperText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _goOutsBlue,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 34),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(
                                      width: 120,
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        onTap: () async {
                                          final String? result =
                                              await showDialog<String>(
                                            context: context,
                                            builder:
                                                (BuildContext context) {
                                              return SimpleDialog(
                                                title: const Text(
                                                  'Select country',
                                                ),
                                                children: <Widget>[
                                                  SimpleDialogOption(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context,
                                                            'UK'),
                                                    child: const Text(
                                                      '🇬🇧  United Kingdom (+44)',
                                                    ),
                                                  ),
                                                  SimpleDialogOption(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context,
                                                            'IE'),
                                                    child: const Text(
                                                      '🇮🇪  Ireland (+353)',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (result == null) {
                                            return;
                                          }

                                          setState(() {
                                            if (result == 'UK') {
                                              _selectedFlag = '🇬🇧';
                                              _selectedDialCode = '+44';
                                            } else if (result == 'IE') {
                                              _selectedFlag = '🇮🇪';
                                              _selectedDialCode = '+353';
                                            }
                                          });
                                        },
                                        child: InputDecorator(
                                          decoration:
                                              _inputDecoration('Code'),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: <Widget>[
                                              AutoSizeText(
                                                '$_selectedFlag $_selectedDialCode',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                              const Icon(
                                                Icons
                                                    .arrow_drop_down_rounded,
                                                color: Colors.black54,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _mobileController,
                                        keyboardType: TextInputType.phone,
                                        textInputAction:
                                            TextInputAction.done,
                                        onFieldSubmitted: (_) =>
                                            _handleContinue(),
                                        inputFormatters:
                                            <TextInputFormatter>[
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(
                                            11,
                                          ),
                                        ],
                                        decoration: _inputDecoration(
                                          'Mobile Number',
                                        ).copyWith(
                                          hintText: '07123456780',
                                          counterText: '',
                                        ),
                                        validator: _mobileValidator,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isReturningUser) ...<Widget>[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    keyboardType: TextInputType.number,
                                    maxLength: 4,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                        letterSpacing: 10, fontSize: 18),
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) =>
                                        _handlePasswordLogin(),
                                    decoration:
                                        _inputDecoration('4-digit PIN').copyWith(
                                      counterText: '',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.black54,
                                        ),
                                        onPressed: () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                      ),
                                    ),
                                    validator: (String? value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'PIN is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _forgotPin,
                                      style: TextButton.styleFrom(
                                        foregroundColor: _goOutsBlue,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: AutoSizeText(
                                        'Forgot PIN?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : (_isReturningUser
                                            ? _handlePasswordLogin
                                            : _handleContinue),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _goOutsBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : AutoSizeText(
                                            'Continue',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 22),
                          if (!_isReturningUser)
                          AutoSizeText(
                            'You will receive a one-time verification code by SMS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 20),
           