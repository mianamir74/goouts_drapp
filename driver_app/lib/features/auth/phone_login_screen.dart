import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() {
        _errorText = 'Please enter your phone number.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    await _authService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        context.go('/otp', extra: verificationId);
      },
      onAutoVerified: () {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verified automatically.')),
        );

        context.go('/');
      },
      onError: (message) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorText = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login with phone number',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your phone number in full international format, for example +447444555666.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+447444555666',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorText != null) ...[
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        child: Text(
                          _isLoading ? 'Sending...' : 'Send OTP',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}