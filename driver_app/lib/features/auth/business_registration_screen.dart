import 'dart:io';
import '../../services/address_lookup_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/business_home_screen.dart';
import '../legal/terms_and_conditions_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({
    super.key,
    required this.referralCode,
    required this.inviteToken,
  });

  final String referralCode;
  final String inviteToken;

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _successGreen = Color(0xFF16A34A);
  static const String _termsUrl = 'https://example.com/goouts-terms';
  static const String _defaultBusinessReferralCode = 'GB000001';
  static const String _defaultCountry = 'UNITED KINGDOM';
  static const String _northernIrelandCountry = 'NORTHERN IRELAND';
  static const String _mapboxPublicToken =
      'pk.eyJ1IjoibWlhbmFtaXI3NCIsImEiOiJjbW44aGp1bTYwYzVrMnBxcnRvYzA5bG40In0.2thWcmSMupWuGVNKJmfQyg';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AddressLookupService _addressService = AddressLookupService();
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _prefixOptions = <String>['Mr', 'Mrs', 'Miss', 'Ms', 'Dr'];
  final List<String> _countryOptions = <String>[
    _defaultCountry,
    _northernIrelandCountry,
  ];
  final Map<String, List<String>> _cityOptionsByCountry =
      <String, List<String>>{
    _defaultCountry: <String>[
      'London',
      'Manchester',
      'Birmingham',
      'Liverpool',
      'Leeds',
      'Bristol',
      'Sheffield',
      'Nottingham',
      'Leicester',
      'Coventry',
      'Bradford',
      'Newcastle',
      'Oxford',
      'Cambridge',
      'Southampton',
      'Portsmouth',
      'Reading',
      'Luton',
      'Milton Keynes',
      'Derby',
    ],
    _northernIrelandCountry: <String>[
      'Belfast',
      'Derry',
      'Lisburn',
      'Newry',
      'Bangor',
      'Craigavon',
      'Newtownabbey',
      'Carrickfergus',
      'Antrim',
      'Coleraine',
      'Omagh',
      'Enniskillen',
      'Armagh',
      'Dungannon',
      'Ballymena',
      'Larne',
    ],
  };

  String? _selectedPrefix;
  String? _selectedCountry;
  String? _selectedCity;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();
  final TextEditingController _legalBusinessNameController =
      TextEditingController();
  final TextEditingController _companyNumberController =
      TextEditingController();
  final TextEditingController _shopUnitNoController = TextEditingController();
  final TextEditingController _roadNameController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _isLoading = false;
  bool _isPickingSelfie = false;
  bool _showSelfieError = false;
  bool _isPostcodeVerified = false;
  bool _isConfirmingPostcode = false;
  bool _isUpdatingPostcodeProgrammatically = false;

  // ── Smart Hybrid verified data (May 2026) ──
  String _verifiedUprn = '';
  String _verifiedFullAddress = '';
  double? _verifiedLatitude;
  double? _verifiedLongitude;
  // Locked only when address was actually auto-filled from OS bottom sheet.
  bool _addressFieldsLocked = false;
  List<MapboxAddressResult> _addressSuggestions = [];

  XFile? _selfieImage;

  @override
  void initState() {
    super.initState();
    _selectedPrefix = _prefixOptions.first;
    _selectedCountry = _countryOptions.first;
    _postcodeController.addListener(_handlePostcodeEdited);
    _pinFocusNode.addListener(() => setState(() {}));
    _confirmPinFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _postcodeController.removeListener(_handlePostcodeEdited);
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _legalBusinessNameController.dispose();
    _companyNumberController.dispose();
    _shopUnitNoController.dispose();
    _roadNameController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  List<String> _cityOptionsForSelectedCountry() {
    return _cityOptionsByCountry[_selectedCountry] ?? <String>[];
  }

  void _handlePostcodeEdited() {
    if (_isUpdatingPostcodeProgrammatically) {
      return;
    }

    final String rawPostcode = _postcodeController.text.trim();
    final String inferredCountry = rawPostcode.isEmpty
        ? _countryOptions.first
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
  }

  String _normalizeUkPostcode(String input) {
    final String cleaned =
        input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length <= 3) {
      return cleaned;
    }
    return '${cleaned.substring(0, cleaned.length - 3)} ${cleaned.substring(cleaned.length - 3)}';
  }

  String? _postcodeValidatorLocal(String? value) {
    final String normalized = _normalizeUkPostcode(value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Postcode is required';
    }
    final RegExp regex =
        RegExp(r'^[A-Z]{1,2}[0-9][A-Z0-9]?\s?[0-9][A-Z]{2}$');
    if (!regex.hasMatch(normalized)) {
      return 'Enter a valid UK postcode';
    }
    return null;
  }

  String _normalizedPostcode() => _normalizeUkPostcode(_postcodeController.text);

  String _inferCountryFromPostcode(String postcode) {
    final String normalized = _normalizeUkPostcode(postcode).replaceAll(' ', '');
    if (normalized.startsWith('BT')) {
      return _northernIrelandCountry;
    }
    return _defaultCountry;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _readMapString(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _readContextName(Map<String, dynamic> context, String key) {
    final dynamic value = context[key];
    if (value is Map) {
      final Map<String, dynamic> valueMap = Map<String, dynamic>.from(value);
      final String name = _readMapString(valueMap, 'name');
      if (name.isNotEmpty) {
        return name;
      }
    }
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final String value in values) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _normalizeForMatching(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String? _matchCityOption(String? rawCity, List<String> options) {
    final String input = _normalizeForMatching(rawCity ?? '');
    if (input.isEmpty) {
      return null;
    }
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

  String _extractCityFromPostcodeFeature(
    Map<String, dynamic> feature,
    List<String> cityOptions,
  ) {
    final Map<String, dynamic> properties = _asMap(feature['properties']);
    final Map<String, dynamic> context = _asMap(properties['context']);

    final String candidate = _firstNonEmpty(<String>[
      _readContextName(context, 'place'),
      _readContextName(context, 'locality'),
      _readContextName(context, 'district'),
      _readMapString(properties, 'name'),
    ]);

    final String? matched = _matchCityOption(candidate, cityOptions);
    return matched ?? '';
  }

  void _showSnackBarMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showTermsRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Required Confirmation'),
          content: const Text(
            'Please accept Terms & Conditions before continuing.',
          ),
          actions: <Widget>[
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

      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (!mounted) {
        return;
      }

      if (pickedImage != null) {
        setState(() {
          _selfieImage = pickedImage;
          _showSelfieError = false;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Selfie Error'),
            content: Text('Failed to capture selfie.\n\n$e'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPickingSelfie = false;
      });
    }
  }

  Future<String> _uploadSelfie({
    required String uid,
    required XFile selfieImage,
  }) async {
    final Reference ref = FirebaseStorage.instance
        .ref()
        .child('businesses')
        .child('selfies')
        .child('$uid.jpg');
    await ref.putFile(File(selfieImage.path));
    return ref.getDownloadURL();
  }

  /// Smart Hybrid Address Lookup (May 2026).
  ///
  /// Two-Step Professional flow:
  ///   1. Validate postcode
  ///   2. Fetch all OS addresses for the postcode
  ///   3. Show a bottom sheet for the owner to pick the correct one
  ///   4. Show a brief "Verifying with Official Address Register..." overlay
  ///   5. Fill the form and lock the fields with UPRN + lat/lng captured
  /// Links an email+password credential to the current Firebase phone-auth
  /// account so returning users can sign in with password instead of SMS OTP.
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

  Future<void> _confirmPostcode() async {
    FocusScope.of(context).unfocus();

    final String? postcodeError =
        _postcodeValidatorLocal(_postcodeController.text);
    if (postcodeError != null) {
      setState(() {
        _isPostcodeVerified = false;
      });
      _showSnackBarMessage('Please enter a valid postcode before continuing.');
      return;
    }

    final String postcode = _normalizedPostcode();
    _isUpdatingPostcodeProgrammatically = true;
    _postcodeController.text = postcode;
    _postcodeController.selection = TextSelection.collapsed(
      offset: _postcodeController.text.length,
    );
    _isUpdatingPostcodeProgrammatically = false;

    setState(() {
      _isConfirmingPostcode = true;
    });

    try {
      // ── Step 1: Fetch all OS addresses for this postcode ────────────
      final List<OsAddressResult> osResults =
          await _addressService.findAddressesAtPostcode(postcode);

      if (!mounted) return;

      // ── No OS results — fall back to Mapbox only for NI postcodes ───
      if (osResults.isEmpty) {
        final bool isNI =
            AddressLookupService.isNorthernIrelandPostcode(postcode);

        if (!isNI) {
          // Non-NI postcode with no OS data — show clear error so the owner
          // can re-type or use the "Enter manually" link.
          setState(() {
            _isConfirmingPostcode = false;
            _isPostcodeVerified = false;
            _addressFieldsLocked = false;
          });
          _showSnackBarMessage(
            'No addresses found for this postcode. Please check it, or tap "Enter manually" below.',
          );
          return;
        }

        // Northern Ireland (BT) — Mapbox fallback.
        final MapboxAddressResult? mapbox =
            await _addressService.findFromMapbox(postcode);

        if (!mounted) return;

        if (mapbox == null) {
          setState(() {
            _isConfirmingPostcode = false;
            _isPostcodeVerified = false;
            _addressFieldsLocked = false;
          });
          _showSnackBarMessage(
            'Postcode not found. Please check it or tap "Enter manually" below.',
          );
          return;
        }

        final String resolvedCountry = _inferCountryFromPostcode(postcode);
        final List<String> cityOptions =
            _cityOptionsByCountry[resolvedCountry] ?? <String>[];
        final String? matchedCity = mapbox.city.isNotEmpty
            ? _matchCityOption(mapbox.city, cityOptions)
            : null;

        setState(() {
          _isConfirmingPostcode = false;
          _selectedCountry = resolvedCountry;
          _selectedCity = matchedCity;
          _verifiedUprn = '';
          _verifiedFullAddress = mapbox.fullAddress;
          _verifiedLatitude = mapbox.latitude;
          _verifiedLongitude = mapbox.longitude;
          _isPostcodeVerified = true;
          _addressFieldsLocked = false; // owner types address manually
        });

        _showSnackBarMessage(
          'Postcode verified (Northern Ireland). Please type your shop number and road name.',
        );
        return;
      }

      // ── OS path: show bottom sheet for the owner to pick ─────────────
      setState(() {
        _isConfirmingPostcode = false;
      });

      final OsAddressResult? selected =
          await _showAddressPickerBottomSheet(osResults);

      if (!mounted || selected == null) return;

      // ── Brief verification overlay (UPRN trust UX) ─────────────────
      setState(() {
        _isConfirmingPostcode = true;
      });
      await _showVerifyingOverlay();
      if (!mounted) return;

      // ── Fill form fields with the verified address ──────────────────
      final String resolvedCountry = _inferCountryFromPostcode(postcode);
      final List<String> cityOptions =
          _cityOptionsByCountry[resolvedCountry] ?? <String>[];
      final String? matchedCity =
          _matchCityOption(selected.postTown, cityOptions);

      if (selected.thoroughfareName.isNotEmpty) {
        _roadNameController.text = selected.thoroughfareName;
      }
      if (selected.resolvedBuildingRef.isNotEmpty) {
        _shopUnitNoController.text = selected.resolvedBuildingRef;
      }

      setState(() {
        _isConfirmingPostcode = false;
        _selectedCountry = resolvedCountry;
        _selectedCity = matchedCity;
        _verifiedUprn = selected.uprn;
        _verifiedFullAddress = selected.fullAddress;
        _verifiedLatitude = selected.latitude;
        _verifiedLongitude = selected.longitude;
        _isPostcodeVerified = true;
        _addressFieldsLocked = true; // OS auto-filled — lock the fields
      });

      _showSnackBarMessage('Address verified with Ordnance Survey.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirmingPostcode = false;
        _isPostcodeVerified = false;
      });
      _showSnackBarMessage(
        'We could not verify this postcode right now. Please try again.',
      );
    }
  }

  /// Bottom sheet listing every OS address at the postcode.
  Future<OsAddressResult?> _showAddressPickerBottomSheet(
    List<OsAddressResult> addresses,
  ) async {
    return showModalBottomSheet<OsAddressResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext sheetCtx, ScrollController scrollController) {
            return Column(
              children: <Widget>[
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.place_rounded,
                          color: _goOutsBlue, size: 26),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AutoSizeText(
                              'Select Your Address',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            AutoSizeText(
                              '${addresses.length} address${addresses.length == 1 ? '' : 'es'} found at ${_postcodeController.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, indent: 16),
                    itemBuilder: (BuildContext itemCtx, int idx) {
                      final OsAddressResult addr = addresses[idx];
                      final String displayLine = addr.fullAddress.isNotEmpty
                          ? addr.fullAddress
                          : '${addr.resolvedBuildingRef} ${addr.thoroughfareName}'
                              .trim();
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Icon(Icons.storefront_outlined,
                            color: _goOutsBlue),
                        title: AutoSizeText(
                          displayLine.isEmpty ? addr.postcode : displayLine,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.grey),
                        onTap: () => Navigator.of(sheetCtx).pop(addr),
                      );
                    },
                  ),
                ),
                Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextButton.icon(
                    icon: Icon(Icons.edit_rounded, size: 18),
                    label: const Text('My address is not in this list'),
                    onPressed: () => Navigator.of(sheetCtx).pop(null),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Brief "Verifying with Official Address Register..." overlay.
  Future<void> _showVerifyingOverlay() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.verified_rounded, size: 56, color: _goOutsBlue),
                SizedBox(height: 12),
                AutoSizeText(
                  'Verifying Address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                AutoSizeText(
                  'with Official Address Register',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: _goOutsBlue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Called when the owner taps an address from the postcode dropdown (Mapbox path).
  void _onAddressSelected(MapboxAddressResult address) {
    final String resolvedCountry = _inferCountryFromPostcode(address.postcode);
    final List<String> cityOptions =
        _cityOptionsByCountry[resolvedCountry] ?? <String>[];
    final String? inferredCity = AddressLookupService.inferCityFromPostcode(address.postcode);
    final String? matchedCity = inferredCity != null
        ? _matchCityOption(inferredCity, cityOptions)
        : (address.city.isNotEmpty ? _matchCityOption(address.city, cityOptions) : null);
    setState(() {
      _postcodeController.text   = address.postcode;
      _shopUnitNoController.text  = address.houseNumber ?? '';
      _roadNameController.text    = address.street ?? '';
      _townController.text       = (address.town ?? address.city).toUpperCase();
      _selectedCountry           = resolvedCountry;
      _selectedCity              = matchedCity;
      _verifiedFullAddress       = address.fullAddress;
      _verifiedLatitude          = address.latitude;
      _verifiedLongitude         = address.longitude;
      _isPostcodeVerified        = true;
      _addressFieldsLocked       = false;
      _addressSuggestions        = [];
    });
  }

  /// Tapped when the owner picks "Edit manually". Clears verified state.
  void _handleEditManually() {
    setState(() {
      _isPostcodeVerified = false;
      _verifiedUprn = '';
      _verifiedFullAddress = '';
      _verifiedLatitude = null;
      _verifiedLongitude = null;
      _addressFieldsLocked = false;
    });
    _showSnackBarMessage(
      'Address fields are now editable. Re-tap "Find Official Address" to re-verify.',
    );
  }

    String _normalizeInviteToken(String inviteToken) {
    return inviteToken.trim().toUpperCase();
  }

  String _normalizeReferralCode(String referralCode) {
    final String cleaned = referralCode.trim().toUpperCase();
    if (cleaned.isEmpty || !cleaned.startsWith('GB')) {
      return _defaultBusinessReferralCode;
    }
    return cleaned;
  }

  String _titleCase(String value) {
    if (value.trim().isEmpty) {
      return '';
    }
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .map((String word) {
          if (word.isEmpty) {
            return word;
          }
          final String lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  String _generateBusinessReferralCode(String uid) {
    final String cleaned =
        uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) {
      return _defaultBusinessReferralCode;
    }
    if (cleaned.length >= 6) {
      return 'GB${cleaned.substring(cleaned.length - 6)}';
    }
    return 'GB${cleaned.padLeft(6, '0')}';
  }

  bool _hasText(TextEditingController controller) {
    return controller.text.trim().isNotEmpty;
  }

  bool get _isPrefixComplete => (_selectedPrefix ?? '').trim().isNotEmpty;

  bool get _isFirstNameComplete => _firstNameController.text.trim().length >= 2;

  bool get _isSurnameComplete => _surnameController.text.trim().length >= 2;

  bool get _isEmailComplete {
    final String email = _emailController.text.trim();
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  bool get _isConfirmEmailComplete {
    final String email = _emailController.text.trim();
    final String confirmEmail = _confirmEmailController.text.trim();
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email) && confirmEmail == email;
  }

  bool get _isPinComplete {
    final String pin = _pinController.text;
    return pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);
  }

  bool get _isConfirmPinComplete {
    return _isPinComplete && _confirmPinController.text == _pinController.text;
  }

  bool get _isBusinessNameComplete =>
      _legalBusinessNameController.text.trim().length >= 2;

  bool get _isCompanyNumberComplete {
    final String value = _companyNumberController.text.trim().toUpperCase();
    final RegExp companyNumberRegex = RegExp(
      r'^(?:\d{8}|SC\d{6}|NI\d{6})$',
      caseSensitive: false,
    );
    return companyNumberRegex.hasMatch(value);
  }

  bool get _isShopUnitComplete => _hasText(_shopUnitNoController);
  bool get _isRoadNameComplete => _roadNameController.text.trim().length >= 2;
  bool get _isCountryComplete => (_selectedCountry ?? '').trim().isNotEmpty;
  bool get _isCityComplete => (_selectedCity ?? '').trim().isNotEmpty;
  bool get _isTermsComplete => _acceptedTerms;
  bool get _isSelfieComplete => _selfieImage != null;

  Widget _successIcon(bool show) {
    if (!show) {
      return const SizedBox.shrink();
    }
    return const Icon(
      Icons.verified_rounded,
      color: _successGreen,
      size: 20,
    );
  }

  Future<void> _submitBusinessForm() async {
    FocusScope.of(context).unfocus();

    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      _showSnackBarMessage(
        'Please complete all required fields before continuing.',
      );
      return;
    }

    if (!_isPostcodeVerified) {
      _showSnackBarMessage('Please confirm your postcode before continuing.');
      return;
    }

    if (_selectedCountry == null || _selectedCountry!.trim().isEmpty) {
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
            actions: <Widget>[
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

    final String inviteToken = _normalizeInviteToken(widget.inviteToken);
    final String normalizedReferralCode =
        _normalizeReferralCode(widget.referralCode);

    setState(() {
      _isLoading = true;
    });

    try {
      final String profilePhotoUrl = await _uploadSelfie(
        uid: currentUser.uid,
        selfieImage: _selfieImage!,
      );

      final DateTime now = DateTime.now();
      final String firstName = _firstNameController.text.trim();
      final String surname = _surnameController.text.trim();
      final String fullName = _titleCase('$firstName $surname'.trim());
      final String ownReferralCode =
          _generateBusinessReferralCode(currentUser.uid);

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
        'shopUnitNo': _shopUnitNoController.text.trim(),
        'roadName': _roadNameController.text.trim(),
        'termsAccepted': true,
        'status': 'PENDING',
        'registrationCompleted': true,
        'referralCodeUsed': normalizedReferralCode,
        'inviteTokenUsed': inviteToken,
        'ownReferralCode': ownReferralCode,
        'referralCode': ownReferralCode,
        'profilePhotoUrl': profilePhotoUrl,
        'selfieUrl': profilePhotoUrl,
        'businessProfileVerificationStatus': 'submitted',
        'businessProfileVerificationBackendStatus': 'submitted',
        'businessProfileVerificationSubmittedAt': FieldValue.serverTimestamp(),
        'businessProfileVerificationLastUpdatedAt':
            FieldValue.serverTimestamp(),
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

      if (!mounted) {
        return;
      }

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
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const BusinessHomeScreen(),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save business registration.\n\n$e'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _goOutsBlue, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  InputDecoration _completedInputDecoration({
    required String label,
    required bool complete,
    String? hint,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return _inputDecoration(
      label: label,
      hint: hint,
      suffixIcon: suffixIcon ?? _successIcon(complete),
      helperText: helperText,
    );
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _companyNumberValidator(String? value) {
    final String input = value?.trim().toUpperCase() ?? '';
    if (input.isEmpty) return 'Company Registration No is required';
    final RegExp companyNumberRegex = RegExp(
      r'^(?:\d{8}|SC\d{6}|NI\d{6})$',
      caseSensitive: false,
    );
    if (!companyNumberRegex.hasMatch(input)) {
      return 'Enter a valid UK company number';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required';
    }
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _confirmEmailValidator(String? value) {
    final String confirmEmail = value?.trim() ?? '';
    if (confirmEmail.isEmpty) {
      return 'Confirm Email is required';
    }
    if (_emailValidator(_emailController.text) != null) {
      return 'Enter a valid email first';
    }
    if (confirmEmail != _emailController.text.trim()) {
      return 'Email addresses do not match';
    }
    return null;
  }

  String? _pinValidator(String? value) {
    if (value == null || value.isEmpty) return 'PIN is required';
    if (value.length < 4) return 'PIN must be 4 digits';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return 'PIN must contain digits only';
    return null;
  }

  String? _confirmPinValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your PIN';
    if (value != _pinController.text) return 'PINs do not match';
    return null;
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF1)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AutoSizeText(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 6),
          AutoSizeText(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> cityOptions = _cityOptionsForSelectedCountry();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Business Registration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: <Widget>[
              _buildSectionCard(
                title: 'Business Partner Details',
                subtitle: 'Complete your business registration details below.',
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: _selectedPrefix,
                    decoration: _completedInputDecoration(
                      label: 'Prefix',
                      complete: _isPrefixComplete,
                    ),
                    items: _prefixOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedPrefix = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: _completedInputDecoration(
                      label: 'First Name',
                      complete: _isFirstNameComplete,
                    ),
                    validator: (String? value) =>
                        _requiredValidator(value, 'First Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _surnameController,
                    decoration: _completedInputDecoration(
                      label: 'Surname',
                      complete: _isSurnameComplete,
                    ),
                    validator: (String? value) =>
                        _requiredValidator(value, 'Surname'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _completedInputDecoration(
                      label: 'Email',
                      complete: _isEmailComplete,
                    ),
                    validator: _emailValidator,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _completedInputDecoration(
                      label: 'Confirm Email',
                      complete: _isConfirmEmailComplete,
                    ),
                    validator: _confirmEmailValidator,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(letterSpacing: 10, fontSize: 18),
                    decoration: _completedInputDecoration(
                      label: '4-digit PIN',
                      complete: _isPinComplete,
                      helperText: 'You will use this PIN to log in',
                    ).copyWith(
                      counterText: '',
                      suffixIconConstraints: const BoxConstraints(
                        minHeight: 0,
                        minWidth: 0,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_isPinComplete &&
                              !_pinFocusNode.hasFocus)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    validator: _pinValidator,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPinController,
                    focusNode: _confirmPinFocusNode,
                    obscureText: _obscureConfirmPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(letterSpacing: 10, fontSize: 18),
                    decoration: _completedInputDecoration(
                      label: 'Confirm PIN',
                      complete: _isConfirmPinComplete,
                    ).copyWith(
                      counterText: '',
                      suffixIconConstraints: const BoxConstraints(
                        minHeight: 0,
                        minWidth: 0,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_isConfirmPinComplete &&
                              !_confirmPinFocusNode.hasFocus)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPin =
                                    !_obscureConfirmPin;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    validator: _confirmPinValidator,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _legalBusinessNameController,
                    decoration: _completedInputDecoration(
                      label: 'Legal Business Name',
                      complete: _isBusinessNameComplete,
                    ),
                    validator: (String? value) =>
                        _requiredValidator(value, 'Legal Business Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _companyNumberController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(8),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: _completedInputDecoration(
                      label: 'Company Registration No',
                      complete: _isCompanyNumberComplete,
                    ),
                    validator: (String? value) =>
                        _requiredValidator(value, 'Company Registration No'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'Business Address',
                subtitle:
                    'Type your postcode → tap "Find Official Address" → pick from the list.',
                children: <Widget>[
                  // ── Loading bar while OS lookup runs ───────────────────
                  if (_isConfirmingPostcode)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        color: _goOutsBlue,
                        backgroundColor: Color(0xFFE5F4FB),
                      ),
                    ),

                  // ── Postcode + Find button (side by side) ──────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _postcodeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9 ]')),
                            LengthLimitingTextInputFormatter(8),
                            UpperCaseTextFormatter(),
                          ],
                          decoration: _completedInputDecoration(
                            label: 'Postcode',
                            complete: _isPostcodeVerified,
                          ),
                          validator: _postcodeValidatorLocal,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 58,
                          child: ElevatedButton.icon(
                            onPressed: _isConfirmingPostcode
                                ? null
                                : _confirmPostcode,
                            icon: _isConfirmingPostcode
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
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
                              _isPostcodeVerified
                                  ? 'Verified'
                                  : 'Find Official Address',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isPostcodeVerified
                                  ? _successGreen
                                  : _goOutsBlue,
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
                  SizedBox(height: 8),

                  // ── Verified subtitle / Manual entry link ──────────────
                  if (_isPostcodeVerified)
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
                        TextButton(
                          onPressed: _isConfirmingPostcode
                              ? null
                              : _handleEditManually,
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
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
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isConfirmingPostcode
                            ? null
                            : _handleEditManually,
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

                  // ── Shop / Unit No (locked only when OS auto-filled) ───
                  TextFormField(
                    controller: _shopUnitNoController,
                    readOnly: _addressFieldsLocked,
                    decoration: _completedInputDecoration(
                      label: 'Shop/Unit No',
                      complete: _isShopUnitComplete,
                      helperText: _addressFieldsLocked
                          ? 'Auto-filled from official record'
                          : null,
                    ),
                    validator: (String? value) =>
                        _requiredValidator(value, 'Shop/Unit No'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // ── Road Name (locked only when OS auto-filled) ────────
                  TextFormField(
                    controller: _roadNameController,
                    readOnly: _addressFieldsLocked,
                    decoration: _completedInputDecoration(
                      label: 'Road Name',
                      complete: _isRoadNameComplete,
                      helperText: _addressFieldsLocked
                          ? 'Auto-filled from official record'
                          : null,
                    ),
                    validator: (String? value) =>
                        _requiredValidator(value, 'Road Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    decoration: _completedInputDecoration(
                      label: 'Country',
                      complete: _isCountryComplete,
                    ),
                    items: _countryOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
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
                    validator: (String? value) =>
                        _requiredValidator(value, 'Country'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cityOptions.contains(_selectedCity) ? _selectedCity : null,
                    decoration: _completedInputDecoration(
                      label: 'City',
                      complete: _isCityComplete,
                    ),
                    items: cityOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedCity = value;
                      });
                    },
                    validator: (String? value) => _requiredValidator(value, 'City'),
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'Selfie Verification',
                subtitle:
                    'Please capture a clear selfie for business profile verification.',
                children: <Widget>[
                  if (_selfieImage != null)
                    Container(
                      clipBehavior: Clip.antiAlias,
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: FileImage(File(_selfieImage!.path)),
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
                        color: const Color(0xFFF4FAFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _showSelfieError
                              ? Colors.red
                              : const Color(0xFFE6ECF1),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 38,
                            color: _goOutsBlue,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No selfie captured yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isPickingSelfie ? null : _pickSelfie,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _goOutsBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isPickingSelfie
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isSelfieComplete
                                  ? Icons.verified_rounded
                                  : Icons.camera_alt_rounded,
                            ),
                      label: Text(
                        _isPickingSelfie
                            ? 'Opening Camera...'
                            : _isSelfieComplete
                                ? 'Selfie Captured'
                                : 'Capture Selfie',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_showSelfieError) ...<Widget>[
                    SizedBox(height: 10),
                    AutoSizeText(
                      'Selfie is required.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              _buildSectionCard(
                title: 'Terms & Conditions',
                subtitle: 'You must accept the terms before continuing.',
                children: <Widget>[
                  CheckboxListTile(
                    value: _acceptedTerms,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? value) {
                      setState(() {
                        _acceptedTerms = value ?? false;
                        _showTermsError = false;
                      });
                    },
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        const Text('I accept the '),
                        GestureDetector(
                          onTap: _openTermsAndConditions,
                          child: const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              color: _goOutsBlue,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _successIcon(_isTermsComplete),
                      ],
                    ),
                  ),
                  if (_showTermsError)
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'You must accept Terms & Conditions.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitBusinessForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goOutsBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : AutoSizeText(
                          'Complete Business Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upperText = newValue.text.toUpperCase();
    return TextEditingValue(
      text: upperText,
      selection: TextSelection.collapsed(offset: upperText.length),
    );
  }
}
