import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _pageBackground = Color(0xFFF7FAFC);
  static const Color _cardBorder = Color(0xFFE6ECF1);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _fieldBackground = Colors.white;

  bool _isLoading = true;

  String _prefix = '';
  String _firstName = '';
  String _surname = '';
  String _email = '';
  String _legalBusinessName = '';
  String _companyNumber = '';
  String _houseNoOrName = '';
  String _streetName = '';
  String _postcode = '';
  String _city = '';
  String _country = '';
  String _profilePhotoUrl = '';
  String _referralCode = 'BG0001';
  bool _isVerified = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _user;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('businesses')
          .doc(user.uid)
          .get();

      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

      _prefix = _readString(data, ['prefix']);
      _firstName = _readString(data, ['firstName']);
      _surname = _readString(data, ['surname']);
      _email = _readString(data, ['email']);
      _legalBusinessName = _readString(data, ['legalBusinessName']);
      _companyNumber = _readString(data, ['companyNumber']);
      _houseNoOrName = _readString(
        data,
        ['houseNoOrName', 'shopUnitNo', 'shopNo', 'houseNo'],
      );
      _streetName = _readString(
        data,
        ['streetName', 'roadName', 'street'],
      );
      _postcode = _readString(data, ['postcode']);
      _city = _readString(data, ['city', 'analyticsCity']);
      _country = _readString(data, ['country', 'analyticsCountry']);
      _profilePhotoUrl = _readString(data, ['profilePhotoUrl', 'selfieUrl']);
      _referralCode = _readString(data, ['ownReferralCode', 'referralCode']);
      if (_referralCode.isEmpty) {
        _referralCode = 'BG0001';
      }

      final String verificationValue = _readString(
        data,
        [
          'businessProfileVerificationStatus',
          'businessProfileVerificationBackendStatus',
        ],
      ).toLowerCase();
      _isVerified =
          verificationValue == 'submitted' || verificationValue == 'verified';
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value == null) continue;
      final String text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String get _displayName {
    final String fullName = '$_firstName $_surname'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (_legalBusinessName.isNotEmpty) return _legalBusinessName;
    return 'Business Partner';
  }

  Widget _sectionCard({
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 6),
          AutoSizeText(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _detailField({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: _fieldBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0392CA), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color(0x220392CA),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText(
            'Business Profile',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          AutoSizeText(
            _displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          AutoSizeText(
            'Your business details are shown below exactly as submitted during registration.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 18),
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        'Referral Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      AutoSizeText(
                        _referralCode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  clipBehavior: Clip.antiAlias,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Text(
                    _isVerified ? 'Verified' : 'Submitted',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selfieSection() {
    final ImageProvider? imageProvider = _profilePhotoUrl.trim().isNotEmpty
        ? NetworkImage(_profilePhotoUrl)
        : null;

    return _sectionCard(
      title: 'Selfie Verification',
      subtitle: 'The selfie below was submitted during business registration.',
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFFF4FAFD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: imageProvider == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 40,
                      color: _goOutsBlue,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No selfie available',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBackground,
        body: Center(
          child: CircularProgressIndicator(color: _goOutsBlue),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: _pageBackground,
        body: Center(
          child: Text('No logged-in business user found.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: AutoSizeText(
          'Business Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _heroCard(),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Business Partner Details',
              subtitle:
                  'These details were imported from the business registration form.',
              children: [
                _detailField(label: 'Prefix', value: _prefix),
                _detailField(label: 'First Name', value: _firstName),
                _detailField(label: 'Surname', value: _surname),
                _detailField(label: 'Email', value: _email),
                _detailField(
                  label: 'Legal Business Name',
                  value: _legalBusinessName,
                ),
                _detailField(label: 'Company Number', value: _companyNumber),
              ],
            ),
            _sectionCard(
              title: 'Business Address',
              subtitle:
                  'These address details were imported from the business registration form.',
              children: [
                _detailField(
                  label: 'Shop No / House No / Name',
                  value: _houseNoOrName,
                ),
                _detailField(label: 'Street Name', value: _streetName),
                _detailField(label: 'Postcode', value: _postcode),
                _detailField(label: 'City', value: _city),
                _detailField(label: 'Country', value: _country),
              ],
            ),
            _selfieSection(),
          ],
        ),
      ),
    );
  }
}
