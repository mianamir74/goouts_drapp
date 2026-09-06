import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_section_card.dart';

class VehicleInfoSection extends StatelessWidget {
  final String? selectedVehicleType;
  final List<String> vehicleTypeOptions;
  final ValueChanged<String?> onVehicleTypeChanged;

  final bool needsLicence;
  final bool isNorthernIreland;
  final TextEditingController drivingLicenceNumberController;

  final InputDecoration Function(String) inputDecorationBuilder;
  final List<TextInputFormatter> Function() ukDrivingLicenceFormattersBuilder;
  final List<TextInputFormatter> Function() niDrivingLicenceFormattersBuilder;

  final String? Function(String?) vehicleTypeValidator;
  final String? Function(String?) drivingLicenceNumberValidator;

  const VehicleInfoSection({
    super.key,
    required this.selectedVehicleType,
    required this.vehicleTypeOptions,
    required this.onVehicleTypeChanged,
    required this.needsLicence,
    required this.isNorthernIreland,
    required this.drivingLicenceNumberController,
    required this.inputDecorationBuilder,
    required this.ukDrivingLicenceFormattersBuilder,
    required this.niDrivingLicenceFormattersBuilder,
    required this.vehicleTypeValidator,
    required this.drivingLicenceNumberValidator,
  });

  bool _hasSelectedValue(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isNotEmpty && normalized != '-';
  }

  bool _hasValidLicenceValue() {
    final String text = drivingLicenceNumberController.text.trim();
    if (text.isEmpty) {
      return false;
    }

    return drivingLicenceNumberValidator(text) == null;
  }

  InputDecoration _buildSuccessDecoration({
    required String label,
    required bool isSuccessful,
    String? helperText,
    String? counterText,
  }) {
    return inputDecorationBuilder(label).copyWith(
      helperText: helperText,
      counterText: counterText,
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
    return RegistrationSectionCard(
      title: 'Vehicle & Licence',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedVehicleType,
            decoration: _buildSuccessDecoration(
              label: 'Vehicle Type',
              isSuccessful: _hasSelectedValue(selectedVehicleType),
            ),
            items: vehicleTypeOptions.map((vehicleType) {
              return DropdownMenuItem<String>(
                value: vehicleType,
                child: Text(vehicleType),
              );
            }).toList(),
            onChanged: onVehicleTypeChanged,
            validator: vehicleTypeValidator,
          ),
          if (needsLicence) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: drivingLicenceNumberController,
              inputFormatters: isNorthernIreland
                  ? niDrivingLicenceFormattersBuilder()
                  : ukDrivingLicenceFormattersBuilder(),
              textCapitalization: TextCapitalization.characters,
              maxLength: isNorthernIreland ? 8 : 16,
              keyboardType:
                  isNorthernIreland ? TextInputType.number : TextInputType.text,
              decoration: _buildSuccessDecoration(
                label: 'Driving Licence Number',
                isSuccessful: _hasValidLicenceValue(),
                helperText: isNorthernIreland
                    ? 'Format: exactly 8 digits (example: 12345678)'
                    : 'Format: 5 letters + 11 digits (example: GOOUT12456789011)',
                counterText: '',
              ),
              validator: drivingLicenceNumberValidator,
            ),
          ],
        ],
      ),
    );
  }
}