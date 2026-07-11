import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_section_card.dart';
import 'package:auto_size_text/auto_size_text.dart';

/// Driver registration — Address section.
///
/// Address field order:
///   1. Postcode  (user types → Look Up Postcode → Mapbox validates)
///   2. House / Business No or Name  (manual)
///   3. Street / Road Name           (manual)
///   4. Town                         (auto-filled from Mapbox local area)
///   5. City                         (auto-filled from postcode area mapping)
///   6. Country                      (auto-filled from postcode prefix)
class ContactInfoSection extends StatelessWidget {
  final TextEditingController postcodeController;
  final TextEditingController houseNoController;
  final TextEditingController streetNameController;
  final TextEditingController townController;

  final String? selectedCountry;
  final List<String> countryOptions;
  final ValueChanged<String?> onCountryChanged;

  final String? selectedCity;
  final List<String> cityOptions;
  final ValueChanged<String?> onCityChanged;

  final bool isPostcodeVerified;
  final bool isConfirmingPostcode;

  /// Always false in Mapbox-only mode — fields remain editable after lookup.
  final bool lockAddressFields;

  /// Tapped when the driver hits "Look Up Postcode".
  final VoidCallback onConfirmPostcode;

  /// Tapped when the driver hits "Enter manually".
  final VoidCallback? onEditManually;

  final InputDecoration Function(String) inputDecorationBuilder;
  final List<TextInputFormatter> Function() upperCaseFormattersBuilder;

  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) postcodeValidator;
  final String? Function(String?) countryValidator;
  final String? Function(String?) cityValidator;

  const ContactInfoSection({
    super.key,
    required this.postcodeController,
    required this.houseNoController,
    required this.streetNameController,
    required this.townController,
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

  bool _hasText(TextEditingController controller) =>
      controller.text.trim().isNotEmpty;

  bool _hasSelectedValue(String? value) =>
      value != null && value.trim().isNotEmpty && value != '-';

  InputDecoration _withTick({
    required String label,
    required bool showTick,
    String? helperText,
  }) {
    return inputDecorationBuilder(label).copyWith(
      helperText: helperText,
      suffixIcon: showTick
          ? const Icon(Icons.check_circle, color: _successGreen)
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

          // ── Loading strip ─────────────────────────────────────────────
          if (isConfirmingPostcode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: _goOutsBlue,
                backgroundColor: Color(0xFFE5F4FB),
              ),
            ),

          // ── 1. Postcode + Look Up button ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: postcodeController,
                  inputFormatters: upperCaseFormattersBuilder(),
                  textCapitalization: TextCapitalization.characters,
                  decoration: _withTick(
                    label: 'Postcode',
                    showTick: isPostcodeVerified,
                  ),
                  validator: postcodeValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed:
                        isConfirmingPostcode ? null : onConfirmPostcode,
                    icon: isConfirmingPostcode
                        ? const SizedBox(
                            width: 18,
                            height: 18,
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
                      isPostcodeVerified ? 'Verified' : 'Look Up Postcode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
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
              ),
            ],
          ),

          // ── Status banners ────────────────────────────────────────────
          const SizedBox(height: 8),
          if (isPostcodeVerified)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _successGreen.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _successGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: _successGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Postcode confirmed — fill in your house number and street below.',
                      style: TextStyle(
                        color: _successGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
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
                      child: const AutoSizeText(
                        'Edit',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                ],
              ),
            )
          else if (onEditManually != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isConfirmingPostcode ? null : onEditManually,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const AutoSizeText(
                  "Can't find your address? Enter manually",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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

          // ── 2. House / Business No or Name ────────────────────────────
          TextFormField(
            controller: houseNoController,
            inputFormatters: upperCaseFormattersBuilder(),
            textCapitalization: TextCapitalization.characters,
            readOnly: lockAddressFields,
            decoration: _withTick(
              label: 'House / Business No or Name',
              showTick: _hasText(houseNoController),
            ),
            validator: (String? v) =>
                requiredValidator(v, 'House / Business No or Name'),
          ),
          const SizedBox(height: 16),

          // ── 3. Street / Road Name ─────────────────────────────────────
          TextFormField(
            controller: streetNameController,
            inputFormatters: upperCaseFormattersBuilder(),
            textCapitalization: TextCapitalization.characters,
            readOnly: lockAddressFields,
            decoration: _withTick(
              label: 'Street / Road Name',
              showTick: _hasText(streetNameController),
            ),
            validator: (String? v) =>
                requiredValidator(v, 'Street / Road Name'),
          ),
          const SizedBox(height: 16),

          // ── 4. Town (auto-filled from Mapbox local area) ──────────────
          TextFormField(
            controller: townController,
            inputFormatters: upperCaseFormattersBuilder(),
            textCapitalization: TextCapitalization.characters,
            decoration: _withTick(
              label: 'Town',
              showTick: _hasText(townController),
              helperText: isPostcodeVerified && _hasText(townController)
                  ? 'Auto-filled from postcode'
                  : null,
            ),
            validator: (String? v) => requiredValidator(v, 'Town'),
          ),
          const SizedBox(height: 16),

          // ── 5. City (auto-filled from postcode area mapping) ──────────
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: cityOptions.contains(selectedCity) ? selectedCity : null,
            decoration: _withTick(
              label: 'City',
              showTick: _hasSelectedValue(selectedCity),
              helperText:
                  cityOptions.isEmpty ? 'Select country first' : null,
            ),
            items: cityOptions.map((String city) {
              return DropdownMenuItem<String>(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (cityOptions.isEmpty || lockAddressFields)
                ? null
                : onCityChanged,
            validator: cityValidator,
          ),
          const SizedBox(height: 16),

          // ── 6. Country (auto-filled from postcode prefix) ─────────────
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedCountry,
            decoration: _withTick(
              label: 'Country',
              showTick: _hasSelectedValue(selectedCountry),
            ),
            items: countryOptions.map((String country) {
              return DropdownMenuItem<String>(
                value: country,
                child: Text(country),
              );
            }).toList(),
            onChanged: onCountryChanged,
            validator: countryValidator,
          ),
        ],
      ),
    );
  }
}
