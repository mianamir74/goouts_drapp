import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_flow_guard.dart';
import 'auth_service.dart';

import '../home/business_home_screen.dart';
import 'business_referral_code_screen.dart';
import 'otp_verification_screen.dart';
import 'widgets/pre_auth_support_sheet.dart';
import 'package:auto_size_text/auto_size_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Adapted from driver_app/lib/features/auth/login_screen.dart's
//  Lead-Partner branch, 11 September 2026, as part of the goouts_drapp /
//  driver_app merge (design/PARTNER_ECOSYSTEM_ARCHITECTURE.md §4).
//
//  This screen is reached ONLY via the "Lead Partner" choice on
//  goouts_drapp's role picker, so — unlike driver_app's original, which was
//  a single shared screen for driver / Lead Partner / cab driver — the
//  driver and cab-driver branches have been removed. A driver-role signup
//  never routes through here; it stays entirely on goouts_drapp's existing
//  DappOnboardingScreen → DappLoginScreen → DappOtpScreen →
//  DappRegistrationScreen chain, unchanged.
// ─────────────────────────────────────────────────────────────────────────────
class LeadPartnerLoginScreen extends StatefulWidget {
  const LeadPartnerLoginScreen({super.key});

  @override
  State<LeadPartnerLoginScreen> createState() => _LeadPartnerLoginScreenState();
}

