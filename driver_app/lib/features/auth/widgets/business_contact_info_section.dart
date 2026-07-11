import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_section_card.dart';
import 'package:auto_size_text/auto_size_text.dart';

/// Business Partner registration — Address section.
///
/// Smart Hybrid flow (May 2026):
///   1. Owner types postcode → taps "Find Official Address"
///   2. Parent screen shows a bottom sheet of OS addresses
///   3. Owner picks one → parent shows verification overlay
///   4. Fields auto-fill, lock, and show the green UPRN-verified tick
///   5. "Enter manually" link is always available as a safety valve
class BusinessContactInfoSection extends StatelessWidget {
  final TextEditingController postcodeController;
  final TextEditingController shopNoController;
  final TextEditingController streetRoadNameController;

  final String? selectedCountry;
  final List<String> countryOptions;
  final ValueChanged<String?> onCountryChanged;

  final String? selectedCity;
  final List<String> cityOptions;
  final ValueChanged<String?> onCityChanged;

  final bool isPostcodeVerified;
  final bool isConfirmingPostcode;

  /// True only when the address fields were auto-filled from OS and
  /// should be read-only. Mapbox/manual flows leave this false.
  final bool lockAddressFields;

  /// Tapped when the owner hits "Find Official Address".
  final VoidCallback onConfirmPostcode;

  /// NEW (optional) — tapped when the owner hits "Enter manually".
  /// Should clear the verified state in the parent so fields unlock.
  final VoidCallback? onEditManually;

  final InputDecoration Function(String label) inputDecorationBuilder;
  final List<TextInputFormatter> Function() upperCaseFormattersBuilder;

  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) postcodeValidator;
  final String? Function(String?) countryValidator;
  final String? Function(String?) cityValidator;

  const BusinessContactInfoSection({
    super.key,
    required this.postcodeController,
    required this.shopNoController,
    required this.streetRoadNameController,
    required this.selectedCountry,
    required this.countryOptions,
    required this.onCountryChanged,
    required this.selectedCity,
    required this.cityOptions,
    required this.onCityChanged,
    required this.isPostcodeVerified,
    required this.isConfirmingPostcode,
    this.lockAddressFields = false,
    required this.onConfirmPostcode,
    required this.inputDecorationBuilder,
    required this.upperCaseFormattersBuilder,
    required this.requiredValidator,
    required this.postcodeValidator,
    required this.countryValidator,
    required this.cityValidator,
    this.onEditManually,
  });

  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _successGreen = Color(0xFF16A34A);

  bool _hasText(TextEditingController controller) {
    return controller.text.trim().isNotEmpty;
  }

  bool _hasSelectedValue(String? value) {
    return value != null && value.trim().isNotEmpty && value != '-';
  }

  InputDecoration _withTick({
    required String label,
    required bool showTick,
    String? helperText,
  }) {
    return inputDecorationBuilder(label).copyWith(
      helperText: helperText,
      suffixIcon: showTick
          ? const Icon(
              Icons.check_circle,
              color: _successGreen,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationSectionCard(
      title: 'Address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Loading strip while verifying with OS ─────────────────────
          if (isConfirmingPostcode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: _goOutsBlue,
                backgroundColor: Color(0xFFE5F4FB),
              ),
            ),

          // ── Postcode field ────────────────────────────────────────────
          TextFormField(
            controller: postcodeController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: <TextInputFormatter>[
              ...upperCaseFormattersBuilder(),
            ],
            decoration: _withTick(
              label: 'Postcode',
              showTick: isPostcodeVerified,
            ),
            validator: postcodeValidator,
          ),
          SizedBox(height: 12),

          // ── Find Official Address button ──────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isConfirmingPostcode ? null : onConfirmPostcode,
              icon: isConfirmingPostcode
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isPostcodeVerified
                          ? Icons.verified_rounded
                          : Icons.search_rounded,
                    ),
              label: AutoSizeText(
                isPostcodeVerified
                    ? 'Address Verified'
                    : 'Find Official Address',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPostcodeVerified ? _successGreen : _goOutsBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          // ── Verified subtitle / Manual entry link ─────────────────────
          SizedBox(height: 8),
          if (isPostcodeVerified)
            Row(
              children: <Widget>[
                Icon(
                  Icons.shield_rounded,
                  size: 16,
                  color: _successGreen,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Official UPRN Address Verified',
                    style: TextStyle(
                      color: _successGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onEditManually != null)
                  TextButton(
                    onPressed:
                        isConfirmingPostcode ? null : onEditManually,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _goOutsBlue,
                    ),
                    child: AutoSizeText(
                      'Edit manually',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            )
          else if (onEditManually != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isConfirmingPostcode ? null : onEditManually,
                icon: Icon(Icons.edit_rounded, size: 16),
                label: AutoSizeText(
                  "Can't find your address? Enter manually",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _goOutsBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Country dropdown (always editable) ────────────────────────
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedCountry,
            decoration: _withTick(
              label: 'Country',
              showTick: _hasSelectedValue(selectedCountry),
            ),
            items: countryOptions
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: onCountryChanged,
            validator: countryValidator,
          ),
          const SizedBox(height: 16),

          // ── City dropdown (locked when verified) ──────────────────────
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: cityOptions.contains(selectedCity) ? selectedCity : null,
            decoration: _withTick(
              label: 'City',
              showTick: _hasSelectedValue(selectedCity),
              helperText: cityOptions.isEmpty
                  ? 'Select country first'
                  : (lockAddressFields
                      ? 'Auto-filled from official record'
                      : null),
            ),
            items: cityOptions
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (cityOptions.isEmpty || lockAddressFields)
                ? null
                : onCityChanged,
            validator: cityValidator,
          ),
          const SizedBox(height: 16),

          // ── Shop No / Unit (locked when verified) ─────────────────────
          TextFormField(
            controller: shopNoController,
            textCapitalization: TextCapitalization.words,
            readOnly: lockAddressFields,
            decoration: _withTick(
              label: 'Shop No',
              showTick: _hasText(shopNoController),
              helperText: lockAddressFields
                  ? 'Auto-filled from official record'
                  : null,
            ),
            validator: (String? value) =>
                requiredValidator(value, 'Shop No'),
          ),
          const SizedBox(height: 16),

          // ── Street / Road Name (locked when verified) ─────────────────
          TextFormField(
            controller: streetRoadNameController,
            textCapitalization: TextCapitalization.words,
            readOnly: lockAddressFields,
            decoration: _withTick(
              label: 'Street / Road Name',
              showTick: _hasText(streetRoadNameController),
              helperText: lockAddressFields
                  ? 'Auto-filled from official record'
                  : null,
            ),
            validator: (String? value) =>
                requiredValidator(value, 'Street / Road Name'),
          ),
        ],
      ),
    );
  }
}
