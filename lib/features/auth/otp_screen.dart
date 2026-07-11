import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorText = 'Please enter the OTP code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.verifyOtp(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful.')),
      );

      context.go('/');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'Invalid OTP code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter OTP'),
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
                      'Verify phone number',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the code you received by SMS.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OTP code',
                        hintText: '123456',
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
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: Text(
                          _isLoading ? 'Verifying...' : 'Verify OTP',
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