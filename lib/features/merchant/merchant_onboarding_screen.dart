import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/utils/app_lists.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class MerchantOnboardingScreen extends StatefulWidget {
  const MerchantOnboardingScreen({super.key});

  @override
  State<MerchantOnboardingScreen> createState() =>
      _MerchantOnboardingScreenState();
}

class _MerchantOnboardingScreenState extends State<MerchantOnboardingScreen> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color _blue = Color(0xFF0392CA);
  static const Color _navy = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _bg = Color(0xFFF8FAFF);

  // ── Steps ──────────────────────────────────────────────────────────────────
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // ── Form keys ──────────────────────────────────────────────────────────────
  final _key1 = GlobalKey<FormState>();
  final _key2 = GlobalKey<FormState>();
  final _key3 = GlobalKey<FormState>();

  // ── Step 1 — Business Details ──────────────────────────────────────────────
  final _tradingName = TextEditingController();
  String _category = '';
  final _addressLine1 = TextEditingController();
  String _country = 'UNITED KINGDOM';
  String _city = '';
  final _postcode = TextEditingController();
  final _businessPhone = TextEditingController();

  // ── Step 2 — Owner Contact ──────────────────────────────────────────────────
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _ownerPhone = TextEditingController();

  // ── Step 3 — Deal Terms ────────────────────────────────────────────────────
  final _inStoreCashback = TextEditingController(text: '10');
  bool _acceptsDelivery = false;
  final _deliveryCashback = TextEditingController(text: '3');

  // Commission tier — set by restaurant type selection
  String _restaurantType = ''; // 'independent' | 'local_chain' | 'regional' | 'self_delivery'

  // Social Boost campaign settings
  bool _socialBoostOptIn = true;
  String _socialBoostDays = '30';  // campaign duration in days; '0' = no limit
  String _socialBoostLimit = '50'; // max customers per campaign; '0' = no limit

  // POS system question
  bool? _hasPosSystem;           // null = not answered, true/false = answered
  String _posSystemName = '';    // e.g. "Deliverect", "Lightspeed", "Epos Now"

  // Existing delivery platforms
  final List<String> _existingPlatforms = [];
  static const List<Map<String, dynamic>> _platformOptions = [
    {'id': 'uber_eats', 'label': 'Uber Eats', 'color': Color(0xFF06C167)},
    {'id': 'deliveroo',  'label': 'Deliveroo', 'color': Color(0xFF00CCBC)},
    {'id': 'just_eat',   'label': 'Just Eat',  'color': Color(0xFFFF8000)},
    {'id': 'none',       'label': 'None',       'color': Color(0xFF6B7280)},
  ];

  // ── Step 4 — Photo ─────────────────────────────────────────────────────────
  File? _businessPhoto;
  bool _uploadingPhoto = false;
  String? _photoUrl;

  // ── Step 5 — Submit ────────────────────────────────────────────────────────
  bool _agreementAccepted = false;
  bool _submitting = false;

  static const List<String> _categories = [
    'Restaurant',
    'Café / Coffee Shop',
    'Gym / Fitness',
    'Salon / Barber',
    'Bar / Pub',
    'Retail / Shop',
    'Nightclub / Venue',
    'Wellness / Spa',
    'Takeaway / Fast Food',
    'Hotel',
    'Entertainment',
    'Other',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _tradingName.dispose();
    _addressLine1.dispose();
    _postcode.dispose();
    _businessPhone.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _ownerPhone.dispose();
    _inStoreCashback.dispose();
    _deliveryCashback.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    if (_currentStep == 0 && !(_key1.currentState?.validate() ?? false)) return;
    if (_currentStep == 1 && !(_key2.currentState?.validate() ?? false)) return;
    if (_currentStep == 2) {
      if (!(_key3.currentState?.validate() ?? false)) return;
      if (_acceptsDelivery && _restaurantType.isEmpty) {
        _showSnack('Please select the restaurant type to set commission.');
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Photo picker ───────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() {
      _businessPhoto = File(picked.path);
      _photoUrl = null;
    });
  }

  Future<void> _uploadPhoto() async {
    if (_businessPhoto == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('merchant_applications/$uid/$ts.jpg');
      await ref.putFile(_businessPhoto!);
      _photoUrl = await ref.getDownloadURL();
    } catch (_) {
      _photoUrl = null;
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Commission helpers ─────────────────────────────────────────────────────
  double _commissionRate() {
    switch (_restaurantType) {
      case 'local_chain':   return 12.0;
      case 'regional':      return 10.0;
      case 'self_delivery': return 8.0;
      default:              return 15.0; // independent — 10% starter, then 15%
    }
  }

  double _starterRate() {
    if (_restaurantType == 'independent') return 10.0;
    return _commissionRate(); // chains start at their tier rate directly
  }

  String _tierName() {
    switch (_restaurantType) {
      case 'local_chain':   return 'Standard';
      case 'regional':      return 'Growth';
      case 'self_delivery': return 'Self-Delivery';
      default:              return 'Starter'; // upgrades after 90 days
    }
  }

  String _tierLabel() {
    switch (_restaurantType) {
      case 'local_chain':   return 'Local Chain — 12% commission';
      case 'regional':      return 'Regional — 10% commission';
      case 'self_delivery': return 'Self-Delivery — 8% (own drivers)';
      default:              return 'Independent — 10% (first 90 days) → 15%';
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_agreementAccepted) {
      _showSnack('Please accept the agreement to continue.');
      return;
    }
    setState(() => _submitting = true);

    try {
      // Upload photo first if selected but not yet uploaded
      if (_businessPhoto != null && _photoUrl == null) {
        await _uploadPhoto();
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Fetch driver name for referral tracking
      String driverName = '';
      String driverCode = '';
      try {
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .get();
        final d = driverDoc.data() ?? {};
        driverName = (d['fullName'] ?? '').toString().trim();
        driverCode = (d['ownReferralCode'] ?? d['referralCode'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
      } catch (_) {}

      final double inStore =
          double.tryParse(_inStoreCashback.text.trim()) ?? 10.0;
      final double deliveryCb =
          double.tryParse(_deliveryCashback.text.trim()) ?? 3.0;
      final double commRate  = _acceptsDelivery ? _commissionRate() : 0.0;
      final double startRate = _acceptsDelivery ? _starterRate()    : 0.0;

      final data = <String, dynamic>{
        // Business details
        'tradingName': _tradingName.text.trim(),
        'legalBusinessName': _tradingName.text.trim(),
        'category': _category,
        'addressLine1': _addressLine1.text.trim(),
        'country': _country,
        'city': _city,
        'postcode': _postcode.text.trim().toUpperCase(),
        'businessPhone': _businessPhone.text.trim(),

        // Owner
        'ownerName': _ownerName.text.trim(),
        'ownerEmail': _ownerEmail.text.trim().toLowerCase(),
        'ownerPhone': _ownerPhone.text.trim(),

        // In-store cashback
        'inStoreCashbackPercent': inStore,
        'cashbackPercent': inStore, // alias used by GoOuts consumer app

        // Delivery & commission
        'acceptsDelivery': _acceptsDelivery,
        'restaurantType': _acceptsDelivery ? _restaurantType : '',
        'commissionTier': _acceptsDelivery ? _tierName() : '',
        'commissionRate': commRate,          // ongoing rate (e.g. 15%)
        'starterCommissionRate': startRate,  // intro rate (e.g. 10% for 90 days)
        'commissionLabel': _acceptsDelivery ? _tierLabel() : '',
        'deliveryCashbackPercent': _acceptsDelivery ? deliveryCb : 0.0,
        'socialBoostOptIn': _acceptsDelivery && _socialBoostOptIn,
        'socialBoostCampaignDays':
            _acceptsDelivery && _socialBoostOptIn
                ? int.tryParse(_socialBoostDays) ?? 30
                : 0,
        'socialBoostCustomerLimit':
            _acceptsDelivery && _socialBoostOptIn
                ? int.tryParse(_socialBoostLimit) ?? 50
                : 0,
        // Legacy field kept for backward compat
        'gooutsCommissionPercent': commRate,

        // POS system (B2B partnership intelligence)
        'hasPosSystem': _hasPosSystem ?? false,
        'posSystemName': _hasPosSystem == true ? _posSystemName.trim() : '',
        'existingPlatforms': _existingPlatforms,

        // Photo
        if (_photoUrl != null) 'businessPhotoUrl': _photoUrl,

        // Referral
        'referredBy': user.uid,
        'referredByName': driverName,
        'referredByCode': driverCode,

        // Status & meta
        'status': 'PENDING',
        'accountType': 'merchant_application',
        'submittedAt': FieldValue.serverTimestamp(),
        'agreementAccepted': true,
        'agreementAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),

        // Points
        'pointsEnabled': true,
        'pointsRatePercent': 1.0,
      };

      await FirebaseFirestore.instance.collection('businesses').add(data);

      if (mounted) {
        _showSuccessSheet();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Submission failed: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    GoOutsSheet.warning(context, title: 'Attention', message: msg);
  }

  void _showSuccessSheet() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: _green, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Business submitted!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_tradingName.text.trim()} has been sent to the GoOuts team for review. '
              'You\'ll earn commission once they go live.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.pop(context); // go back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text(
          'Sign Up a Business',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: _back,
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _currentStep, total: _totalSteps),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _step1BusinessDetails(),
                _step2OwnerContact(),
                _step3DealTerms(),
                _step4Photo(),
                _step5ReviewSubmit(),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  // ── Step 1: Business Details ───────────────────────────────────────────────
  Widget _step1BusinessDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Form(
        key: _key1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(
              icon: Icons.store_rounded,
              color: _blue,
              title: 'Business Details',
              subtitle: 'Tell us about the venue you\'re signing up.',
            ),
            const SizedBox(height: 24),
            _label('Business / Trading Name *'),
            _field(
              controller: _tradingName,
              hint: 'e.g. Luigi\'s Pizza',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _label('Category *'),
            _dropdown(
              value: _category.isEmpty ? null : _category,
              hint: 'Select category',
              items: _categories,
              onChanged: (v) => setState(() => _category = v ?? ''),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Select a category' : null,
            ),
            const SizedBox(height: 16),
            _label('Address Line 1 *'),
            _field(
              controller: _addressLine1,
              hint: 'e.g. 45 High Street',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _label('City *'),
            _dropdown(
              value: _city.isEmpty ? null : _city,
              hint: 'Select city',
              items: AppLists.cityOptionsForCountry(_country),
              onChanged: (v) => setState(() => _city = v ?? ''),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Select a city' : null,
            ),
            const SizedBox(height: 16),
            _label('Postcode *'),
            _field(
              controller: _postcode,
              hint: 'e.g. E1 6RF',
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _label('Business Phone *'),
            _field(
              controller: _businessPhone,
              hint: 'e.g. 07700 900123',
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Owner Contact ─────────────────────────────────────────────────
  Widget _step2OwnerContact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Form(
        key: _key2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(
              icon: Icons.person_outline_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Owner / Contact',
              subtitle: 'Who should GoOuts contact about this business?',
            ),
            const SizedBox(height: 24),
            _label('Owner Full Name *'),
            _field(
              controller: _ownerName,
              hint: 'e.g. Marco Rossi',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _label('Owner Email *'),
            _field(
              controller: _ownerEmail,
              hint: 'e.g. marco@luigis.co.uk',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Owner Phone *'),
            _field(
              controller: _ownerPhone,
              hint: 'e.g. 07700 900456',
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _blue, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'GoOuts will send the owner login credentials to access the merchant portal once approved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _blue,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Deal Terms ────────────────────────────────────────────────────
  Widget _step3DealTerms() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Form(
        key: _key3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(
              icon: Icons.percent_rounded,
              color: _green,
              title: 'GoOuts Deal',
              subtitle:
                  'Agreed cashback rates and commission — set with the merchant.',
            ),
            const SizedBox(height: 24),

            // In-store cashback
            _sectionCard(
              icon: Icons.store_rounded,
              iconColor: _blue,
              title: 'In-Store Cashback',
              child: Column(
                children: [
                  _label('Cashback % offered to customers *'),
                  _percentField(
                    controller: _inStoreCashback,
                    hint: '10',
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null) return 'Enter a number';
                      if (n < 1 || n > 50) return 'Must be 1–50%';
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This % of the customer\'s spend is credited back to their GoOuts wallet.',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Online delivery toggle
            _sectionCard(
              icon: Icons.delivery_dining_rounded,
              iconColor: _amber,
              title: 'Online Delivery',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Accept GoOuts delivery orders?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: _acceptsDelivery,
                        onChanged: (v) =>
                            setState(() => _acceptsDelivery = v),
                        activeColor: _blue,
                      ),
                    ],
                  ),
                  if (_acceptsDelivery) ...[
                    const SizedBox(height: 20),

                    // ── Restaurant Type (determines commission tier) ──────────
                    const Text(
                      'Restaurant Type *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This sets the GoOuts commission tier for this restaurant.',
                      style: TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // Type tiles
                    _restaurantTypeTile(
                      type: 'independent',
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFF2563EB),
                      label: 'Independent',
                      sublabel: '1–2 locations',
                      badge: '15%',
                      badgeNote: '10% first 90 days',
                    ),
                    const SizedBox(height: 8),
                    _restaurantTypeTile(
                      type: 'local_chain',
                      icon: Icons.store_mall_directory_rounded,
                      color: const Color(0xFFD97706),
                      label: 'Local Chain',
                      sublabel: '3–15 branches',
                      badge: '12%',
                      badgeNote: 'from day 1',
                    ),
                    const SizedBox(height: 8),
                    _restaurantTypeTile(
                      type: 'regional',
                      icon: Icons.location_city_rounded,
                      color: const Color(0xFF7C3AED),
                      label: 'Regional Chain',
                      sublabel: '15+ branches — admin review',
                      badge: '10%',
                      badgeNote: 'negotiated',
                    ),
                    const SizedBox(height: 8),
                    _restaurantTypeTile(
                      type: 'self_delivery',
                      icon: Icons.directions_bike_rounded,
                      color: const Color(0xFF0D9488),
                      label: 'Self-Delivery',
                      sublabel: 'Restaurant uses own drivers',
                      badge: '8%',
                      badgeNote: 'platform fee only',
                    ),

                    // ── Commission summary card ──────────────────────────────
                    if (_restaurantType.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _commissionSummaryCard(),
                    ],

                    const SizedBox(height: 20),

                    // ── Delivery cashback ────────────────────────────────────
                    _label('Delivery cashback % offered to customers *'),
                    _percentField(
                      controller: _deliveryCashback,
                      hint: '3',
                      validator: (v) {
                        if (!_acceptsDelivery) return null;
                        final n = double.tryParse(v ?? '');
                        if (n == null) return 'Enter a number';
                        if (n < 0 || n > 30) return 'Must be 0–30%';
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This % of the food subtotal is credited to the customer\'s GoOuts wallet after delivery.',
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),

                    const SizedBox(height: 20),

                    // ── Social Boost opt-in ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: Color(0xFF7C3AED), size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Social Boost',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                              Switch(
                                value: _socialBoostOptIn,
                                onChanged: (v) =>
                                    setState(() => _socialBoostOptIn = v),
                                activeColor: const Color(0xFF7C3AED),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Customer pays full price → posts on Instagram → gets £2.99 delivery cashback to wallet. Cost split 50/50 with restaurant.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7C3AED),
                                height: 1.45),
                          ),
                          if (_socialBoostOptIn) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Social Boost runs as a campaign — not permanently on. Set limits below. The merchant can adjust these anytime from their portal.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            // Duration limit
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Initial campaign duration',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary),
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: _socialBoostDays,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C3AED)),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '7', child: Text('7 days')),
                                    DropdownMenuItem(
                                        value: '14', child: Text('14 days')),
                                    DropdownMenuItem(
                                        value: '30', child: Text('30 days')),
                                    DropdownMenuItem(
                                        value: '0', child: Text('No limit')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _socialBoostDays = v ?? '30'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Customer limit
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Max customers per campaign',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary),
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: _socialBoostLimit,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C3AED)),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '25',
                                        child: Text('25 customers')),
                                    DropdownMenuItem(
                                        value: '50',
                                        child: Text('50 customers')),
                                    DropdownMenuItem(
                                        value: '100',
                                        child: Text('100 customers')),
                                    DropdownMenuItem(
                                        value: '0',
                                        child: Text('No limit')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _socialBoostLimit = v ?? '50'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Campaign runs for ${_socialBoostDays == '0' ? 'unlimited time' : '$_socialBoostDays days'} · '
                                'Stops after ${_socialBoostLimit == '0' ? 'unlimited customers' : '$_socialBoostLimit customers claim it'}. '
                                'Merchant controls it from their portal anytime.',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7C3AED),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // POS system question
            _sectionCard(
              icon: Icons.point_of_sale_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: 'POS System',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Do you currently use an all-in-one POS system that manages your Deliveroo or Uber Eats orders?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'e.g. Deliverect, Lightspeed, Epos Now, Square, Clover',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _posChoiceChip('Yes', true),
                      const SizedBox(width: 10),
                      _posChoiceChip('No', false),
                    ],
                  ),
                  if (_hasPosSystem == true) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: _posSystemName,
                      onChanged: (v) => _posSystemName = v,
                      decoration: InputDecoration(
                        labelText: 'Which POS system?',
                        hintText: 'e.g. Deliverect, Lightspeed, Epos Now',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFF7C3AED), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Great! GoOuts is working on a direct integration with leading POS providers so your GoOuts orders appear automatically.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF7C3AED)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_hasPosSystem == false) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: _green.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: _green, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No problem. The GoOuts Merchant Terminal tablet handles all your orders.',
                              style: TextStyle(fontSize: 12, color: _green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Existing delivery platforms ──────────────────────────────────
            _sectionCard(
              icon: Icons.delivery_dining_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Already on a Delivery Platform?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Is this business currently active on any of these platforms?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select all that apply. This helps us understand their delivery experience.',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _platformOptions.map((p) {
                      final id = p['id'] as String;
                      final label = p['label'] as String;
                      final color = p['color'] as Color;
                      final selected = _existingPlatforms.contains(id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (id == 'none') {
                              _existingPlatforms.clear();
                              _existingPlatforms.add('none');
                            } else {
                              _existingPlatforms.remove('none');
                              if (selected) {
                                _existingPlatforms.remove(id);
                              } else {
                                _existingPlatforms.add(id);
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? color.withOpacity(0.12) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : _border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected)
                                Icon(Icons.check_circle_rounded, color: color, size: 16)
                              else
                                Icon(Icons.radio_button_unchecked_rounded, color: _border, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? color : _textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Restaurant type tile ───────────────────────────────────────────────────
  Widget _restaurantTypeTile({
    required String type,
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required String badge,
    required String badgeNote,
  }) {
    final selected = _restaurantType == type;
    return GestureDetector(
      onTap: () => setState(() => _restaurantType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : _textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                        fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badgeNote,
                  style: TextStyle(
                      fontSize: 10,
                      color: selected ? color : _textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? color : _border,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Commission summary card ────────────────────────────────────────────────
  Widget _commissionSummaryCard() {
    const double sampleOrder = 25.0;
    final double rate = _commissionRate();
    final double starter = _starterRate();
    final double commission = sampleOrder * rate / 100;
    final double restaurantGets = sampleOrder - commission;
    final double deliverooGets = sampleOrder * 0.30;
    final double restaurantOnDeliveroo = sampleOrder - deliverooGets;
    final double saving = restaurantGets - restaurantOnDeliveroo;

    Color cardColor;
    switch (_restaurantType) {
      case 'local_chain':   cardColor = const Color(0xFFD97706); break;
      case 'regional':      cardColor = const Color(0xFF7C3AED); break;
      case 'self_delivery': cardColor = const Color(0xFF0D9488); break;
      default:              cardColor = const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_rounded, color: cardColor, size: 16),
              const SizedBox(width: 6),
              Text(
                'Commission Agreement — ${_tierLabel()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cardColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // On a £25 order breakdown
          Row(
            children: [
              Expanded(
                child: _commCell('GoOuts takes',
                    '-£${commission.toStringAsFixed(2)}',
                    Colors.red.shade700),
              ),
              Expanded(
                child: _commCell('Restaurant keeps',
                    '£${restaurantGets.toStringAsFixed(2)}',
                    Colors.green.shade700),
              ),
              Expanded(
                child: _commCell('vs Deliveroo 30%',
                    '+£${saving.toStringAsFixed(2)} more',
                    cardColor),
              ),
            ],
          ),

          if (_restaurantType == 'independent') ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: cardColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Starts at ${starter.toStringAsFixed(0)}% for first 90 days, then moves to ${rate.toStringAsFixed(0)}%. Auto-upgrades to 12% at 50+ orders/day.',
                      style: TextStyle(
                          fontSize: 11, color: cardColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_restaurantType == 'regional') ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: Color(0xFF7C3AED)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Regional chains require admin approval before going live. Rate may be adjusted by the GoOuts team.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C3AED),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),
          Text(
            '* All figures based on £${sampleOrder.toStringAsFixed(0)} food subtotal. Delivery fee (£2.99) is separate and goes to the driver.',
            style: TextStyle(
                fontSize: 10,
                color: cardColor.withOpacity(0.7),
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _commCell(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style:
              const TextStyle(fontSize: 10, color: _textSecondary),
        ),
      ],
    );
  }

  Widget _posChoiceChip(String label, bool value) {
    final selected = _hasPosSystem == value;
    return GestureDetector(
      onTap: () => setState(() => _hasPosSystem = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7C3AED).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF7C3AED)
                : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? const Color(0xFF7C3AED) : _textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Step 4: Business Photo ─────────────────────────────────────────────────
  Widget _step4Photo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            icon: Icons.photo_camera_rounded,
            color: _amber,
            title: 'Business Photo',
            subtitle:
                'Take a clear photo of the business front. Helps GoOuts verify the location.',
          ),
          const SizedBox(height: 24),

          if (_businessPhoto == null)
            GestureDetector(
              onTap: () => _showPhotoOptions(),
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _border, width: 1.5, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: _amber, size: 30),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Add business photo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Camera or gallery',
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    _businessPhoto!,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() {
                          _businessPhoto = null;
                          _photoUrl = null;
                        }),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          if (_businessPhoto != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showPhotoOptions,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Change photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _amber.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: _amber, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Photo is optional but recommended. A clear shopfront photo speeds up admin approval.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _amber,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _blue),
              title: const Text('Take a photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _blue),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Step 5: Review & Submit ────────────────────────────────────────────────
  Widget _step5ReviewSubmit() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            icon: Icons.checklist_rounded,
            color: _navy,
            title: 'Review & Submit',
            subtitle: 'Check everything is correct before submitting.',
          ),
          const SizedBox(height: 24),

          // Summary card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                _reviewSection('Business', [
                  _reviewRow('Name', _tradingName.text.trim()),
                  _reviewRow('Category', _category),
                  _reviewRow('Address',
                      '${_addressLine1.text.trim()}, ${_city.isNotEmpty ? _city : '—'}, ${_postcode.text.trim().toUpperCase()}'),
                  _reviewRow('Phone', _businessPhone.text.trim()),
                ]),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _reviewSection('Owner', [
                  _reviewRow('Name', _ownerName.text.trim()),
                  _reviewRow('Email', _ownerEmail.text.trim()),
                  _reviewRow('Phone', _ownerPhone.text.trim()),
                ]),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _reviewSection('Deal Terms', [
                  _reviewRow(
                      'In-store cashback', '${_inStoreCashback.text.trim()}%'),
                  _reviewRow('Accepts delivery',
                      _acceptsDelivery ? 'Yes' : 'No'),
                  if (_acceptsDelivery) ...[
                    _reviewRow('Restaurant type',
                        _restaurantType.replaceAll('_', ' ').toUpperCase()),
                    _reviewRow('Commission tier', _tierLabel()),
                    _reviewRow('GoOuts commission',
                        '${_commissionRate().toStringAsFixed(0)}%${_restaurantType == 'independent' ? ' (10% first 90 days)' : ''}'),
                    _reviewRow('Delivery cashback',
                        '${_deliveryCashback.text.trim()}% (food subtotal)'),
                    _reviewRow(
                        'Social Boost',
                        _socialBoostOptIn
                            ? 'Opted in — ${_socialBoostDays == '0' ? 'no time limit' : '$_socialBoostDays days'} · max ${_socialBoostLimit == '0' ? 'unlimited' : '$_socialBoostLimit'} customers'
                            : 'Not opted in'),
                  ],
                  _reviewRow('Points earning', '1% of spend'),
                  _reviewRow('Has POS system',
                      _hasPosSystem == null ? 'Not answered' : (_hasPosSystem! ? 'Yes' : 'No')),
                  if (_hasPosSystem == true && _posSystemName.trim().isNotEmpty)
                    _reviewRow('POS provider', _posSystemName.trim()),
                  _reviewRow('Delivery platforms', _existingPlatforms.isEmpty
                      ? '—'
                      : _existingPlatforms.map((id) {
                          final match = _platformOptions.firstWhere(
                              (p) => p['id'] == id,
                              orElse: () => {'label': id});
                          return match['label'] as String;
                        }).join(', ')),
                ]),
                if (_businessPhoto != null) ...[
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _businessPhoto!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Business photo attached',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Agreement
          GestureDetector(
            onTap: () =>
                setState(() => _agreementAccepted = !_agreementAccepted),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _agreementAccepted
                    ? _green.withOpacity(0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreementAccepted
                      ? _green.withOpacity(0.4)
                      : _border,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _agreementAccepted ? _green : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _agreementAccepted ? _green : _border,
                        width: 1.5,
                      ),
                    ),
                    child: _agreementAccepted
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'I confirm I have spoken with the business owner and they have agreed to join GoOuts on the terms shown above. I have authority to submit this application on their behalf.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: _textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _reviewSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _bottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : isLast
                      ? _submit
                      : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? _green : _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _blue.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isLast ? 'Submit Application' : 'Next',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _stepHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _percentField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: validator,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
        suffixText: '%',
        suffixStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: _blue),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  static const List<String> _labels = [
    'Business',
    'Owner',
    'Commission',
    'Photo',
    'Submit',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        children: [
          Row(
            children: List.generate(total, (i) {
              final done = i < current;
              final active = i == current;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        decoration: BoxDecoration(
                          color: done || active
                              ? const Color(0xFF0392CA)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < total - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${current + 1} of $total',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _labels[current],
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0392CA),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
