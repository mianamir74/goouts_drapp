import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_section_card.dart';

class AccountInfoSection extends StatelessWidget {
  final TextEditingController pinController;
  final TextEditingController confirmPinController;

  final bool obscurePin;
  final bool obscureConfirmPin;

  final VoidCallback onTogglePin;
  final VoidCallback onToggleConfirmPin;

  final InputDecoration Function(String) inputDecorationBuilder;

  final String? Function(String?) pinValidator;
  final String? Function(String?) confirmPinValidator;

  const AccountInfoSection({
    super.key,
    required this.pinController,
    required this.confirmPinController,
    required this.obscurePin,
    required this.obscureConfirmPin,
    required this.onTogglePin,
    required this.onToggleConfirmPin,
    required this.inputDecorationBuilder,
    required this.pinValidator,
    required this.confirmPinValidator,
  });

  bool get _isPinValid =>
      pinController.text.length == 4 &&
      RegExp(r'^\d{4}$').hasMatch(pinController.text);

  bool get _isConfirmPinValid =>
      _isPinValid && confirmPinController.text == pinController.text;

  @override
  Widget build(BuildContext context) {
    return RegistrationSectionCard(
      title: 'Security PIN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: pinController,
            obscureText: obscurePin,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(letterSpacing: 10, fontSize: 18),
            decoration: inputDecorationBuilder('4-digit PIN').copyWith(
              counterText: '',
              helperText: 'You will use this PIN to log in',
              suffixIconConstraints:
                  const BoxConstraints(minHeight: 0, minWidth: 0),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPinValid)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                  IconButton(
                    icon: Icon(
                        obscurePin ? Icons.visibility_off : Icons.visibility),
                    onPressed: onTogglePin,
                  ),
                ],
              ),
            ),
            validator: pinValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmPinController,
            obscureText: obscureConfirmPin,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(letterSpacing: 10, fontSize: 18),
            decoration: inputDecorationBuilder('Confirm PIN').copyWith(
              counterText: '',
              suffixIconConstraints:
                  const BoxConstraints(minHeight: 0, minWidth: 0),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isConfirmPinValid)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                  IconButton(
                    icon: Icon(obscureConfirmPin
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: onToggleConfirmPin,
                  ),
                ],
              ),
            ),
            validator: confirmPinValidator,
          ),
        ],
      ),
    );
  }
}
