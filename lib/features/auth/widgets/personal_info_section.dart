import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_section_card.dart';

class PersonalInfoSection extends StatelessWidget {
  final String? selectedPrefix;
  final List<String> prefixOptions;
  final ValueChanged<String?> onPrefixChanged;

  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final TextEditingController surnameController;
  final TextEditingController emailController;
  final TextEditingController confirmEmailController;

  final String ukLocalMobileNumber;

  final String? selectedMonth;
  final List<String> monthOptions;
  final ValueChanged<String?> onMonthChanged;

  final int? selectedYear;
  final List<int> yearOptions;
  final ValueChanged<int?> onYearChanged;

  final InputDecoration Function(String) inputDecorationBuilder;
  final List<TextInputFormatter> Function() upperCaseFormattersBuilder;

  final String? Function(String?) prefixValidator;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) confirmEmailValidator;
  final String? Function(String?) monthValidator;
  final String? Function(int?) yearValidator;

  const PersonalInfoSection({
    super.key,
    required this.selectedPrefix,
    required this.prefixOptions,
    required this.onPrefixChanged,
    required this.firstNameController,
    required this.middleNameController,
    required this.surnameController,
    required this.emailController,
    required this.confirmEmailController,
    required this.ukLocalMobileNumber,
    required this.selectedMonth,
    required this.monthOptions,
    required this.onMonthChanged,
    required this.selectedYear,
    required this.yearOptions,
    required this.onYearChanged,
    required this.inputDecorationBuilder,
    required this.upperCaseFormattersBuilder,
    required this.prefixValidator,
    required this.requiredValidator,
    required this.emailValidator,
    required this.confirmEmailValidator,
    required this.monthValidator,
    required this.yearValidator,
  });

  bool _hasText(TextEditingController controller) {
    return controller.text.trim().isNotEmpty;
  }

  bool _hasSelectedValue(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isNotEmpty && normalized != '-';
  }

  bool _hasValidEmail(TextEditingController controller) {
    final String text = controller.text.trim();
    if (text.isEmpty) {
      return false;
    }

    return emailValidator(text) == null;
  }

  bool _hasValidConfirmEmail() {
    final String text = confirmEmailController.text.trim();
    if (text.isEmpty) {
      return false;
    }

    return confirmEmailValidator(text) == null;
  }

  InputDecoration _buildSuccessDecoration({
    required String label,
    required bool isSuccessful,
  }) {
    return inputDecorationBuilder(label).copyWith(
      suffixIcon: isSuccessful
          ? const Icon(
              Icons.check_circle,
              color: Colors.green,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayLocalMobile = ukLocalMobileNumber.trim().isEmpty
        ? '07XXXXXXXXX'
        : ukLocalMobileNumber;
    final bool hasRealMobile = ukLocalMobileNumber.trim().isNotEmpty;

    return RegistrationSectionCard(
      title: 'Personal Details',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedPrefix,
            decoration: _buildSuccessDecoration(
              label: 'Prefix',
              isSuccessful: _hasSelectedValue(selectedPrefix),
            ),
            items: prefixOptions.map((prefix) {
              return DropdownMenuItem<String>(
                value: prefix,
                child: Text(prefix),
              );
            }).toList(),
            onChanged: onPrefixChanged,
            validator: prefixValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: firstNameController,
            inputFormatters: upperCaseFormattersBuilder(),
            textCapitalization: TextCapitalization.characters,
            decoration: _buildSuccessDecoration(
              label: 'First Name',
              isSuccessful: _hasText(firstNameController),
            ),
            validator: (value) => requiredValidator(value, 'First Name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: middleNameController,
            inputFormatters: upperCaseFormattersBuilder(),
            textCapitalization: TextCapitalization.characters,
            decoration: _buildSuccessDecoration(
              label: 'Middle Name',
              isSuccessful: _hasText(middleNameController),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: surnameController,
            inputFormatters: upperCaseFormattersBuilder(),
            textCapitalization: TextCapitalization.characters,
            decoration: _buildSuccessDecoration(
              label: 'Surname',
              isSuccessful: _hasText(surnameController),
            ),
            validator: (value) => requiredValidator(value, 'Surname'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            decoration: _buildSuccessDecoration(
              label: 'Email Address',
              isSuccessful: _hasValidEmail(emailController),
            ),
            validator: emailValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmEmailController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            decoration: _buildSuccessDecoration(
              label: 'Confirm Email Address',
              isSuccessful: _hasValidConfirmEmail(),
            ),
            validator: confirmEmailValidator,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: '🇬🇧 +44',
                  readOnly: true,
                  decoration: inputDecorationBuilder('Code').copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: displayLocalMobile,
                  readOnly: true,
                  decoration: _buildSuccessDecoration(
                    label: 'Mobile Number',
                    isSuccessful: hasRealMobile,
                  ).copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedMonth,
                  decoration: _buildSuccessDecoration(
                    label: 'Birth Month',
                    isSuccessful: _hasSelectedValue(selectedMonth),
                  ),
                  items: monthOptions.map((month) {
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(month),
                    );
                  }).toList(),
                  onChanged: onMonthChanged,
                  validator: monthValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: selectedYear,
                  decoration: _buildSuccessDecoration(
                    label: 'Birth Year',
                    isSuccessful: selectedYear != null,
                  ),
                  items: yearOptions.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: onYearChanged,
                  validator: yearValidator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}