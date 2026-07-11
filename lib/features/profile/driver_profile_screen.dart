import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../legal/terms_and_conditions_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);
  static const String _termsUrl = 'https://example.com/goouts-terms';

  late final Future<_CurrentAccount?> _accountFuture;

  @override
  void initState() {
    super.initState();
    _accountFuture = _loadCurrentAccount();
  }

  Future<_CurrentAccount?> _loadCurrentAccount() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return null;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final Future<DocumentSnapshot<Map<String, dynamic>>> driverFuture =
        firestore.collection('drivers').doc(currentUser.uid).get();
    final Future<DocumentSnapshot<Map<String, dynamic>>> businessFuture =
        firestore.collection('businesses').doc(currentUser.uid).get();

    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
      <Future<DocumentSnapshot<Map<String, dynamic>>>>[
        driverFuture,
        businessFuture,
      ],
    );

    final DocumentSnapshot<Map<String, dynamic>> driverDoc = snapshots[0];
    final DocumentSnapshot<Map<String, dynamic>> businessDoc = snapshots[1];
    final Map<String, dynamic>? driverData = driverDoc.data();
    final Map<String, dynamic>? businessData = businessDoc.data();

    final bool businessLooksValid = businessDoc.exists &&
        _looksLikeBusinessProfile(businessData);
    final bool driverLooksValid = driverDoc.exists &&
        !_looksLikeBusinessProfile(driverData);

    if (businessLooksValid) {
      return _CurrentAccount(
        uid: currentUser.uid,
        collection: 'businesses',
        isBusiness: true,
      );
    }

    if (driverLooksValid) {
      return _CurrentAccount(
        uid: currentUser.uid,
        collection: 'drivers',
        isBusiness: false,
      );
    }

    if (businessDoc.exists) {
      return _CurrentAccount(
        uid: currentUser.uid,
        collection: 'businesses',
        isBusiness: true,
      );
    }

    if (driverDoc.exists) {
      return _CurrentAccount(
        uid: currentUser.uid,
        collection: 'drivers',
        isBusiness: false,
      );
    }

    return _CurrentAccount(
      uid: currentUser.uid,
      collection: 'drivers',
      isBusiness: false,
    );
  }

  bool _looksLikeBusinessProfile(Map<String, dynamic>? data) {
    if (data == null) {
      return false;
    }

    final String accountType =
        (data['accountType'] ?? '').toString().trim().toLowerCase();
    final String dashboardRole =
        (data['dashboardRole'] ?? '').toString().trim().toLowerCase();
    final String legalBusinessName =
        (data['legalBusinessName'] ?? '').toString().trim();
    final String companyNumber =
        (data['companyNumber'] ?? '').toString().trim();
    final String referralCode =
        (data['ownReferralCode'] ?? data['referralCode'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

    return accountType == 'business' ||
        dashboardRole == 'business' ||
        legalBusinessName.isNotEmpty ||
        companyNumber.isNotEmpty ||
        referralCode.startsWith('GB');
  }

  String _readString(
    Map<String, dynamic>? data,
    List<String> keys, {
    String fallback = '',
  }) {
    if (data == null) {
      return fallback;
    }

    for (final String key in keys) {
      final dynamic value = data[key];
      if (value == null) {
        continue;
      }

      final String text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  String _readNestedString(
    Map<String, dynamic>? data,
    List<String> path, {
    String fallback = '',
  }) {
    dynamic current = data;

    for (final String key in path) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return fallback;
      }
    }

    if (current == null) {
      return fallback;
    }

    final String text = current.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  bool _readBool(
    Map<String, dynamic>? data,
    List<String> keys, {
    bool fallback = false,
  }) {
    if (data == null) {
      return fallback;
    }

    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is bool) {
        return value;
      }

      if (value is num) {
        return value != 0;
      }

      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized == 'true') {
          return true;
        }
        if (normalized == 'false') {
          return false;
        }
      }
    }

    return fallback;
  }

  String _formatDisplayText(String value) {
    final String cleaned = value.trim();
    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((String word) {
          if (word.isEmpty) {
            return word;
          }
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  String _buildDisplayName({
    required Map<String, dynamic>? data,
    required User currentUser,
    required bool isBusiness,
  }) {
    if (isBusiness) {
      final String fullName = _formatDisplayText(
        _readString(data, const <String>['fullName', 'contactPersonName']),
      );
      if (fullName.isNotEmpty) {
        return fullName;
      }

      final String firstName = _readString(data, const <String>['firstName']);
      final String surname = _readString(data, const <String>['surname']);
      final String nameFromParts = _formatDisplayText('$firstName $surname'.trim());
      if (nameFromParts.isNotEmpty) {
        return nameFromParts;
      }

      final String legalBusinessName = _formatDisplayText(
        _readString(data, const <String>['legalBusinessName']),
      );
      if (legalBusinessName.isNotEmpty) {
        return legalBusinessName;
      }

      return 'Business Partner';
    }

    final String fullName = _formatDisplayText(
      _readString(data, const <String>['fullName']),
    );
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final String firstName = _readString(data, const <String>['firstName']);
    final String surname = _readString(data, const <String>['surname']);
    final String nameFromParts = _formatDisplayText('$firstName $surname'.trim());
    if (nameFromParts.isNotEmpty) {
      return nameFromParts;
    }

    return currentUser.phoneNumber?.trim().isNotEmpty == true
        ? currentUser.phoneNumber!.trim()
        : 'Driver';
  }

  String _buildPhoneNumber(Map<String, dynamic>? data, User currentUser) {
    return _readString(
      data,
      const <String>['phone', 'phoneNumber'],
      fallback: _readNestedString(
        data,
        const <String>['contactDetails', 'phoneNumber'],
        fallback: currentUser.phoneNumber ?? '',
      ),
    );
  }

  String _buildEmail(Map<String, dynamic>? data) {
    return _readString(
      data,
      const <String>['email'],
      fallback: _readNestedString(data, const <String>['contactDetails', 'email']),
    );
  }

  String _buildCity(Map<String, dynamic>? data) {
    return _formatDisplayText(
      _readString(
        data,
        const <String>['city'],
        fallback: _readNestedString(data, const <String>['address', 'city']),
      ),
    );
  }

  String _buildCountry(Map<String, dynamic>? data) {
    return _formatDisplayText(
      _readString(
        data,
        const <String>['country'],
        fallback: _readNestedString(data, const <String>['contactDetails', 'country']),
      ),
    );
  }

  String _buildPostcode(Map<String, dynamic>? data) {
    return _readString(
      data,
      const <String>['postcode'],
      fallback: _readNestedString(data, const <String>['address', 'postcode']),
    ).toUpperCase();
  }

  String _buildAddressLine(Map<String, dynamic>? data) {
    final String house = _formatDisplayText(
      _readString(
        data,
        const <String>['houseNoOrName'],
        fallback: _readNestedString(data, const <String>['address', 'houseNoOrName']),
      ),
    );
    final String street = _formatDisplayText(
      _readString(
        data,
        const <String>['streetName'],
        fallback: _readNestedString(data, const <String>['address', 'streetName']),
      ),
    );

    return '$house $street'.trim();
  }

  String _buildVehicleType(Map<String, dynamic>? data) {
    return _formatDisplayText(
      _readString(
        data,
        const <String>['vehicleType'],
        fallback: _readNestedString(data, const <String>['vehicleDetails', 'vehicleType']),
      ),
    );
  }

  String _buildBusinessName(Map<String, dynamic>? data) {
    return _formatDisplayText(
      _readString(data, const <String>['legalBusinessName']),
    );
  }

  String _buildCompanyNumber(Map<String, dynamic>? data) {
    return _readString(data, const <String>['companyNumber']).toUpperCase();
  }

  String _buildReferralCode({
    required Map<String, dynamic>? data,
    required String uid,
    required bool isBusiness,
  }) {
    final String ownCode =
        _readString(data, const <String>['ownReferralCode', 'referralCode']).toUpperCase();
    if (ownCode.isNotEmpty && (!isBusiness || ownCode.startsWith('GB'))) {
      return ownCode;
    }

    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (isBusiness) {
      if (cleaned.isEmpty) {
        return 'BG0001';
      }
      if (cleaned.length >= 4) {
        return 'BG${cleaned.substring(cleaned.length - 4)}';
      }
      return 'BG${cleaned.padLeft(4, '0')}';
    }

    if (cleaned.isEmpty) {
      return 'G01001';
    }
    if (cleaned.length >= 6) {
      return 'GO${cleaned.substring(cleaned.length - 6)}';
    }
    return 'GO${cleaned.padLeft(6, '0')}';
  }

  String _buildVerificationStatus({
    required Map<String, dynamic>? data,
    required bool isBusiness,
  }) {
    final List<String> keys = isBusiness
        ? const <String>[
            'businessProfileVerificationStatus',
            'businessProfileVerificationBackendStatus',
          ]
        : const <String>[
            'identityVerificationStatus',
            'identityVerificationBackendStatus',
          ];

    final String rawStatus =
        _readString(data, keys, fallback: 'submitted').trim().toLowerCase();

    if (rawStatus == 'verified' || rawStatus == 'approved' || rawStatus == 'success') {
      return 'verified';
    }

    if (rawStatus == 'rejected' || rawStatus == 'failed' || rawStatus == 'needs_support') {
      return 'rejected';
    }

    return 'submitted';
  }

  String _buildVerificationStatusLabel({
    required String status,
    required bool isBusiness,
  }) {
    switch (status) {
      case 'verified':
        return isBusiness ? 'Business Profile Verified' : 'Verified';
      case 'rejected':
        return isBusiness ? 'Business Profile Needs Attention' : 'Verification Failed';
      default:
        return isBusiness ? 'Business Profile Under Review' : 'Submitted';
    }
  }

  String _buildVerificationDescription({
    required String status,
    required bool isBusiness,
  }) {
    if (isBusiness) {
      switch (status) {
        case 'verified':
          return 'Your business profile is verified.';
        case 'rejected':
          return 'Please review your business details or contact support.';
        default:
          return 'Your business profile is submitted successfully.';
      }
    }

    switch (status) {
      case 'verified':
        return 'Your driver profile has been verified successfully.';
      case 'rejected':
        return 'Please review your driver verification details or contact support.';
      default:
        return 'Your driver profile is under review.';
    }
  }

  Color _verificationStatusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return _goOutsBlue;
    }
  }

  IconData _verificationStatusIcon(String status) {
    switch (status) {
      case 'verified':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.error_outline_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  void _launchTerms() {
    showTermsSheet(context);
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String value}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            clipBehavior: Clip.antiAlias,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _goOutsBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _goOutsBlue),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AutoSizeText(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                AutoSizeText(
                  value.trim().isEmpty ? 'Not set' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard({
    required bool isBusiness,
    required String status,
  }) {
    final Color accentColor = _verificationStatusColor(status);

    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.25)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            clipBehavior: Clip.antiAlias,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _verificationStatusIcon(status),
              color: accentColor,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AutoSizeText(
                  _buildVerificationStatusLabel(status: status, isBusiness: isBusiness),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                SizedBox(height: 6),
                AutoSizeText(
                  _buildVerificationDescription(status: status, isBusiness: isBusiness),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('No logged-in account found.'),
        ),
      );
    }

    return FutureBuilder<_CurrentAccount?>(
      future: _accountFuture,
      builder: (BuildContext context, AsyncSnapshot<_CurrentAccount?> accountSnapshot) {
        if (accountSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _screenBackground,
            body: Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            ),
          );
        }

        final _CurrentAccount? account = accountSnapshot.data;
        if (account == null) {
          return const Scaffold(
            body: Center(
              child: Text('No logged-in account found.'),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(account.collection)
              .doc(account.uid)
              .snapshots(),
          builder: (BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: _screenBackground,
                body: Center(
                  child: CircularProgressIndicator(color: _goOutsBlue),
                ),
              );
            }

            final Map<String, dynamic>? data = snapshot.data?.data();
            final String displayName = _buildDisplayName(
              data: data,
              currentUser: currentUser,
              isBusiness: account.isBusiness,
            );
            final String phoneNumber = _buildPhoneNumber(data, currentUser);
            final String email = _buildEmail(data);
            final String referralCode = _buildReferralCode(
              data: data,
              uid: account.uid,
              isBusiness: account.isBusiness,
            );
            final String verificationStatus = _buildVerificationStatus(
              data: data,
              isBusiness: account.isBusiness,
            );
            final String city = _buildCity(data);
            final String country = _buildCountry(data);
            final String postcode = _buildPostcode(data);
            final String addressLine = _buildAddressLine(data);
            final String photoUrl = _readString(
              data,
              const <String>['profilePhotoUrl', 'selfieUrl'],
              fallback: _readNestedString(data, const <String>['profileImage', 'photoUrl']),
            );

            final String roleLabel = account.isBusiness ? 'Business Partner' : 'Driver';
            final String businessName = _buildBusinessName(data);
            final String companyNumber = _buildCompanyNumber(data);
            final String vehicleType = _buildVehicleType(data);
            final bool termsAccepted = _readBool(
              data,
              const <String>['termsAccepted'],
              fallback: _readBool(data, const <String>['acceptedTerms']),
            );

            return Scaffold(
              backgroundColor: _screenBackground,
              appBar: AppBar(
                backgroundColor: _goOutsBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  account.isBusiness ? 'Business Profile' : 'Driver Profile',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: _goOutsBlue.withOpacity(0.12),
                            backgroundImage: photoUrl.trim().isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.trim().isEmpty
                                ? Icon(
                                    account.isBusiness ? Icons.storefront_rounded : Icons.person_rounded,
                                    size: 40,
                                    color: _goOutsBlue,
                                  )
                                : null,
                          ),
                          SizedBox(height: 14),
                          AutoSizeText(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          AutoSizeText(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (phoneNumber.trim().isNotEmpty) ...<Widget>[
                            SizedBox(height: 6),
                            AutoSizeText(
                              phoneNumber,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                          if (email.trim().isNotEmpty) ...<Widget>[
                            SizedBox(height: 4),
                            AutoSizeText(
                              email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildVerificationCard(
                      isBusiness: account.isBusiness,
                      status: verificationStatus,
                    ),
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      title: 'Referral Code',
                      value: referralCode,
                    ),
                    if (account.isBusiness) ...<Widget>[
                      _buildInfoTile(
                        icon: Icons.business_rounded,
                        title: 'Legal Business Name',
                        value: businessName,
                      ),
                      _buildInfoTile(
                        icon: Icons.numbers_rounded,
                        title: 'Business / Company Number',
                        value: companyNumber,
                      ),
                    ] else ...<Widget>[
                      _buildInfoTile(
                        icon: Icons.two_wheeler_rounded,
                        title: 'Vehicle Type',
                        value: vehicleType,
                      ),
                    ],
                    _buildInfoTile(
                      icon: Icons.location_city_rounded,
                      title: 'City',
                      value: city,
                    ),
                    _buildInfoTile(
                      icon: Icons.public_rounded,
                      title: 'Country',
                      value: country,
                    ),
                    _buildInfoTile(
                      icon: Icons.markunread_mailbox_outlined,
                      title: 'Postcode',
                      value: postcode,
                    ),
                    _buildInfoTile(
                      icon: Icons.home_work_outlined,
                      title: account.isBusiness ? 'Shop No/Name & Street / Road Name' : 'House No/Name & Street',
                      value: addressLine,
                    ),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.rule_folder_outlined, color: _goOutsBlue),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  termsAccepted ? 'Terms accepted' : 'Terms not confirmed yet',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _launchTerms,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open Terms & Conditions'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _goOutsBlue,
                              side: const BorderSide(color: _goOutsBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CurrentAccount {
  final String uid;
  final String collection;
  final bool isBusiness;

  const _CurrentAccount({
    required this.uid,
    required this.collection,
    required this.isBusiness,
  });
}
