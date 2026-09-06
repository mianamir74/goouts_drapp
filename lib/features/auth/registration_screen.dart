import 'dart:io';
import '../../services/address_lookup_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/business_home_screen.dart';
import '../home/driver_home_screen.dart';
import 'widgets/pre_auth_support_sheet.dart';

import 'models/driver_model.dart';
import 'services/driver_registration_service.dart';
import 'utils/app_lists.dart';
import 'utils/driver_validators.dart';
import 'widgets/account_info_section.dart';
import 'widgets/contact_info_section.dart';
import 'widgets/personal_info_section.dart';
import 'widgets/registration_section_card.dart';
import 'widgets/vehicle_info_section.dart';
import '../legal/terms_and_conditions_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';
import '../../screens/liveness_selfie_screen.dart';
import '../../services/image_orientation.dart';

// NOTE:
// This file is the user-requested updated copy of file:965 with these 4 changes:
// 1) GB -> GB in business prefix checks.
// 2) Driver defaults aligned to GD100001 and driver validation uses GD.
// 3) Business registration navigates to BusinessHomeScreen.
// 4) sentinvites -> sentinvites.

class RegistrationScreen extends StatefulWidget {
  final String referralCode;

  const RegistrationScreen({
    super.key,
    required this.referralCode,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const String _termsUrl = 'https://example.com/goouts-terms';
  static const String _defaultDriverReferralCode = 'GD100001';
  static const String _defaultBusinessReferralCode = 'GB000001';
  static const String _defaultCabDriverReferralCode = 'GC100001';
  static const int _verificationSupportThreshold = 3;
  static const String _defaultDriverCountry = 'UNITED KINGDOM';
  static const String _northernIrelandCountry = 'NORTHERN IRELAND';
  // _mapboxPublicToken removed 13 August 2026. This screen declared its own
  // copy of the Mapbox token and never used it — every lookup goes through
  // AddressLookupService. A dead field holding a credential is the worst of
  // both: no benefit, and one more place a token gets pasted back in.

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AddressLookupService _addressService = AddressLookupService();
  final DriverRegistrationService _driverRegistrationService =
      DriverRegistrationService();
  final ImagePicker _imagePicker = ImagePicker();

  late final List<int> _yearOptions;

  String? _selectedPrefix;
  String? _selectedMonth;
  int? _selectedYear;
  String? _selectedVehicleType;
  String? _selectedCountry;
  String? _selectedCity;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _drivingLicenceNumberController = TextEditingController();
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _streetNameController = TextEditingController();
  final TextEditingController _townController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _legalBusinessNameController = TextEditingController();
  final TextEditingController _companyNumberController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _hasRightToWork = false;
  bool _showRightToWorkError = false;
  bool _isPickingSelfie = false;
  bool _showSelfieError = false;
  bool _isPickingDrivingLicenceFront = false;
  bool _showDrivingLicenceFrontError = false;
  bool _isPickingDrivingLicenceBack = false;
  bool _showDrivingLicenceBackError = false;
  bool _isPickingPassport = false;
  bool _showPassportError = false;
  bool _isPostcodeVerified = false;
  bool _isConfirmingPostcode = false;
  bool _isUpdatingPostcodeProgrammatically = false;
  bool _hasReadRouteArgs = false;

  // ── Smart Hybrid verified data (May 2026) ──
  String _verifiedUprn = '';
  String _verifiedFullAddress = '';
  double? _verifiedLatitude;
  double? _verifiedLongitude;
  // Locked only when address was actually auto-filled from OS bottom sheet.
  // Mapbox fallback / manual entry leave fields editable.
  bool _addressFieldsLocked = false;
  List<MapboxSuggestResult> _addressSuggestions = [];
  String _mapboxSessionToken = AddressLookupService.generateSessionToken();
  bool _isLookingUpAddress = false;

  String _accountType = 'driver';
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  XFile? _selfieImage;

  /// What the phone thought of the selfie, and whether the head-sweep finished.
  ///
  /// ⚠ ADVISORY ONLY. Client-written and trivially forgeable, so nothing
  /// automated may key off them. New on 24 August 2026 — this app previously
  /// ran no selfie check of any kind.
  bool _livenessComplete = false;
  String _livenessNote = '';
  String? _selfieAdvice;
  Map<String, dynamic>? _selfieScores;
  XFile? _drivingLicenceFrontImage;
  XFile? _drivingLicenceBackImage;
  XFile? _passportImage;

  bool get _isBusinessAccount => _accountType == 'business';
  bool get _isCabDriverAccount => _accountType == 'cab_driver';

  /// Firestore collection for the current driver-type account.
  String get _firestoreDriverCollection =>
      _isCabDriverAccount ? 'cab_drivers' : 'drivers';

  @override
  void initState() {
    super.initState();
    _yearOptions = AppLists.buildYearOptions();
    _selectedPrefix = AppLists.prefixOptions.first;
    _selectedCountry = AppLists.countryOptions.first;
    _postcodeController.addListener(_handlePostcodeEdited);
  }

  Future<void> _restorePendingAccountType() async {
    if (_accountType == 'business' || _accountType == 'cab_driver') return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String pending =
        prefs.getString('pending_account_type')?.trim().toLowerCase() ?? 'driver';
    if (!mounted) return;
    if (pending == 'business' || pending == 'cab_driver') {
      setState(() {
        _accountType = pending;
        if (pending == 'cab_driver') {
          _selectedVehicleType = 'Car';
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasReadRouteArgs) return;
    _hasReadRouteArgs = true;

    final Map<String, dynamic> args = _routeArguments();
    final String routeAccountType =
        _readMapString(args, 'accountType').trim().toLowerCase();
    final String incomingReferralCode = _readMapString(args, 'referralCode').isNotEmpty
        ? _readMapString(args, 'referralCode')
        : widget.referralCode;
    final String normalizedReferralCode = incomingReferralCode.trim().toUpperCase();

    if (routeAccountType == 'business' || normalizedReferralCode.startsWith('GB')) {
      _accountType = 'business';
    } else if (routeAccountType == 'cab_driver' || normalizedReferralCode.startsWith('GC')) {
      _accountType = 'cab_driver';
      _selectedVehicleType = 'Car'; // auto-select for cab drivers
    } else {
      _accountType = 'driver';
    }

    _restorePendingAccountType();
  }

  @override
  void dispose() {
    _postcodeController.removeListener(_handlePostcodeEdited);
    _firstNameController.dispose();
    _middleNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _drivingLicenceNumberController.dispose();
    _houseNoController.dispose();
    _streetNameController.dispose();
    _townController.dispose();
    _postcodeController.dispose();
    _legalBusinessNameController.dispose();
    _companyNumberController.dispose();
    super.dispose();
  }

  void _handlePostcodeEdited() {
    if (_isUpdatingPostcodeProgrammatically) return;
    final String rawPostcode = _postcodeController.text.trim();
    final String inferredCountry = rawPostcode.isEmpty
        ? AppLists.countryOptions.first
        : _inferCountryFromPostcode(rawPostcode);
    setState(() {
      _isPostcodeVerified = false;
      _verifiedUprn = '';
      _verifiedFullAddress = '';
      _verifiedLatitude = null;
      _verifiedLongitude = null;
      _addressFieldsLocked = false;
      if (_selectedCountry != inferredCountry) {
        _selectedCountry = inferredCountry;
        _selectedCity = null;
      }
    });
    _townController.clear();
  }

  bool _isMotorbikeVehicleType(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    return normalized == 'MOTORBIKE';
  }

  bool _vehicleNeedsLicence() =>
      _isCabDriverAccount || _isMotorbikeVehicleType(_selectedVehicleType);
  bool _needsIdentityDocument() =>
      _isCabDriverAccount || (_selectedVehicleType ?? '').trim().isNotEmpty;
  bool _requiresDrivingLicenceFrontAndBack() => _vehicleNeedsLicence();
  bool _requiresPassportCopy() => _needsIdentityDocument() && !_vehicleNeedsLicence();
  bool _isNorthernIreland() =>
      (_selectedCountry ?? '').trim().toUpperCase() == _northernIrelandCountry;
  List<String> _cityOptionsForSelectedCountry() =>
      AppLists.cityOptionsForCountry(_selectedCountry);
  String _requiredIdentityDocumentTitle() => 'Document Upload';

  String _requiredIdentityDocumentDescription() {
    if (_requiresDrivingLicenceFrontAndBack()) {
      return _isCabDriverAccount
          ? 'Rider Drivers must upload a clear photo of the front and back of their driving licence.'
          : 'Motorbike drivers must upload a clear photo of the front and back of their driving licence.';
    }
    if (_requiresPassportCopy()) {
      return 'Please upload a clear passport copy.';
    }
    return '';
  }

  String _normalizeUkPostcode(String input) => DriverValidators.normalizeUkPostcode(input);
  String? _postcodeValidatorLocal(String? value) => DriverValidators.postcodeValidator(value);
  String _normalizedPostcode() => _normalizeUkPostcode(_postcodeController.text);

  String _extractUkLocalMobile(String phoneNumber) {
    final String cleaned = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+44') && cleaned.length >= 13) {
      return '0${cleaned.substring(3)}';
    }
    if (cleaned.startsWith('44') && cleaned.length >= 12) {
      return '0${cleaned.substring(2)}';
    }
    if (cleaned.startsWith('07')) {
      return cleaned;
    }
    return '';
  }

  String _normalizePhoneForInviteMatching(String phoneNumber) {
    final String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned.substring(1);
    if (cleaned.startsWith('00')) return cleaned.substring(2);
    if (cleaned.startsWith('0')) return '44${cleaned.substring(1)}';
    return cleaned;
  }

  String _generateOwnReferralCode(String uid) {
    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return _defaultDriverReferralCode;
    if (cleaned.length >= 6) return 'GD${cleaned.substring(cleaned.length - 6)}';
    return 'GD${cleaned.padLeft(6, '0')}';
  }

  String _generateBusinessReferralCode(String uid) {
    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return _defaultBusinessReferralCode;
    if (cleaned.length >= 6) return 'GB${cleaned.substring(cleaned.length - 6)}';
    return 'GB${cleaned.padLeft(6, '0')}';
  }

  String _generateCabDriverReferralCode(String uid) {
    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return _defaultCabDriverReferralCode;
    if (cleaned.length >= 6) return 'GC${cleaned.substring(cleaned.length - 6)}';
    return 'GC${cleaned.padLeft(6, '0')}';
  }

  String _normalizeReferralCode(String referralCode) {
    final String cleaned = referralCode.trim().toUpperCase();
    if (cleaned.isEmpty) {
      if (_isBusinessAccount) return ReferralDefaults.businessCode;
      if (_isCabDriverAccount) return ReferralDefaults.cabDriverCode;
      return ReferralDefaults.driverCode;
    }
    return cleaned;
  }

  String _normalizeInviteToken(String inviteToken) => inviteToken.trim().toUpperCase();

  String _titleCase(String value) {
    if (value.trim().isEmpty) return '';
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .map((String word) {
          if (word.isEmpty) return word;
          final String lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  String _buildJoinedDriverName({
    required String firstName,
    required String middleName,
    required String surname,
  }) {
    final String combined = '$firstName $middleName $surname'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (combined.isEmpty) return 'Unnamed Driver';
    return _titleCase(combined);
  }

  Map<String, dynamic> _routeArguments() {
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) return args;
    if (args is Map) return Map<String, dynamic>.from(args);
    return <String, dynamic>{};
  }

  String _readMapString(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  DateTime? _readMapDateTime(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value.trim());
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _readContextName(Map<String, dynamic> context, String key) {
    final dynamic value = context[key];
    if (value is Map) {
      final Map<String, dynamic> valueMap = Map<String, dynamic>.from(value);
      final String name = _readMapString(valueMap, 'name');
      if (name.isNotEmpty) return name;
    }
    if (value is String) return value.trim();
    return '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final String value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _normalizeForMatching(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String? _matchCityOption(String? rawCity, List<String> options) {
    final String input = _normalizeForMatching(rawCity ?? '');
    if (input.isEmpty) return null;
    for (final String option in options) {
      final String normalizedOption = _normalizeForMatching(option);
      if (normalizedOption == input ||
          normalizedOption.contains(input) ||
          input.contains(normalizedOption)) {
        return option;
      }
    }
    return null;
  }

  String _inferCountryFromPostcode(String postcode) {
    final String normalized = _normalizeUkPostcode(postcode).replaceAll(' ', '');
    if (normalized.startsWith('BT')) return _northernIrelandCountry;
    return _defaultDriverCountry;
  }

  String _extractCityFromPostcodeFeature(Map<String, dynamic> feature, List<String> cityOptions) {
    final Map<String, dynamic> properties = _asMap(feature['properties']);
    final Map<String, dynamic> context = _asMap(properties['context']);
    final String candidate = _firstNonEmpty([
      _readContextName(context, 'place'),
      _readContextName(context, 'locality'),
      _readContextName(context, 'district'),
      _readMapString(properties, 'name'),
    ]);
    final String? matched = _matchCityOption(candidate, cityOptions);
    return matched ?? '';
  }

  void _showSnackBarMessage(String message) {
    if (!mounted) return;
    GoOutsSheet.warning(context, title: 'Attention', message: message);
  }

  Future<void> _showTermsRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Required Confirmation'),
          content: Text(
            _isBusinessAccount
                ? 'Please accept Terms & Conditions before continuing.'
                : 'Please accept Terms & Conditions and confirm your right to work before continuing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTermsAndConditions() async {
    showTermsSheet(context);
  }

  Future<void> _pickSelfie() async {
    try {
      setState(() {
        _isPickingSelfie = true;
      });
      // ── ⚠ THE LIVE CAMERA REPLACED image_picker HERE, 24 August 2026 ───────
      //
      // What was here had both faults at once:
      //
      // 1. imageQuality: 85 AND maxWidth: 1200 — the combination documented
      //    across this codebase as destroying identity photographs. Either one
      //    makes image_picker re-encode, which DROPS the EXIF orientation tag
      //    WITHOUT rotating the pixels, leaving a sideways image with nothing
      //    left to say it is sideways.
      //
      // 2. NO CHECK AT ALL. Whatever the camera returned went straight into
      //    _selfieImage and on to Storage.
      //
      // ⚠ LivenessSelfieScreen RETURNS THE FINISHED ARTICLE — upright,
      // downscaled and inspected — and will not hand back a photograph with no
      // usable face in it. Do not add a resize or a re-check here.
      final LivenessSelfieResult? shot =
          await LivenessSelfieScreen.open(context);
      if (!mounted) return;

      // null means they backed out without taking one. Nothing happened.
      if (shot != null) {
        setState(() {
          _selfieImage = XFile(shot.path);
          _showSelfieError = false;
          // ⚠ ADVISORY, NEVER A DECISION — client-written and trivially
          // forged. false means the head-sweep ran out of time and the photo
          // was taken anyway: look harder, not reject.
          _livenessComplete = shot.livenessComplete;
          _livenessNote = shot.livenessNote;
          _selfieAdvice = shot.advice;
          _selfieScores = Map<String, dynamic>.from(shot.scores);
        });
      }
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Selfie Error'),
            content: Text('Failed to capture selfie.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isPickingSelfie = false;
      });
    }
  }

  Future<ImageSource?> _showDocumentSourceDialog(String title) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AutoSizeText(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how you want to add your document.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.45),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text(
                          'Camera',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _goOutsBlue,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _goOutsBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<XFile?> _pickDocumentImage({required String dialogTitle}) async {
    final ImageSource? source = await _showDocumentSourceDialog(dialogTitle);
    if (source == null) return null;

    // ── ⚠ imageQuality AND maxWidth REMOVED, 24 August 2026. DO NOT PUT THEM
    //    BACK. ──────────────────────────────────────────────────────────────
    //
    // Either one makes image_picker re-encode the file, which DROPS the EXIF
    // orientation tag WITHOUT rotating the pixels. What is left is a sideways
    // photograph with nothing attached to say it is sideways.
    //
    // On an identity DOCUMENT that is worse than on a selfie, because the
    // quality inspector checks the ASPECT RATIO of a card: a correctly held
    // driving licence measured on its side reads as the wrong shape and is
    // refused. The applicant is told to retake a photograph that was already
    // correct.
    //
    // The resize now happens inside normaliseOrientation, AFTER the rotation
    // has been baked into the pixels where nothing can lose it.
    //
    // Normalised HERE rather than in each caller — licence front, licence back
    // and passport all come through this one method, and one of them would
    // eventually be missed. That is precisely how the consumer app ended up
    // with the gallery path fixed and the camera path not.
    final XFile? picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return null;
    return XFile(await normaliseOrientation(picked.path));
  }

  Future<void> _pickDrivingLicenceFront() async {
    try {
      setState(() {
        _isPickingDrivingLicenceFront = true;
      });
      final XFile? pickedImage = await _pickDocumentImage(
        dialogTitle: 'Upload Driving Licence Front',
      );
      if (!mounted) return;
      if (pickedImage != null) {
        setState(() {
          _drivingLicenceFrontImage = pickedImage;
          _showDrivingLicenceFrontError = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await _showDocumentErrorDialog(title: 'Driving Licence Front Error', error: e);
    } finally {
      if (!mounted) return;
      setState(() {
        _isPickingDrivingLicenceFront = false;
      });
    }
  }

  Future<void> _pickDrivingLicenceBack() async {
    try {
      setState(() {
        _isPickingDrivingLicenceBack = true;
      });
      final XFile? pickedImage = await _pickDocumentImage(
        dialogTitle: 'Upload Driving Licence Back',
      );
      if (!mounted) return;
      if (pickedImage != null) {
        setState(() {
          _drivingLicenceBackImage = pickedImage;
          _showDrivingLicenceBackError = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await _showDocumentErrorDialog(title: 'Driving Licence Back Error', error: e);
    } finally {
      if (!mounted) return;
      setState(() {
        _isPickingDrivingLicenceBack = false;
      });
    }
  }

  Future<void> _pickPassportCopy() async {
    try {
      setState(() {
        _isPickingPassport = true;
      });
      final XFile? pickedImage = await _pickDocumentImage(dialogTitle: 'Upload Passport Copy');
      if (!mounted) return;
      if (pickedImage != null) {
        setState(() {
          _passportImage = pickedImage;
          _showPassportError = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await _showDocumentErrorDialog(title: 'Passport Upload Error', error: e);
    } finally {
      if (!mounted) return;
      setState(() {
        _isPickingPassport = false;
      });
    }
  }

  Future<void> _showDocumentErrorDialog({required String title, required Object error}) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text('Failed to upload your document.\n\n$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _uploadSelfie({required String uid, required XFile selfieImage}) async {
    final String folder = _isBusinessAccount ? 'businesses' : _firestoreDriverCollection;
    final Reference ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child('selfies')
        .child('$uid.jpg');
    await ref.putFile(File(selfieImage.path));
    return ref.getDownloadURL();
  }

  Future<String> _uploadDocumentImage({
    required String uid,
    required XFile image,
    required String folderName,
    required String fileBaseName,
  }) async {
    final String extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final Reference ref = FirebaseStorage.instance
        .ref()
        .child(_firestoreDriverCollection)
        .child('identity_documents')
        .child(uid)
        .child(folderName)
        .child('${fileBaseName}_${DateTime.now().millisecondsSinceEpoch}.$extension');
    await ref.putFile(File(image.path));
    return ref.getDownloadURL();
  }

  /// Mapbox address autocomplete flow (Mapbox-only, no OS).
  ///
  /// Driver types House / Business No + Postcode → taps "Look Up Address" →
  /// we search Mapbox for "{houseNo} {postcode}" — Mapbox's address index
  /// reliably resolves this exact combination to a real building (a bare
  /// postcode alone does NOT — Mapbox only returns the postcode centroid
  /// for that, never a per-building list). Real matches show in a dropdown;
  /// tapping one auto-fills street/town/city/country/coords.
  Future<void> _confirmPostcode() async {
    FocusScope.of(context).unfocus();
    final String? postcodeError =
        _postcodeValidatorLocal(_postcodeController.text);
    if (postcodeError != null) {
      setState(() {
        _autoValidateMode = AutovalidateMode.always;
        _isPostcodeVerified = false;
      });
      _showSnackBarMessage('Please enter a valid postcode before continuing.');
      return;
    }

    final String houseNo = _houseNoController.text.trim();
    if (houseNo.isEmpty) {
      _showSnackBarMessage(
        'Please enter your House / Business No or Name first, then look up your address.',
      );
      return;
    }

    final String postcode = _normalizedPostcode();
    _isUpdatingPostcodeProgrammatically = true;
    _postcodeController.text = postcode;
    _postcodeController.selection =
        TextSelection.collapsed(offset: _postcodeController.text.length);
    _isUpdatingPostcodeProgrammatically = false;

    setState(() {
      _isConfirmingPostcode = true;
    });

    try {
      final List<MapboxSuggestResult> results = await _addressService.suggest(
        '$houseNo $postcode',
        _mapboxSessionToken,
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        setState(() {
          _isConfirmingPostcode = false;
          _addressSuggestions = results;
        });
        return;
      }

      setState(() {
        _isConfirmingPostcode = false;
        _isPostcodeVerified = false;
        _addressFieldsLocked = false;
      });
      _showSnackBarMessage(
        'Address not recognised. Please check it or tap "Enter manually" below.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirmingPostcode = false;
        _isPostcodeVerified = false;
      });
      _showSnackBarMessage(
        'We could not verify this address right now. Please try again.',
      );
    }
  }

  /// Called when the driver taps a suggestion from the address dropdown.
  /// Retrieves full details (street, coords, etc.) and auto-fills everything.
  Future<void> _onSuggestionSelected(MapboxSuggestResult suggestion) async {
    setState(() {
      _isLookingUpAddress = true;
      _addressSuggestions = [];
    });
    final MapboxAddressResult? result = await _addressService.retrieve(
      suggestion.mapboxId,
      _mapboxSessionToken,
    );
    // retrieve() is the billed call — rotate the token so the NEXT lookup
    // starts a fresh free suggest() session.
    _mapboxSessionToken = AddressLookupService.generateSessionToken();

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLookingUpAddress = false);
      _showSnackBarMessage('Could not load that address — please try again.');
      return;
    }

    final String postcode = result.postcode;
    final String? inferredCity =
        AddressLookupService.inferCityFromPostcode(postcode);
    final String resolvedCountry = _inferCountryFromPostcode(postcode);
    final List<String> cityOptions =
        AppLists.cityOptionsForCountry(resolvedCountry);
    final String? matchedCity = inferredCity != null
        ? _matchCityOption(inferredCity, cityOptions)
        : (result.city.isNotEmpty
            ? _matchCityOption(result.city, cityOptions)
            : null);

    setState(() {
      _isLookingUpAddress = false;
      _postcodeController.text = postcode;
      _houseNoController.text = result.houseNumber?.isNotEmpty == true
          ? result.houseNumber!
          : _houseNoController.text;
      _streetNameController.text = result.street ?? '';
      _townController.text = (result.town ?? result.city).toUpperCase();
      _selectedCountry = resolvedCountry;
      _selectedCity = matchedCity;
      _verifiedUprn = '';
      _verifiedFullAddress = result.fullAddress;
      _verifiedLatitude = result.latitude;
      _verifiedLongitude = result.longitude;
      _isPostcodeVerified = true;
      _addressFieldsLocked = false;
    });

    _showSnackBarMessage('Address verified and filled in below.');
  }

  /// Tapped when the user picks "Edit manually" / "Enter manually".
  /// Clears the verified state so the form fields unlock.
  void _handleEditManually() {
    setState(() {
      _isPostcodeVerified = false;
      _verifiedUprn = '';
      _verifiedFullAddress = '';
      _verifiedLatitude = null;
      _verifiedLongitude = null;
      _addressFieldsLocked = false;
      _addressSuggestions = [];
    });
    _townController.clear();
    _showSnackBarMessage(
      'Address fields are now editable. Re-tap "Look Up Address" to re-verify.',
    );
  }

    Future<void> _saveVerificationMetadata({
    required User currentUser,
    required String profilePhotoUrl,
    String? passportUrl,
    String? drivingLicenceFrontUrl,
    String? drivingLicenceBackUrl,
  }) async {
    final String firstName = _firstNameController.text.trim();
    final String surname = _surnameController.text.trim();
    final String postcode = _normalizedPostcode();

    final Map<String, dynamic> payload = <String, dynamic>{
      'profilePhotoUrl': profilePhotoUrl,
      'selfieUrl': profilePhotoUrl,
      // ⚠ ADVISORY, NEVER A DECISION. Client-written and trivially forged.
      // livenessComplete false means the head-sweep ran out of time and the
      // photo was taken anyway — look harder, not reject.
      'livenessComplete': _livenessComplete,
      if (_livenessNote.isNotEmpty) 'livenessNote': _livenessNote,
      if (_selfieAdvice != null) 'selfieAdvice': _selfieAdvice,
      if (_selfieScores != null) 'selfieScores': _selfieScores,
      'identityVerificationStatus': 'submitted',
      'identityVerificationBackendStatus': 'submitted',
      'identityVerificationFailureCount': 0,
      'identityVerificationAttemptCount': 1,
      'identityVerificationSupportThreshold': _verificationSupportThreshold,
      'identityVerificationSupportRecommended': false,
      'identityVerificationSupportReason': '',
      'identityVerificationSubmittedAt': FieldValue.serverTimestamp(),
      'identityVerificationLastUpdatedAt': FieldValue.serverTimestamp(),
      'identityVerificationChecks': <String, dynamic>{
        'selfieSubmitted': true,
        'faceRecognitionPending': true,
        'nameSubmitted': firstName.isNotEmpty,
        'surnameSubmitted': surname.isNotEmpty,
        'postcodeSubmitted': postcode.isNotEmpty,
        'passportSubmitted': passportUrl != null && passportUrl.isNotEmpty,
        'drivingLicenceFrontSubmitted':
            drivingLicenceFrontUrl != null && drivingLicenceFrontUrl.isNotEmpty,
        'drivingLicenceBackSubmitted':
            drivingLicenceBackUrl != null && drivingLicenceBackUrl.isNotEmpty,
      },
    };

    if (_requiresDrivingLicenceFrontAndBack()) {
      payload.addAll(<String, dynamic>{
        'identityDocumentType': 'driving_licence',
        'identityDocumentLabel': 'Driving Licence',
        'drivingLicenceFrontUrl': drivingLicenceFrontUrl ?? '',
        'drivingLicenceBackUrl': drivingLicenceBackUrl ?? '',
        'identityDocumentUrl': '',
      });
    } else {
      payload.addAll(<String, dynamic>{
        'identityDocumentType': 'passport',
        'identityDocumentLabel': 'Passport',
        'identityDocumentUrl': passportUrl ?? '',
        'drivingLicenceFrontUrl': '',
        'drivingLicenceBackUrl': '',
      });
    }

    await FirebaseFirestore.instance
        .collection(_firestoreDriverCollection)
        .doc(currentUser.uid)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> _saveAdditionalRegistrationMetadata({
    required User currentUser,
    required DriverModel driver,
  }) async {
    final Map<String, dynamic> updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'country': _selectedCountry?.trim() ?? '',
      'city': _selectedCity?.trim() ?? '',
      'analyticsCountry': _selectedCountry?.trim() ?? '',
      'analyticsCity': _selectedCity?.trim() ?? '',
      'postcode': _normalizedPostcode(),
      'postcodeVerified': _isPostcodeVerified,
      'postcodeVerificationProvider':
          _isPostcodeVerified ? 'os_mapbox_hybrid' : '',
      'addressUprn': _verifiedUprn,
      'addressFull': _verifiedFullAddress,
      'addressLatitude': _verifiedLatitude,
      'addressLongitude': _verifiedLongitude,
      'registrationCompleted': driver.registrationCompleted,
      'rightToWorkConfirmed': _hasRightToWork,
      'termsAccepted': _acceptedTerms,
      'houseNoOrName': _houseNoController.text.trim(),
      'streetName': _streetNameController.text.trim(),
      'town': _townController.text.trim().toUpperCase(),
      'requiredDocumentType':
          _requiresDrivingLicenceFrontAndBack() ? 'driving_licence' : 'passport',
      'requiredDocumentLabel':
          _requiresDrivingLicenceFrontAndBack() ? 'Driving Licence' : 'Passport',
    };

    if (_isPostcodeVerified) {
      updateData['postcodeVerifiedAt'] = FieldValue.serverTimestamp();
    }
    if (_hasRightToWork) {
      updateData['rightToWorkConfirmedAt'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection(_firestoreDriverCollection)
        .doc(currentUser.uid)
        .set(updateData, SetOptions(merge: true));
  }

  Future<void> _syncReferralInviteResolution({
    required User currentUser,
    required DriverModel driver,
    required String normalizedReferralCode,
    required String inviteToken,
  }) async {
    final String normalizedPhone = _normalizePhoneForInviteMatching(
      currentUser.phoneNumber ?? '',
    );
    if (normalizedPhone.isEmpty) return;

    final QuerySnapshot<Map<String, dynamic>> phoneInviteSnapshot =
        await FirebaseFirestore.instance
            .collection('invites')
            .where('inviteePhoneNormalized', isEqualTo: normalizedPhone)
            .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> inviteDocs = phoneInviteSnapshot.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final String status = _readMapString(data, 'status').toLowerCase();
      return status != 'cancelled' && status != 'expired';
    }).toList();

    if (inviteDocs.isEmpty) return;

    QueryDocumentSnapshot<Map<String, dynamic>>? winningInviteDoc;
    final String normalizedInviteToken = _normalizeInviteToken(inviteToken);

    if (normalizedInviteToken.isNotEmpty) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in inviteDocs) {
        if (_normalizeInviteToken(doc.id) == normalizedInviteToken) {
          winningInviteDoc = doc;
          break;
        }
      }
    }

    if (winningInviteDoc == null) {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> matchingCodeDocs = inviteDocs
          .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final String code = _readMapString(doc.data(), 'referralCode').trim().toUpperCase();
        return code == normalizedReferralCode;
      }).toList();

      matchingCodeDocs.sort((a, b) {
        final DateTime? aDate =
            _readMapDateTime(a.data(), 'sentAt') ?? _readMapDateTime(a.data(), 'updatedAt');
        final DateTime? bDate =
            _readMapDateTime(b.data(), 'sentAt') ?? _readMapDateTime(b.data(), 'updatedAt');
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (matchingCodeDocs.isNotEmpty) {
        winningInviteDoc = matchingCodeDocs.first;
      }
    }

    if (winningInviteDoc == null) return;

    final Map<String, dynamic> winningData = winningInviteDoc.data();
    final String winningInviterUid = _readMapString(winningData, 'inviterUid');
    final String winningReferralCode = _readMapString(winningData, 'referralCode').toUpperCase();
    final String joinedDriverName = _buildJoinedDriverName(
      firstName: driver.firstName,
      middleName: driver.middleName,
      surname: driver.surname,
    );

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in inviteDocs) {
      final Map<String, dynamic> data = doc.data();
      final String inviterUid = _readMapString(data, 'inviterUid');
      final String inviteId = _readMapString(data, 'inviteId');
      final String referralCode = _readMapString(data, 'referralCode').toUpperCase();

      final bool sameWinnerAttribution =
          inviterUid == winningInviterUid && referralCode == winningReferralCode;

      final Map<String, dynamic> updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'joinedDriverUid': currentUser.uid,
        'joinedDriverName': joinedDriverName,
        'joinedDriverSelfieUrl': driver.profilePhotoUrl,
        'joinedAt': FieldValue.serverTimestamp(),
        'city': driver.city.trim().toUpperCase(),
        'joinedDriverCity': driver.city.trim().toUpperCase(),
      };

      if (sameWinnerAttribution) {
        updateData['status'] = 'joined';
        updateData['resolutionReason'] = 'joined_with_this_referrer';
      } else {
        updateData['status'] = 'joined_elsewhere';
        updateData['resolutionReason'] = 'joined_with_other_referrer';
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
      }

      batch.set(doc.reference, updateData, SetOptions(merge: true));

      if (inviterUid.isNotEmpty && inviteId.isNotEmpty) {
        batch.set(
          FirebaseFirestore.instance
              .collection(_firestoreDriverCollection)
              .doc(inviterUid)
              // FIXED 3 August 2026. This read 'sentinvites', no underscore.
              // Every reader uses 'sent_invites', including
              // driver_home_screen.dart, so a driver's invite resolution was
              // being written to a subcollection nothing looks at. The
              // inviter never saw that their referral had joined.
              //
              // The business path further down this same file was already
              // correct, which is why it only affected drivers. driver_app's
              // header note says "4) sentinvites -> sentinvites", a mangled
              // instruction that was never actually carried out here.
              .collection('sent_invites')
              .doc(inviteId),
          updateData,
          SetOptions(merge: true),
        );
      }
    }

    batch.set(
      FirebaseFirestore.instance
          .collection(_firestoreDriverCollection)
          .doc(currentUser.uid),
      <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'referralCodeUsed': normalizedReferralCode,
        'inviteTokenUsed': normalizedInviteToken,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _syncBusinessReferralInviteResolution({
    required User currentUser,
    required String fullName,
    required String profilePhotoUrl,
    required String city,
    required String normalizedReferralCode,
    required String inviteToken,
  }) async {
    final String normalizedPhone = _normalizePhoneForInviteMatching(
      currentUser.phoneNumber ?? '',
    );
    if (normalizedPhone.isEmpty) return;

    final QuerySnapshot<Map<String, dynamic>> phoneInviteSnapshot =
        await FirebaseFirestore.instance
            .collection('invites')
            .where('inviteePhoneNormalized', isEqualTo: normalizedPhone)
            .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> inviteDocs =
        phoneInviteSnapshot.docs.where((doc) {
      final String status = _readMapString(doc.data(), 'status').toLowerCase();
      return status != 'cancelled' && status != 'expired';
    }).toList();

    if (inviteDocs.isEmpty) return;

    QueryDocumentSnapshot<Map<String, dynamic>>? winningInviteDoc;
    final String normalizedInviteToken = _normalizeInviteToken(inviteToken);

    if (normalizedInviteToken.isNotEmpty) {
      for (final doc in inviteDocs) {
        if (_normalizeInviteToken(doc.id) == normalizedInviteToken) {
          winningInviteDoc = doc;
          break;
        }
      }
    }

    if (winningInviteDoc == null) {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> matchingCodeDocs =
          inviteDocs.where((doc) {
        final String code =
            _readMapString(doc.data(), 'referralCode').trim().toUpperCase();
        return code == normalizedReferralCode;
      }).toList();

      matchingCodeDocs.sort((a, b) {
        final DateTime? aDate =
            _readMapDateTime(a.data(), 'sentAt') ?? _readMapDateTime(a.data(), 'updatedAt');
        final DateTime? bDate =
            _readMapDateTime(b.data(), 'sentAt') ?? _readMapDateTime(b.data(), 'updatedAt');
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (matchingCodeDocs.isNotEmpty) winningInviteDoc = matchingCodeDocs.first;
    }

    if (winningInviteDoc == null) return;

    final Map<String, dynamic> winningData = winningInviteDoc.data();
    final String winningInviterUid = _readMapString(winningData, 'inviterUid');
    final String winningReferralCode =
        _readMapString(winningData, 'referralCode').toUpperCase();

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final doc in inviteDocs) {
      final Map<String, dynamic> data = doc.data();
      final String inviterUid = _readMapString(data, 'inviterUid');
      final String inviteId = _readMapString(data, 'inviteId');
      final String referralCode =
          _readMapString(data, 'referralCode').toUpperCase();

      final bool sameWinner =
          inviterUid == winningInviterUid && referralCode == winningReferralCode;

      final Map<String, dynamic> updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'joinedDriverUid': currentUser.uid,
        'joinedDriverName': fullName,
        'joinedDriverSelfieUrl': profilePhotoUrl,
        'joinedAt': FieldValue.serverTimestamp(),
        'city': city.trim().toUpperCase(),
        'joinedDriverCity': city.trim().toUpperCase(),
      };

      if (sameWinner) {
        updateData['status'] = 'joined';
        updateData['resolutionReason'] = 'joined_with_this_referrer';
      } else {
        updateData['status'] = 'joined_elsewhere';
        updateData['resolutionReason'] = 'joined_with_other_referrer';
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
      }

      batch.set(doc.reference, updateData, SetOptions(merge: true));

      if (inviterUid.isNotEmpty && inviteId.isNotEmpty) {
        batch.set(
          FirebaseFirestore.instance
              .collection('businesses')
              .doc(inviterUid)
              .collection('sent_invites')
              .doc(inviteId),
          updateData,
          SetOptions(merge: true),
        );
      }
    }

    batch.set(
      FirebaseFirestore.instance
          .collection('businesses')
          .doc(currentUser.uid),
      <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'referralCodeUsed': normalizedReferralCode,
        'inviteTokenUsed': normalizedInviteToken,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _goToDriverHome() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DriverHomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _goToBusinessHome() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const BusinessHomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  /// Links an email+password credential to the current Firebase phone-auth
  /// account so returning users can sign in with password instead of SMS OTP.
  /// Email format: {e164PhoneDigitsOnly}@goouts.app
  /// Silently ignores errors (e.g. credential already linked).
  Future<void> _linkEmailPasswordCredential({
    required User currentUser,
    required String password,
  }) async {
    try {
      final String phone = currentUser.phoneNumber ?? '';
      final String email =
          '${phone.replaceAll('+', '').replaceAll(' ', '')}@goouts.app';
      final AuthCredential cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await currentUser.linkWithCredential(cred);
    } catch (_) {
      // Already linked or non-critical — ignore
    }
  }

  Future<void> _submitBusinessForm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      _showSnackBarMessage('Please complete all required fields before continuing.');
      return;
    }
    if (!_isPostcodeVerified) {
      _showSnackBarMessage('Please confirm your postcode before continuing.');
      return;
    }
    if (_selectedCountry == null || _selectedCountry == '-') {
      _showSnackBarMessage('Please select your country.');
      return;
    }
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      _showSnackBarMessage('Please select your city.');
      return;
    }
    if (_selfieImage == null) {
      setState(() {
        _showSelfieError = true;
      });
      _showSnackBarMessage('Please capture your selfie before continuing.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() {
        _showTermsError = true;
      });
      await _showTermsRequiredDialog();
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Not Logged In'),
            content: const Text(
              'No authenticated business user was found. Please log in again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final Map<String, dynamic> routeArgs = _routeArguments();
    final String inviteToken = _normalizeInviteToken(_readMapString(routeArgs, 'inviteToken'));
    String normalizedReferralCode = _normalizeReferralCode(widget.referralCode);
    if (!normalizedReferralCode.startsWith('GB')) {
      normalizedReferralCode = _defaultBusinessReferralCode;
    }

    final DateTime now = DateTime.now();
    final String profilePhotoUrl = await _uploadSelfie(
      uid: currentUser.uid,
      selfieImage: _selfieImage!,
    );
    final String firstName = _firstNameController.text.trim();
    final String surname = _surnameController.text.trim();
    final String fullName = _titleCase('$firstName $surname'.trim());

    setState(() {
      _isLoading = true;
    });

    try {
      final String ownReferralCode = _generateBusinessReferralCode(currentUser.uid);
      final Map<String, dynamic> businessData = <String, dynamic>{
        'uid': currentUser.uid,
        'accountType': 'business',
        'dashboardRole': 'business',
        'phoneNumber': currentUser.phoneNumber ?? '',
        'prefix': (_selectedPrefix ?? '').trim(),
        'firstName': firstName,
        'middleName': '',
        'surname': surname,
        'fullName': fullName,
        'contactPersonName': fullName,
        'email': _emailController.text.trim(),
        'legalBusinessName': _legalBusinessNameController.text.trim(),
        'companyNumber': _companyNumberController.text.trim().toUpperCase(),
        'country': _selectedCountry?.trim() ?? '',
        'city': _selectedCity?.trim() ?? '',
        'analyticsCountry': _selectedCountry?.trim() ?? '',
        'analyticsCity': _selectedCity?.trim() ?? '',
        'postcode': _normalizedPostcode(),
        'postcodeVerified': _isPostcodeVerified,
        'postcodeVerificationProvider':
            _isPostcodeVerified ? 'os_mapbox_hybrid' : '',
        'addressUprn': _verifiedUprn,
        'addressFull': _verifiedFullAddress,
        'addressLatitude': _verifiedLatitude,
        'addressLongitude': _verifiedLongitude,
        'houseNoOrName': _houseNoController.text.trim(),
        'streetName': _streetNameController.text.trim(),
        'town': _townController.text.trim().toUpperCase(),
        'termsAccepted': true,
        'status': 'PENDING',
        'registrationCompleted': true,
        'referralCodeUsed': normalizedReferralCode,
        'inviteTokenUsed': inviteToken,
        'ownReferralCode': ownReferralCode,
        'referralCode': ownReferralCode,
        'profilePhotoUrl': profilePhotoUrl,
        'selfieUrl': profilePhotoUrl,
      // ⚠ ADVISORY, NEVER A DECISION. Client-written and trivially forged.
      // livenessComplete false means the head-sweep ran out of time and the
      // photo was taken anyway — look harder, not reject.
      'livenessComplete': _livenessComplete,
      if (_livenessNote.isNotEmpty) 'livenessNote': _livenessNote,
      if (_selfieAdvice != null) 'selfieAdvice': _selfieAdvice,
      if (_selfieScores != null) 'selfieScores': _selfieScores,
        'businessProfileVerificationStatus': 'submitted',
        'businessProfileVerificationBackendStatus': 'submitted',
        'businessProfileVerificationSubmittedAt': FieldValue.serverTimestamp(),
        'businessProfileVerificationLastUpdatedAt': FieldValue.serverTimestamp(),
        'createdAt': now,
        'updatedAt': now,
      };

      if (_isPostcodeVerified) {
        businessData['postcodeVerifiedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(currentUser.uid)
          .set(businessData, SetOptions(merge: true));

      // Link email+password so returning users can log in without SMS OTP
      await _linkEmailPasswordCredential(
        currentUser: currentUser,
        password: _pinController.text,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Registration Completed'),
            content: const SingleChildScrollView(
              child: Text(
                'Thanks for joining GoOuts.\n\nYour personal details, business details, address, and selfie have been submitted successfully.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      await _syncBusinessReferralInviteResolution(
        currentUser: currentUser,
        fullName: fullName,
        profilePhotoUrl: profilePhotoUrl,
        city: _selectedCity ?? '',
        normalizedReferralCode: normalizedReferralCode,
        inviteToken: inviteToken,
      );

      await _goToBusinessHome();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save business registration.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitDriverForm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      _showSnackBarMessage('Please complete all required fields correctly before continuing.');
      return;
    }
    if (_selectedMonth == null || _selectedYear == null) {
      _showSnackBarMessage('Please select your birth month and birth year.');
      return;
    }
    if (_selectedVehicleType == null || _selectedVehicleType!.trim().isEmpty) {
      _showSnackBarMessage('Please select your vehicle type.');
      return;
    }
    if (!_isPostcodeVerified) {
      _showSnackBarMessage('Please confirm your postcode before continuing.');
      return;
    }
    if (_selectedCountry == null || _selectedCountry == '-') {
      _showSnackBarMessage('Please select your country.');
      return;
    }
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      _showSnackBarMessage('Please select your city.');
      return;
    }
    if (_selfieImage == null) {
      setState(() {
        _showSelfieError = true;
      });
      _showSnackBarMessage('Please capture your selfie before continuing.');
      return;
    }
    if (_requiresDrivingLicenceFrontAndBack()) {
      if (_drivingLicenceFrontImage == null) {
        setState(() {
          _showDrivingLicenceFrontError = true;
        });
        _showSnackBarMessage('Please upload the front of your driving licence.');
        return;
      }
      if (_drivingLicenceBackImage == null) {
        setState(() {
          _showDrivingLicenceBackError = true;
        });
        _showSnackBarMessage('Please upload the back of your driving licence.');
        return;
      }
    }
    if (_requiresPassportCopy() && _passportImage == null) {
      setState(() {
        _showPassportError = true;
      });
      _showSnackBarMessage('Please upload your passport copy.');
      return;
    }
    if (!_acceptedTerms || !_hasRightToWork) {
      setState(() {
        _showTermsError = !_acceptedTerms;
        _showRightToWorkError = !_hasRightToWork;
      });
      await _showTermsRequiredDialog();
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Not Logged In'),
            content: const Text('No authenticated driver was found. Please log in again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final Map<String, dynamic> routeArgs = _routeArguments();
    final String inviteToken = _normalizeInviteToken(_readMapString(routeArgs, 'inviteToken'));
    final String selectedMonth = _selectedMonth!;
    final int selectedYear = _selectedYear!;
    final int age = DriverValidators.calculateAge(
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
      monthOptions: AppLists.monthOptions,
    );

    String normalizedReferralCode = _normalizeReferralCode(widget.referralCode);
    if (_isCabDriverAccount) {
      if (!normalizedReferralCode.startsWith('GC')) {
        normalizedReferralCode = _defaultCabDriverReferralCode;
      }
    } else {
      if (!normalizedReferralCode.startsWith('GD')) {
        normalizedReferralCode = _defaultDriverReferralCode;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String profilePhotoUrl = await _uploadSelfie(
        uid: currentUser.uid,
        selfieImage: _selfieImage!,
      );

      String? passportUrl;
      String? drivingLicenceFrontUrl;
      String? drivingLicenceBackUrl;

      if (_requiresDrivingLicenceFrontAndBack()) {
        drivingLicenceFrontUrl = await _uploadDocumentImage(
          uid: currentUser.uid,
          image: _drivingLicenceFrontImage!,
          folderName: 'driving_licence',
          fileBaseName: 'front',
        );
        drivingLicenceBackUrl = await _uploadDocumentImage(
          uid: currentUser.uid,
          image: _drivingLicenceBackImage!,
          folderName: 'driving_licence',
          fileBaseName: 'back',
        );
      } else {
        passportUrl = await _uploadDocumentImage(
          uid: currentUser.uid,
          image: _passportImage!,
          folderName: 'passport',
          fileBaseName: 'passport',
        );
      }

      final DateTime now = DateTime.now();
      final DriverModel driver = DriverModel(
        uid: currentUser.uid,
        phoneNumber: currentUser.phoneNumber ?? '',
        prefix: (_selectedPrefix ?? '').trim(),
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        surname: _surnameController.text.trim(),
        birthMonth: selectedMonth.trim(),
        birthYear: selectedYear.toString(),
        age: age,
        email: _emailController.text.trim(),
        country: _selectedCountry!.trim(),
        houseNoOrName: _houseNoController.text.trim(),
        streetName: _streetNameController.text.trim(),
        town: _townController.text.trim(),
        city: _selectedCity!.trim(),
        postcode: _normalizedPostcode(),
        vehicleType: (_selectedVehicleType ?? '').trim(),
        drivingLicenceNumber:
            _vehicleNeedsLicence() ? _drivingLicenceNumberController.text.trim() : '',
        registrationCompleted: true,
        status: 'PENDING',
        termsAccepted: true,
        referralCodeUsed: normalizedReferralCode,
        ownReferralCode: _isCabDriverAccount
            ? _generateCabDriverReferralCode(currentUser.uid)
            : _generateOwnReferralCode(currentUser.uid),
        profilePhotoUrl: profilePhotoUrl,
        createdAt: now,
        updatedAt: now,
      );

      await _driverRegistrationService.registerDriver(
        driver,
        collection: _firestoreDriverCollection,
      );
      await _saveAdditionalRegistrationMetadata(currentUser: currentUser, driver: driver);
      await _saveVerificationMetadata(
        currentUser: currentUser,
        profilePhotoUrl: profilePhotoUrl,
        passportUrl: passportUrl,
        drivingLicenceFrontUrl: drivingLicenceFrontUrl,
        drivingLicenceBackUrl: drivingLicenceBackUrl,
      );
      await _syncReferralInviteResolution(
        currentUser: currentUser,
        driver: driver,
        normalizedReferralCode: normalizedReferralCode,
        inviteToken: inviteToken,
      );

      // Link email+password so returning users can log in without SMS OTP
      await _linkEmailPasswordCredential(
        currentUser: currentUser,
        password: _pinController.text,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Registration Completed'),
            content: SingleChildScrollView(
              child: Text(
                _requiresDrivingLicenceFrontAndBack()
                    ? 'Thanks for joining GoOuts.\n\nYour details, selfie, and driving licence front and back have been submitted successfully.'
                    : 'Thanks for joining GoOuts.\n\nYour details, selfie, and passport copy have been submitted successfully.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      await _goToDriverHome();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save registration.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_isBusinessAccount) {
      await _submitBusinessForm();
      return;
    }
    // Both delivery driver and cab driver use the same form submission flow.
    // _firestoreDriverCollection handles routing to correct collection.
    await _submitDriverForm();
  }

  void _clearAllDocumentSelections() {
    _passportImage = null;
    _drivingLicenceFrontImage = null;
    _drivingLicenceBackImage = null;
    _showPassportError = false;
    _showDrivingLicenceFrontError = false;
    _showDrivingLicenceBackError = false;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  List<TextInputFormatter> _upperCaseFormatters() {
    return <TextInputFormatter>[
      TextInputFormatter.withFunction((TextEditingValue oldValue, TextEditingValue newValue) {
        return TextEditingValue(
          text: newValue.text.toUpperCase(),
          selection: newValue.selection,
        );
      }),
    ];
  }

  List<TextInputFormatter> _ukDrivingLicenceFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      LengthLimitingTextInputFormatter(16),
      TextInputFormatter.withFunction((TextEditingValue oldValue, TextEditingValue newValue) {
        final String upper = newValue.text.toUpperCase();
        if (upper.length <= 5) {
          if (!RegExp(r'^[A-Z]*$').hasMatch(upper)) return oldValue;
        } else {
          final String firstPart = upper.substring(0, 5);
          final String secondPart = upper.substring(5);
          if (!RegExp(r'^[A-Z]{5}$').hasMatch(firstPart)) return oldValue;
          if (!RegExp(r'^[0-9]*$').hasMatch(secondPart)) return oldValue;
        }
        return TextEditingValue(
          text: upper,
          selection: TextSelection.collapsed(offset: upper.length),
        );
      }),
    ];
  }

  List<TextInputFormatter> _niDrivingLicenceFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(8),
    ];
  }

  String? _requiredValidator(String? value, String fieldName) {
    return DriverValidators.requiredField(value, fieldName);
  }

  String? _prefixValidator(String? value) => DriverValidators.prefixValidator(value);
  String? _countryValidator(String? value) => DriverValidators.countryValidator(value);
  String? _cityValidator(String? value) => DriverValidators.cityValidator(value);

  String? _businessCityValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'City is required';
    return null;
  }

  String? _postcodeValidator(String? value) => _postcodeValidatorLocal(value);
  String? _emailValidator(String? value) => DriverValidators.emailValidator(value);

  String? _confirmEmailValidator(String? value) {
    return DriverValidators.confirmEmailValidator(value, _emailController.text);
  }

  String? _pinValidator(String? value) => DriverValidators.pinValidator(value);

  String? _confirmPinValidator(String? value) {
    return DriverValidators.confirmPinValidator(value, _pinController.text);
  }

  String? _monthDropdownValidator(String? value) => DriverValidators.monthDropdownValidator(value);
  String? _yearDropdownValidator(int? value) => DriverValidators.yearDropdownValidator(value);
  String? _vehicleTypeValidator(String? value) => DriverValidators.vehicleTypeValidator(value);

  String? _drivingLicenceNumberValidator(String? value) {
    return DriverValidators.drivingLicenceNumberValidator(
      value: value,
      needsLicence: _vehicleNeedsLicence(),
      isNorthernIreland: _isNorthernIreland(),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String emptyText,
    required XFile? image,
    required bool isLoading,
    required bool showError,
    required VoidCallback? onPressed,
  }) {
    return RegistrationSectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(image.path),
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: showError ? Colors.red : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file_rounded, size: 42, color: Colors.black45),
                  const SizedBox(height: 10),
                  Text(
                    emptyText,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Icon(image == null ? Icons.upload_file_rounded : Icons.check_circle_rounded),
              label: Text(
                isLoading ? 'Uploading...' : image == null ? 'Upload' : 'Uploaded',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: image != null ? Colors.green : _goOutsBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'This upload is required before continuing.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelfieSection({required String title, required String description}) {
    return RegistrationSectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: const TextStyle(color: Colors.black54, height: 1.5)),
          const SizedBox(height: 14),
          if (_selfieImage != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_selfieImage!.path),
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showSelfieError ? Colors.red : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.camera_alt_rounded, size: 42, color: Colors.black45),
                  SizedBox(height: 10),
                  Text(
                    'No selfie captured yet',
                    style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isLoading || _isPickingSelfie) ? null : _pickSelfie,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selfieImage != null ? Colors.green : _goOutsBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isPickingSelfie
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_selfieImage != null) ...[
                              const Icon(Icons.check_circle, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _selfieImage == null ? 'Take Selfie' : 'Selfie Captured',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (_showSelfieError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Please capture your selfie before continuing.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessRegistrationBody() {
    final String currentPhoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    final String ukLocalMobileNumber = _extractUkLocalMobile(currentPhoneNumber);
    String normalizedReferralCode = _normalizeReferralCode(widget.referralCode);
    if (!normalizedReferralCode.startsWith('GB')) {
      normalizedReferralCode = _defaultBusinessReferralCode;
    }

    return Column(
      children: [
        RegistrationSectionCard(
          title: 'Business Referral Details',
          child: Row(
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _goOutsBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.groups_rounded, color: _goOutsBlue, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral code applied',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    SizedBox(height: 6),
                    AutoSizeText(
                      normalizedReferralCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _goOutsBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSelfieSection(
          title: 'Profile Photo',
          description:
              'Please capture a clear selfie. This photo will be used in your business profile and profile section.',
        ),
        const SizedBox(height: 16),
        RegistrationSectionCard(
          title: 'Personal Information',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedPrefix,
                decoration: _inputDecoration('Prefix'),
                items: AppLists.prefixOptions
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedPrefix = value;
                  });
                },
                validator: _prefixValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('First Name'),
                validator: (String? value) => _requiredValidator(value, 'First Name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _surnameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Surname'),
                validator: (String? value) => _requiredValidator(value, 'Surname'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email Address'),
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Confirm Email Address'),
                validator: _confirmEmailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue:
                    ukLocalMobileNumber.isNotEmpty ? ukLocalMobileNumber : currentPhoneNumber,
                readOnly: true,
                decoration: _inputDecoration('Mobile Number'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AccountInfoSection(
          pinController: _pinController,
          confirmPinController: _confirmPinController,
          obscurePin: _obscurePin,
          obscureConfirmPin: _obscureConfirmPin,
          onTogglePin: () {
            setState(() {
              _obscurePin = !_obscurePin;
            });
          },
          onToggleConfirmPin: () {
            setState(() {
              _obscureConfirmPin = !_obscureConfirmPin;
            });
          },
          inputDecorationBuilder: _inputDecoration,
          pinValidator: _pinValidator,
          confirmPinValidator: _confirmPinValidator,
        ),
        const SizedBox(height: 16),
        RegistrationSectionCard(
          title: 'Business Information',
          child: Column(
            children: [
              TextFormField(
                controller: _legalBusinessNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Legal Business Name'),
                validator: (String? value) =>
                  _requiredValidator(value, 'Legal Business Name'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyNumberController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(8),
            ..._upperCaseFormatters(),
        ],
        decoration: _inputDecoration('Company Registration No'),
        validator: (String? value) =>
            _requiredValidator(value, 'Company Registration No'),
        onChanged: (_) => setState(() {}),
      ),
              const SizedBox(height: 16),

              // ── Shop / Unit No — typed FIRST, needed to search Mapbox ──
              TextFormField(
                controller: _houseNoController,
                textCapitalization: TextCapitalization.words,
                readOnly: _addressFieldsLocked,
                decoration: _inputDecoration('Shop / Unit No'),
                validator: (String? value) => _requiredValidator(value, 'Shop / Unit No'),
              ),
              const SizedBox(height: 16),

              // ── Postcode + Look Up Address ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _postcodeController,
                      inputFormatters: _upperCaseFormatters(),
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration('Postcode'),
                      validator: _postcodeValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: (_isConfirmingPostcode || _isLookingUpAddress)
                            ? null
                            : _confirmPostcode,
                        icon: _isConfirmingPostcode
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isPostcodeVerified
                                    ? Icons.verified_rounded
                                    : Icons.search_rounded,
                              ),
                        label: AutoSizeText(
                          _isPostcodeVerified ? 'Verified' : 'Look Up Address',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPostcodeVerified
                              ? const Color(0xFF16A34A)
                              : _goOutsBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Address dropdown ─────────────────────────────────────
              if (_addressSuggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _goOutsBlue.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Text(
                          'Select your address:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      ..._addressSuggestions.map((s) => InkWell(
                        onTap: () => _onSuggestionSelected(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: _goOutsBlue, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0D1B3E),
                                      ),
                                    ),
                                    Text(
                                      s.placeFormatted,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 16),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
              if (_isLookingUpAddress) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Loading address…', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (_isPostcodeVerified)
                Row(
                  children: <Widget>[
                    const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Address Verified',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _isConfirmingPostcode ? null : _handleEditManually,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: _goOutsBlue,
                      ),
                      child: const AutoSizeText(
                        'Edit manually',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        _isConfirmingPostcode ? null : _handleEditManually,
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
              const SizedBox(height: 16),

              // ── Street / Road Name — auto-filled when address picked ──
              TextFormField(
                controller: _streetNameController,
                textCapitalization: TextCapitalization.words,
                readOnly: _addressFieldsLocked,
                decoration: _inputDecoration('Street / Road Name'),
                validator: (String? value) => _requiredValidator(value, 'Street / Road Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: _inputDecoration('Country'),
                items: AppLists.countryOptions
                    .map((String value) =>
                        DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCountry = value;
                    _selectedCity = null;
                    _isPostcodeVerified = false;
                    _verifiedUprn = '';
                    _verifiedFullAddress = '';
                    _verifiedLatitude = null;
                    _verifiedLongitude = null;
                  });
                },
                validator: _countryValidator,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: _inputDecoration('City'),
                items: _cityOptionsForSelectedCountry()
                    .map((String value) =>
                        DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
                validator: _businessCityValidator,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RegistrationSectionCard(
          title: 'Terms & Conditions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    activeColor: _goOutsBlue,
                    onChanged: (bool? value) {
                      setState(() {
                        _acceptedTerms = value ?? false;
                        if (_acceptedTerms) {
                          _showTermsError = false;
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        children: [
                          const Text('I agree to the '),
                          GestureDetector(
                            onTap: _openTermsAndConditions,
                            child: const Text(
                              'Terms & Conditions',
                              style: TextStyle(
                                color: _goOutsBlue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Text(' of GoOuts.'),
                        ],
                      ),
                    ),
                  ),
                  if (_acceptedTerms)
                    Padding(
                      padding: EdgeInsets.only(top: 10, right: 6),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                ],
              ),
              if (_showTermsError)
                Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'Please accept the Terms & Conditions to continue.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _goOutsBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : AutoSizeText(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already registered? ',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0392CA),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => showPreAuthSupportSheet(
              context,
              accountType: _isBusinessAccount ? 'business' : 'driver',
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDriverRegistrationBody() {
    final bool needsLicence = _vehicleNeedsLicence();
    final String currentPhoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    final String ukLocalMobileNumber = _extractUkLocalMobile(currentPhoneNumber);

    return Column(
      children: [
        RegistrationSectionCard(
          title: 'Referral Details',
          child: Row(
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _goOutsBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.groups_rounded, color: _goOutsBlue, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral code applied',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    SizedBox(height: 6),
                    AutoSizeText(
                      _normalizeReferralCode(widget.referralCode),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _goOutsBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSelfieSection(
          title: 'Selfie Verification',
          description:
              'Please capture a clear selfie. This photo will be used as your profile picture and verification selfie.',
        ),
        const SizedBox(height: 16),
        PersonalInfoSection(
          selectedPrefix: _selectedPrefix,
          prefixOptions: AppLists.prefixOptions,
          onPrefixChanged: (String? value) {
            setState(() {
              _selectedPrefix = value;
            });
          },
          firstNameController: _firstNameController,
          middleNameController: _middleNameController,
          surnameController: _surnameController,
          emailController: _emailController,
          confirmEmailController: _confirmEmailController,
          ukLocalMobileNumber: ukLocalMobileNumber,
          selectedMonth: _selectedMonth,
          monthOptions: AppLists.monthOptions,
          onMonthChanged: (String? value) {
            setState(() {
              _selectedMonth = value;
            });
          },
          selectedYear: _selectedYear,
          yearOptions: _yearOptions,
          onYearChanged: (int? value) {
            setState(() {
              _selectedYear = value;
            });
          },
          inputDecorationBuilder: _inputDecoration,
          upperCaseFormattersBuilder: _upperCaseFormatters,
          prefixValidator: _prefixValidator,
          requiredValidator: _requiredValidator,
          emailValidator: _emailValidator,
          confirmEmailValidator: _confirmEmailValidator,
          monthValidator: _monthDropdownValidator,
          yearValidator: _yearDropdownValidator,
        ),
        const SizedBox(height: 16),
        AccountInfoSection(
          pinController: _pinController,
          confirmPinController: _confirmPinController,
          obscurePin: _obscurePin,
          obscureConfirmPin: _obscureConfirmPin,
          onTogglePin: () {
            setState(() {
              _obscurePin = !_obscurePin;
            });
          },
          onToggleConfirmPin: () {
            setState(() {
              _obscureConfirmPin = !_obscureConfirmPin;
            });
          },
          inputDecorationBuilder: _inputDecoration,
          pinValidator: _pinValidator,
          confirmPinValidator: _confirmPinValidator,
        ),
        const SizedBox(height: 16),
        ContactInfoSection(
          postcodeController: _postcodeController,
          houseNoController: _houseNoController,
          streetNameController: _streetNameController,
          townController: _townController,
          selectedCountry: _selectedCountry,
          countryOptions: AppLists.countryOptions,
          onCountryChanged: (String? value) {
            setState(() {
              _selectedCountry = value;
              _selectedCity = null;
              _isPostcodeVerified = false;
              _verifiedUprn = '';
              _verifiedFullAddress = '';
              _verifiedLatitude = null;
              _verifiedLongitude = null;
            });
          },
          selectedCity: _selectedCity,
          cityOptions: _cityOptionsForSelectedCountry(),
          onCityChanged: (String? value) {
            setState(() {
              _selectedCity = value;
            });
          },
          isPostcodeVerified: _isPostcodeVerified,
          isConfirmingPostcode: _isConfirmingPostcode,
          lockAddressFields: _addressFieldsLocked,
          isLookingUpAddress: _isLookingUpAddress,
          onConfirmPostcode: _confirmPostcode,
          onEditManually: _handleEditManually,
          addressSuggestions: _addressSuggestions,
          onAddressSelected: _onSuggestionSelected,
          inputDecorationBuilder: _inputDecoration,
          upperCaseFormattersBuilder: _upperCaseFormatters,
          requiredValidator: _requiredValidator,
          postcodeValidator: _postcodeValidator,
          countryValidator: _countryValidator,
          cityValidator: _cityValidator,
        ),
        SizedBox(height: 16),
        if (_isCabDriverAccount)
          RegistrationSectionCard(
            title: 'Vehicle Information',
            child: Row(
              children: <Widget>[
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_taxi_rounded,
                    color: Color(0xFF22C55E),
                    size: 26,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AutoSizeText(
                        'Vehicle Type',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      AutoSizeText(
                        'Car (Rider Driver)',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
              ],
            ),
          )
        else
          VehicleInfoSection(
            selectedVehicleType: _selectedVehicleType,
            vehicleTypeOptions: AppLists.vehicleTypeOptions,
            onVehicleTypeChanged: (String? value) {
              setState(() {
                _selectedVehicleType = value;
                _drivingLicenceNumberController.clear();
                _clearAllDocumentSelections();
              });
            },
            needsLicence: needsLicence,
            isNorthernIreland: _isNorthernIreland(),
            drivingLicenceNumberController: _drivingLicenceNumberController,
            inputDecorationBuilder: _inputDecoration,
            ukDrivingLicenceFormattersBuilder: _ukDrivingLicenceFormatters,
            niDrivingLicenceFormattersBuilder: _niDrivingLicenceFormatters,
            vehicleTypeValidator: _vehicleTypeValidator,
            drivingLicenceNumberValidator: _drivingLicenceNumberValidator,
          ),
        const SizedBox(height: 16),
        if (_needsIdentityDocument())
          RegistrationSectionCard(
            title: _requiredIdentityDocumentTitle(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_requiredIdentityDocumentDescription().isNotEmpty)
                  Text(
                    _requiredIdentityDocumentDescription(),
                    style: const TextStyle(color: Colors.black54, height: 1.5),
                  ),
              ],
            ),
          ),
        if (_needsIdentityDocument()) const SizedBox(height: 16),
        if (_requiresDrivingLicenceFrontAndBack())
          _buildUploadCard(
            title: 'Driving Licence Front',
            emptyText: 'No driving licence front uploaded yet',
            image: _drivingLicenceFrontImage,
            isLoading: _isPickingDrivingLicenceFront,
            showError: _showDrivingLicenceFrontError,
            onPressed: (_isLoading || _isPickingDrivingLicenceFront)
                ? null
                : _pickDrivingLicenceFront,
          ),
        if (_requiresDrivingLicenceFrontAndBack()) const SizedBox(height: 16),
        if (_requiresDrivingLicenceFrontAndBack())
          _buildUploadCard(
            title: 'Driving Licence Back',
            emptyText: 'No driving licence back uploaded yet',
            image: _drivingLicenceBackImage,
            isLoading: _isPickingDrivingLicenceBack,
            showError: _showDrivingLicenceBackError,
            onPressed: (_isLoading || _isPickingDrivingLicenceBack)
                ? null
                : _pickDrivingLicenceBack,
          ),
        if (_requiresDrivingLicenceFrontAndBack()) const SizedBox(height: 16),
        if (_requiresPassportCopy())
          _buildUploadCard(
            title: 'Passport Copy',
            emptyText: 'No passport copy uploaded yet',
            image: _passportImage,
            isLoading: _isPickingPassport,
            showError: _showPassportError,
            onPressed: (_isLoading || _isPickingPassport) ? null : _pickPassportCopy,
          ),
        if (_requiresPassportCopy()) const SizedBox(height: 16),
        RegistrationSectionCard(
          title: 'Terms & Conditions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    activeColor: _goOutsBlue,
                    onChanged: (bool? value) {
                      setState(() {
                        _acceptedTerms = value ?? false;
                        if (_acceptedTerms) {
                          _showTermsError = false;
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        children: [
                          const Text('I agree to the '),
                          GestureDetector(
                            onTap: _openTermsAndConditions,
                            child: const Text(
                              'Terms & Conditions',
                              style: TextStyle(
                                color: _goOutsBlue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Text(' of GoOuts.'),
                        ],
                      ),
                    ),
                  ),
                  if (_acceptedTerms)
                    const Padding(
                      padding: EdgeInsets.only(top: 10, right: 6),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                ],
              ),
              if (_showTermsError)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'Please accept the Terms & Conditions to continue.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _hasRightToWork,
                    activeColor: _goOutsBlue,
                    onChanged: (bool? value) {
                      setState(() {
                        _hasRightToWork = value ?? false;
                        if (_hasRightToWork) {
                          _showRightToWorkError = false;
                        }
                      });
                    },
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Do you have the right to work in the UK & NI?'),
                    ),
                  ),
                  if (_hasRightToWork)
                    Padding(
                      padding: EdgeInsets.only(top: 10, right: 6),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                ],
              ),
              if (_showRightToWorkError)
                Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'Please confirm your right to work before continuing.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _goOutsBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : AutoSizeText(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already registered? ',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0392CA),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => showPreAuthSupportSheet(
              context,
              accountType: _isBusinessAccount ? 'business' : 'driver',
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
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AutoSizeText(
          'Complete Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
          child: _isBusinessAccount
              ? _buildBusinessRegistrationBody()
              : _buildDriverRegistrationBody(),
        ),
      ),
    );
  }
}

class ReferralDefaults {
  static const String driverCode = 'GD100001';
  static const String businessCode = 'GB000001';
  static const String cabDriverCode = 'GC100001';
}