class _LeadPartnerLoginScreenState extends State<LeadPartnerLoginScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);

  static const String _pendingAccountTypeKey = 'pending_account_type';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hasReadRouteArgs = false;
  bool _isReturningUser = false;
  bool _obscurePassword = true;

  final _authService = AuthService();

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
        try {
          await _navigateToHomeForExistingUser(user);
        } catch (_) {
          // Silently ignore — login screen remains visible, user can retry
        }
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

    if (_selectedDialCode == '+44') {
      if (!RegExp(r'^07\d{9}$').hasMatch(cleaned)) {
        return 'Enter a valid UK mobile number (e.g. 07911123456)';
      }
    } else if (_selectedDialCode == '+353') {
      if (!RegExp(r'^08\d{8}$').hasMatch(cleaned)) {
        return 'Enter a valid Irish mobile number (e.g. 0851234567)';
      }
    } else {
      if (cleaned.length < 7) {
        return 'Enter a valid mobile number';
      }
    }

    return null;
  }

  String _toE164Number(String localNumber) {
    final String cleaned = localNumber.replaceAll(RegExp(r'[\s\-()]'), '');

    // Already in E.164 — return as-is
    if (cleaned.startsWith('+')) return cleaned;

    // UK: 07xxxxxxxxx (11 digits) → +447xxxxxxxxx
    if (_selectedDialCode == '+44') {
      if (cleaned.startsWith('07') && cleaned.length == 11) {
        return '+44${cleaned.substring(1)}';
      }
      // UK number without leading 0: 7xxxxxxxxx (10 digits)
      if (cleaned.startsWith('7') && cleaned.length == 10) {
        return '+44$cleaned';
      }
    }

    // Ireland: 08xxxxxxxxx (10 digits) → +3538xxxxxxxxx (drop leading 0)
    if (_selectedDialCode == '+353') {
      if (cleaned.startsWith('0') && cleaned.length >= 9) {
        return '+353${cleaned.substring(1)}';
      }
      return '+353$cleaned';
    }

    // Other dial codes — strip non-digits then prepend dial code
    if (_selectedDialCode.isNotEmpty) {
      final String digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
      return '$_selectedDialCode$digitsOnly';
    }

    return cleaned;
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
    final DocumentSnapshot<Map<String, dynamic>> leadPartnerDoc;
    try {
      leadPartnerDoc =
          await firestore.collection('lead_partners').doc(user.uid).get();
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Connection Error',
          'Could not reach the server. Please check your connection and try again.\n\n$e');
      return;
    }
    if (!mounted) return;

    if (leadPartnerDoc.exists) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
        (route) => false,
      );
    } else {
      // New user — no Lead Partner profile exists yet. Send to registration.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BusinessReferralCodeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (_isLoading) return;

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    final String localMobile = _mobileController.text.trim();
    final String e164 = _toE164Number(localMobile);
    final String emailForAuth =
        '${e164.replaceAll('+', '').replaceAll(' ', '')}@goouts.app';

    setState(() => _isLoading = true);

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailForAuth,
        password: _passwordController.text,
      );

      // Mirror the OTP flow — save account type so app-level routing (if it
      // ever needs it) sees the same value the OTP path writes.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingAccountTypeKey, 'business');

      if (!mounted) return;

      final User? user = credential.user;
      if (user != null) {
        await _navigateToHomeForExistingUser(user);
      } else {
        // Credential returned no user — unexpected. Show error instead of
        // crashing to splash.
        if (!mounted) return;
        await _showErrorDialog('Login Failed', 'Could not retrieve your account. Please try OTP login.');
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

  Future<void> _completeVerificationFlow() async {
    // Everything below can exit early (unmounted widget, no signed-in user),
    // throw (prefs / Firestore failure), or complete normally. Whichever
    // happens, AuthFlowGuard.end() below in `finally` guarantees the guard
    // started in _handleContinue() is always released — otherwise the root
    // app gate is stuck on its spinner for the rest of this app process.
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingAccountTypeKey, 'business');

      if (!mounted) return;

      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentSnapshot<Map<String, dynamic>> leadPartnerDoc =
          await firestore.collection('lead_partners').doc(user.uid).get();

      if (!mounted) return;

      // Release the guard just before navigation so the app gate doesn't
      // interfere while we pushAndRemoveUntil.
      AuthFlowGuard.end();

      if (leadPartnerDoc.exists) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessReferralCodeScreen()),
          (route) => false,
        );
      }
    } finally {
      // Safety net for every early-return / exception path above. On the
      // normal success path AuthFlowGuard.end() was already called just
      // before navigation; calling it again here is a harmless no-op
      // (AuthFlowGuard.end() is idempotent).
      AuthFlowGuard.end();
    }
  }

  Future<void> _handleContinue() async {
    if (_isLoading) return;

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    final String localMobile = _mobileController.text.trim();
    final String e164PhoneNumber = _toE164Number(localMobile);

    // Cancel auth subscription and activate flow guard BEFORE any Firebase
    // activity. The guard prevents the app gate's StreamBuilder from
    // swapping widgets mid-flow (the same OTP/splash race driver_app fixed).
    _authSubscription?.cancel();
    _authSubscription = null;
    AuthFlowGuard.start();

    setState(() => _isLoading = true);

    await _authService.sendOtp(
      phoneNumber: e164PhoneNumber,
      onCodeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LeadPartnerOtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber: e164PhoneNumber,
              localMobileNumber: localMobile,
              resendToken: resendToken,
            ),
          ),
        );
      },
      onAutoVerified: () async {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await _completeVerificationFlow();
      },
      onError: (String message) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (context.mounted) _showErrorDialog('OTP Failed', message);
      },
    );
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
                            'assets/logo/role_icon.png',
                            height: 190,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.storefront_rounded,
                              size: 90,
                              color: _goOutsBlue,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 10),
                          const AutoSizeText(
                            'Lead Partner login',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                                            _selectedDialCode == '+353' ? 10 : 11,
                                          ),
                                        ],
                                        decoration: _inputDecoration(
                                          'Mobile Number',
                                        ).copyWith(
                                          hintText: _selectedDialCode == '+353' ? '0851234567' : '07123456780',
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
                                      child: const AutoSizeText(
                                        'Forgot PIN?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
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
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const AutoSizeText(
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
                          const SizedBox(height: 22),
                          if (!_isReturningUser)
                          const AutoSizeText(
                            'You will receive a one-time verification code by SMS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: GestureDetector(
                              onTap: () => showPreAuthSupportSheet(
                                context,
                                accountType: 'business',
                              ),
                              child: const Text(
                                'Having trouble? Get help',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black38,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.black26,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
