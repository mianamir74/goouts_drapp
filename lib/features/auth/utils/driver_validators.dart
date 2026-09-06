class DriverValidators {
  static bool vehicleNeedsLicence(String? vehicleType) {
    return vehicleType != null &&
        vehicleType != 'BICYCLE' &&
        vehicleType != 'E-BIKE';
  }

  static bool isNorthernIreland(String? country) {
    return country == 'NORTHERN IRELAND';
  }

  static int calculateAge({
    required String selectedMonth,
    required int selectedYear,
    required List<String> monthOptions,
  }) {
    final DateTime currentDate = DateTime.now();
    final int birthMonthNumber = monthOptions.indexOf(selectedMonth) + 1;

    int age = currentDate.year - selectedYear;

    if (birthMonthNumber > 0 && currentDate.month < birthMonthNumber) {
      age--;
    }

    return age;
  }

  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? prefixValidator(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return 'Prefix is required';
    }
    return null;
  }

  static String? countryValidator(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return 'Country is required';
    }
    return null;
  }

  static String? cityValidator(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return 'Intended Work City is required';
    }
    return null;
  }

  static String? workAreaValidator(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return 'Intended Work Area is required';
    }
    return null;
  }

  static String normalizeUkPostcode(String value) {
    final String cleaned = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');

    if (cleaned.length <= 3) {
      return cleaned;
    }

    final String outward = cleaned.substring(0, cleaned.length - 3);
    final String inward = cleaned.substring(cleaned.length - 3);
    return '$outward $inward';
  }

  static String? postcodeValidator(String? value) {
    final String postcode = normalizeUkPostcode(value ?? '');

    if (postcode.isEmpty) {
      return 'Postcode is required';
    }

    final RegExp postcodeRegex = RegExp(
      r'^(GIR 0AA|[A-Z]{1,2}[0-9][A-Z0-9]?\s[0-9][A-Z]{2})$',
    );

    if (!postcodeRegex.hasMatch(postcode)) {
      return 'Enter a valid postcode';
    }

    return null;
  }

  static String? emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email Address is required';
    }

    final String email = value.trim();
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? confirmEmailValidator(
    String? value,
    String originalEmail,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm Email Address is required';
    }

    if (value.trim().toLowerCase() != originalEmail.trim().toLowerCase()) {
      return 'Email addresses do not match';
    }

    return null;
  }

  static String? pinValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length < 4) {
      return 'PIN must be 4 digits';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
      return 'PIN must contain digits only';
    }
    return null;
  }

  static String? confirmPinValidator(String? value, String originalPin) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your PIN';
    }
    if (value != originalPin) {
      return 'PINs do not match';
    }
    return null;
  }

  static String? monthDropdownValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Month is required';
    }
    return null;
  }

  static String? yearDropdownValidator(int? value) {
    if (value == null) {
      return 'Year is required';
    }
    return null;
  }

  static String? vehicleTypeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vehicle Type is required';
    }
    return null;
  }

  static String? drivingLicenceNumberValidator({
    required String? value,
    required bool needsLicence,
    required bool isNorthernIreland,
  }) {
    if (!needsLicence) {
      return null;
    }

    if (value == null || value.trim().isEmpty) {
      return 'Driving Licence Number is required';
    }

    final String licence = value.trim().toUpperCase();

    if (isNorthernIreland) {
      if (!RegExp(r'^[0-9]{8}$').hasMatch(licence)) {
        return 'Enter exactly 8 digits';
      }
      return null;
    }

    if (!RegExp(r'^[A-Z]{5}[0-9]{11}$').hasMatch(licence)) {
      return 'Enter 5 letters followed by 11 digits';
    }

    return null;
  }
}