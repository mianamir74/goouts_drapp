import 'driver_validators.dart';

class BusinessValidators {
  static String normalizeUkPostcode(String input) {
    return DriverValidators.normalizeUkPostcode(input);
  }

  static String? postcodeValidator(String? value) {
    return DriverValidators.postcodeValidator(value);
  }

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? nameValidator(String? value, String label) {
    final String? required = requiredField(value, label);
    if (required != null) {
      return required;
    }

    final String cleaned = value!.trim();
    if (!RegExp(r"^[A-Za-z .'-]{2,}$").hasMatch(cleaned)) {
      return 'Enter a valid $label';
    }
    return null;
  }

  static String? emailValidator(String? value) {
    final String? required = requiredField(value, 'Email Address');
    if (required != null) {
      return required;
    }

    final String cleaned = value!.trim();
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return pattern.hasMatch(cleaned) ? null : 'Enter a valid email address';
  }

  static String? confirmEmailValidator(String? value, String email) {
    final String? emailError = emailValidator(value);
    if (emailError != null) {
      return emailError;
    }

    if (value!.trim().toLowerCase() != email.trim().toLowerCase()) {
      return 'Email addresses do not match';
    }
    return null;
  }

  static String? pinValidator(String? value) {
    if (value == null || value.isEmpty) return 'PIN is required';
    if (value.length < 4) return 'PIN must be 4 digits';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return 'PIN must contain digits only';
    return null;
  }

  static String? confirmPinValidator(String? value, String pin) {
    if (value == null || value.isEmpty) return 'Please confirm your PIN';
    if (value != pin) return 'PINs do not match';
    return null;
  }

  static String? cityValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'City is required';
    }
    return null;
  }

  static String? countryValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Country is required';
    }
    return null;
  }

  static String? companyNumberValidator(String? value) {
    return requiredField(value, 'Business / Company Number');
  }
}
