import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/models/driver_model.dart';
import 'package:auto_size_text/auto_size_text.dart';

class ReferralDevTesterScreen extends StatefulWidget {
  const ReferralDevTesterScreen({super.key});

  @override
  State<ReferralDevTesterScreen> createState() =>
      _ReferralDevTesterScreenState();
}

class _ReferralDevTesterScreenState extends State<ReferralDevTesterScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);
  static const Color _joinedGreen = Color(0xFF16A34A);
  static const Color _joinedGreenBg = Color(0xFFDCFCE7);
  static const Color _pendingAmber = Color(0xFFD97706);
  static const Color _pendingAmberBg = Color(0xFFFFF3D6);
  static const Color _elsewhereRed = Color(0xFFDC2626);
  static const Color _elsewhereRedBg = Color(0xFFFEE2E2);

  bool _isWorking = false;
  String _driverCollection = 'drivers'; // resolved on load
  String _selectedCity = 'London';

  static const List<String> _ukCities = [
    'London', 'Manchester', 'Birmingham', 'Leeds', 'Glasgow',
    'Liverpool', 'Sheffield', 'Bristol', 'Edinburgh', 'Leicester',
    'Belfast', 'Nottingham', 'Newcastle', 'Bradford', 'Cardiff',
    'Coventry', 'Derby', 'Southampton', 'Portsmouth', 'Norwich',
    'Derry', 'Lisburn', 'Newry', 'Armagh', 'Ballymena',
  ];

  // 10 base people — city/address injected per-city in _createTestDriverProfiles
  static const List<Map<String, String>> _testDriverProfiles = [
    {'firstName': 'Ahmed',    'surname': 'Hassan',   'fullName': 'Ahmed Hassan',
     'email': 'ahmed.hassan@devtest.com',   'birthMonth': 'March',     'birthYear': '1988',
     'phoneNumber': '07700900001'},
    {'firstName': 'Priya',    'surname': 'Sharma',   'fullName': 'Priya Sharma',
     'email': 'priya.sharma@devtest.com',   'birthMonth': 'July',      'birthYear': '1993',
     'phoneNumber': '07700900002'},
    {'firstName': 'Mohammed', 'surname': 'Ali',      'fullName': 'Mohammed Ali',
     'email': 'mohammed.ali@devtest.com',   'birthMonth': 'November',  'birthYear': '1990',
     'phoneNumber': '07700900003'},
    {'firstName': 'Emma',     'surname': 'Clarke',   'fullName': 'Emma Clarke',
     'email': 'emma.clarke@devtest.com',    'birthMonth': 'January',   'birthYear': '1995',
     'phoneNumber': '07700900004'},
    {'firstName': 'Daniel',   'surname': 'Murphy',   'fullName': 'Daniel Murphy',
     'email': 'daniel.murphy@devtest.com',  'birthMonth': 'September', 'birthYear': '1987',
     'phoneNumber': '07700900005'},
    {'firstName': 'Aisha',    'surname': 'Patel',    'fullName': 'Aisha Patel',
     'email': 'aisha.patel@devtest.com',    'birthMonth': 'May',       'birthYear': '1992',
     'phoneNumber': '07700900006'},
    {'firstName': 'Thomas',   'surname': 'Brown',    'fullName': 'Thomas Brown',
     'email': 'thomas.brown@devtest.com',   'birthMonth': 'February',  'birthYear': '1991',
     'phoneNumber': '07700900007'},
    {'firstName': 'Fatima',   'surname': 'Khan',     'fullName': 'Fatima Khan',
     'email': 'fatima.khan@devtest.com',    'birthMonth': 'August',    'birthYear': '1989',
     'phoneNumber': '07700900008'},
    {'firstName': 'James',    'surname': 'Wilson',   'fullName': 'James Wilson',
     'email': 'james.wilson@devtest.com',   'birthMonth': 'December',  'birthYear': '1986',
     'phoneNumber': '07700900009'},
    {'firstName': 'Sara',     'surname': 'Ali',      'fullName': 'Sara Ali',
     'email': 'sara.ali@devtest.com',       'birthMonth': 'October',   'birthYear': '1994',
     'phoneNumber': '07700900010'},
  ];

  // 10 cities with address data
  static const List<Map<String, String>> _testCityData = [
    {'city': 'London',     'postcode': 'NW1 6XE',  'street': 'Baker Street',        'houseNo': '12'},
    {'city': 'Manchester', 'postcode': 'M1 5GD',   'street': 'Oxford Road',         'houseNo': '47'},
    {'city': 'Birmingham', 'postcode': 'B1 2EA',   'street': 'Broad Street',        'houseNo': '8'},
    {'city': 'Belfast',    'postcode': 'BT1 1DA',  'street': 'Royal Avenue',        'houseNo': '3'},
    {'city': 'Leeds',      'postcode': 'LS1 5JB',  'street': 'Park Row',            'houseNo': '21'},
    {'city': 'Glasgow',    'postcode': 'G2 3AE',   'street': 'Sauchiehall Street',  'houseNo': '66'},
    {'city': 'Liverpool',  'postcode': 'L1 4DS',   'street': 'Bold Street',         'houseNo': '14'},
    {'city': 'Derry',      'postcode': 'BT48 6JY', 'street': 'Strand Road',         'houseNo': '9'},
    {'city': 'Bristol',    'postcode': 'BS1 5NF',  'street': 'Park Street',         'houseNo': '29'},
    {'city': 'Newcastle',  'postcode': 'NE1 3AF',  'street': 'Grey Street',         'houseNo': '55'},
  ];

  Future<String> _resolveCollection(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection('drivers').doc(uid).get(),
      firestore.collection('cab_drivers').doc(uid).get(),
      firestore.collection('businesses').doc(uid).get(),
    ]);
    if (results[1].exists) return 'cab_drivers';
    if (results[2].exists) return 'businesses';
    return 'drivers';
  }

  String _generateReferralCode(String uid) {
    final cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    if (cleaned.isEmpty) {
      return 'GO1001';
    }

    if (cleaned.length >= 6) {
      return 'GO${cleaned.substring(cleaned.length - 6)}';
    }

    return 'GO${cleaned.padLeft(6, '0')}';
  }

  String _resolveOwnReferralCode({
    required String uid,
    required Map<String, dynamic>? currentDriverData,
  }) {
    final merged = <String, dynamic>{
      'uid': uid,
      ...?currentDriverData,
    };

    final driver = DriverModel.fromMap(merged);
    final code = driver.referralCode.trim().toUpperCase();

    if (code.isNotEmpty) {
      return code;
    }

    return _generateReferralCode(uid);
  }

  String _normalizePhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleaned.isEmpty) {
      return '';
    }

    if (cleaned.startsWith('+')) {
      return cleaned.substring(1);
    }

    if (cleaned.startsWith('00')) {
      return cleaned.substring(2);
    }

    if (cleaned.startsWith('0')) {
      return '44${cleaned.substring(1)}';
    }

    return cleaned;
  }

  String _buildInviteLink(String token) {
    return 'https://goouts.app/invite?token=$token';
  }

  String _buildToken(String suffix) {
    return 'DEVTEST_${suffix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isWorking) return;

    setState(() {
      _isWorking = true;
    });

    try {
      await action();
    } catch (e) {
      _showSnackBar('Action failed.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _clearTesterScenarios(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final QuerySnapshot<Map<String, dynamic>> sentInviteSnapshot =
        await firestore
            .collection(_driverCollection)
            .doc(userId)
            .collection('sent_invites')
            .where('source', isEqualTo: 'dev_tester')
            .get();

    final QuerySnapshot<Map<String, dynamic>> inviteSnapshot =
        await firestore
            .collection('invites')
            .where('source', isEqualTo: 'dev_tester')
            .get();

    final WriteBatch batch = firestore.batch();

    for (final doc in sentInviteSnapshot.docs) {
      batch.delete(doc.reference);
    }

    for (final doc in inviteSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> _createTestDriverProfiles() async {
    final firestore = FirebaseFirestore.instance;
    final int ts = DateTime.now().millisecondsSinceEpoch;
    WriteBatch batch = firestore.batch();
    int opCount = 0;

    for (int ci = 0; ci < _testCityData.length; ci++) {
      final Map<String, String> cityMap = _testCityData[ci];
      final String city     = cityMap['city']    ?? '';
      final String postcode = cityMap['postcode'] ?? '';
      final String street   = cityMap['street']   ?? '';
      final String houseNo  = cityMap['houseNo']  ?? '';
      final String country  = 'United Kingdom';
      final String addrFull =
          '${houseNo.toUpperCase()} ${street.toUpperCase()}, '
          '${city.toUpperCase()}, $postcode';

      for (int pi = 0; pi < _testDriverProfiles.length; pi++) {
        final Map<String, String> p = _testDriverProfiles[pi];
        final String uid        = 'dev_drv_${ts}_${ci}_$pi';
        final String firstName  = p['firstName']  ?? '';
        final String surname    = p['surname']    ?? '';
        final String fullName   = p['fullName']   ?? '';
        final String birthMonth = p['birthMonth'] ?? '';
        final String birthYear  = p['birthYear']  ?? '';
        final String rawPhone   = p['phoneNumber'] ?? '07700000000';
        final String phone      = rawPhone.length >= 9
            ? '${rawPhone.substring(0, 9)}${ci.toString().padLeft(2, '0')}'
            : rawPhone;
        final String code = 'GODEV${ci.toString().padLeft(2,'0')}${pi.toString().padLeft(2,'0')}';

        final Map<String, dynamic> data = <String, dynamic>{
          'uid':                  uid,
          'fullName':             fullName,
          'firstName':            firstName,
          'surname':              surname,
          'email':                'test@goouts.org',
          'phoneNumber':          phone,
          'birthMonth':           birthMonth,
          'birthYear':            birthYear,
          'houseNoOrName':        houseNo,
          'streetName':           street,
          'city':                 city,
          'postcode':             postcode,
          'country':              country,
          'addressFull':          addrFull,
          'address': <String, dynamic>{
            'houseNoOrName': houseNo,
            'streetName':    street,
            'city':          city,
            'postcode':      postcode,
          },
          'personalDetails': <String, dynamic>{
            'firstName':  firstName,
            'surname':    surname,
            'birthMonth': birthMonth,
            'birthYear':  birthYear,
          },
          'status':                'PENDING',
          'isActive':              false,
          'registrationCompleted': true,
          'ownReferralCode':       code,
          'source':                'dev_tester',
          'createdAt':             FieldValue.serverTimestamp(),
          'updatedAt':             FieldValue.serverTimestamp(),
        };

        batch.set(
          firestore.collection('drivers').doc(uid),
          data,
        );

        opCount++;
        if (opCount == 400) {
          await batch.commit();
          batch = firestore.batch();
          opCount = 0;
        }
      }
    }

    if (opCount > 0) await batch.commit();
  }

    Future<void> _clearTestDriverProfiles() async {
    final firestore = FirebaseFirestore.instance;
    final QuerySnapshot<Map<String, dynamic>> snap = await firestore
        .collection('drivers')
        .where('source', isEqualTo: 'dev_tester')
        .get();

    final WriteBatch batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _createAllCityScenarios({
    required String userId,
    required String referralCode,
  }) async {
    const List<String> cities = [
      'London',
      'Manchester',
      'Birmingham',
      'Belfast',
      'Leeds',
      'Glasgow',
      'Liverpool',
      'Derry',
      'Bristol',
      'Newcastle',
    ];

    // 10 names per city — same pool rotated
    const List<Map<String, String>> people = [
      {'name': 'Ahmed Hassan',   'phone': '077009000'},
      {'name': 'Priya Sharma',   'phone': '077009001'},
      {'name': 'Mohammed Ali',   'phone': '077009002'},
      {'name': 'Emma Clarke',    'phone': '077009003'},
      {'name': 'Daniel Murphy',  'phone': '077009004'},
      {'name': 'Aisha Patel',    'phone': '077009005'},
      {'name': 'Thomas Brown',   'phone': '077009006'},
      {'name': 'Fatima Khan',    'phone': '077009007'},
      {'name': 'James Wilson',   'phone': '077009008'},
      {'name': 'Sara Ali',       'phone': '077009009'},
    ];

    // Status pattern per city: 4 joined, 4 pending, 2 joined_elsewhere
    const List<String> statusPattern = [
      'joined',
      'joined',
      'joined',
      'joined',
      'pending',
      'pending',
      'pending',
      'pending',
      'joined_elsewhere',
      'joined_elsewhere',
    ];

    for (int ci = 0; ci < cities.length; ci++) {
      final String city = cities[ci];
      for (int pi = 0; pi < people.length; pi++) {
        final String name   = people[pi]['name']!;
        final String status = statusPattern[pi];
        final String phone  = '${people[pi]['phone']}${ci.toString().padLeft(2, '0')}';
        final String suffix = '${city.substring(0, 3).toUpperCase()}_$pi';

        await _createScenario(
          userId: userId,
          referralCode: referralCode,
          inviteeName: name,
          inviteePhone: phone,
          status: status,
          joinedDriverName: (status == 'joined' || status == 'joined_elsewhere') ? name : '',
          resolutionReason: status == 'joined_elsewhere' ? 'joined_with_other_referrer' : '',
          tokenSuffix: suffix,
          inviteeCity: city,
        );
      }
    }
  }

  Future<void> _createScenario({
    required String userId,
    required String referralCode,
    required String inviteeName,
    required String inviteePhone,
    required String status,
    required String joinedDriverName,
    required String resolutionReason,
    required String tokenSuffix,
    String inviteeCity = '',
  }) async {
    final firestore = FirebaseFirestore.instance;
    final String inviteToken = _buildToken(tokenSuffix);
    final String inviteId = firestore
        .collection(_driverCollection)
        .doc(userId)
        .collection('sent_invites')
        .doc()
        .id;

    final Map<String, dynamic> baseData = <String, dynamic>{
      'inviteId': inviteId,
      'inviteToken': inviteToken,
      'inviterUid': userId,
      'inviteeName': inviteeName,
      'inviteePhone': inviteePhone,
      'inviteePhoneNormalized': _normalizePhone(inviteePhone),
      'inviteeCity': inviteeCity,
      'city': inviteeCity.trim().toUpperCase(),
      'joinedDriverCity': inviteeCity.trim().toUpperCase(),
      'referralCode': referralCode,
      'status': status,
      'source': 'dev_tester',
      'sentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reminderCount': 0,
      'inviteLink': _buildInviteLink(inviteToken),
      'joinedDriverUid': '',
      'joinedDriverName': '',
      'joinedDriverSelfieUrl': '',
      'clickedAt': null,
      'startedAt': null,
      'joinedAt': null,
      'resolvedAt': null,
      'lastReminderAt': null,
      'resolutionReason': '',
      'isDemo': false,
    };

    if (status == 'joined') {
      baseData['joinedDriverUid'] = 'JOINED_${DateTime.now().millisecondsSinceEpoch}';
      baseData['joinedDriverName'] = joinedDriverName;
      baseData['joinedDriverSelfieUrl'] = '';
      baseData['joinedAt'] = FieldValue.serverTimestamp();
      baseData['resolutionReason'] = 'joined_with_this_referrer';
    }

    if (status == 'joined_elsewhere') {
      baseData['joinedDriverUid'] =
          'OTHER_${DateTime.now().millisecondsSinceEpoch}';
      baseData['joinedDriverName'] = joinedDriverName;
      baseData['joinedDriverSelfieUrl'] = '';
      baseData['joinedAt'] = FieldValue.serverTimestamp();
      baseData['resolvedAt'] = FieldValue.serverTimestamp();
      baseData['resolutionReason'] = resolutionReason;
    }

    final WriteBatch batch = firestore.batch();

    batch.set(
      firestore
          .collection(_driverCollection)
          .doc(userId)
          .collection('sent_invites')
          .doc(inviteId),
      baseData,
      SetOptions(merge: true),
    );

    batch.set(
      firestore.collection('invites').doc(inviteToken),
      baseData,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Widget _buildInfoCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _goOutsBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.science_outlined,
              color: _goOutsBlue,
              size: 24,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  'Dev-only tester',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1C),
                  ),
                ),
                SizedBox(height: 6),
                AutoSizeText(
                  'Use this tool to generate Pending, Joined, and Joined elsewhere referral records directly in Firestore for UI testing.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isWorking ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    AutoSizeText(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTesterItemCard(_TesterItem item) {
    Widget statusWidget;

    if (item.status == 'joined') {
      statusWidget = _buildStatusPill(
        label: 'Joined',
        textColor: _joinedGreen,
        backgroundColor: _joinedGreenBg,
      );
    } else if (item.status == 'joined_elsewhere') {
      statusWidget = _buildStatusPill(
        label: 'Joined elsewhere',
        textColor: _elsewhereRed,
        backgroundColor: _elsewhereRedBg,
      );
    } else {
      statusWidget = _buildStatusPill(
        label: 'Pending',
        textColor: _pendingAmber,
        backgroundColor: _pendingAmberBg,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _goOutsBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              item.initials,
              style: const TextStyle(
                color: _goOutsBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    statusWidget,
                  ],
                ),
                SizedBox(height: 6),
                AutoSizeText(
                  item.displayPhone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                AutoSizeText(
                  item.dateText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverProfileCard(_DriverProfileItem item) {
    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (item.status.toUpperCase()) {
      case 'APPROVED':
        statusColor = _joinedGreen;
        statusBg    = _joinedGreenBg;
        statusLabel = 'Approved';
        break;
      case 'REJECTED':
        statusColor = _elsewhereRed;
        statusBg    = _elsewhereRedBg;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = _pendingAmber;
        statusBg    = _pendingAmberBg;
        statusLabel = 'Pending';
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _goOutsBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              item.initials,
              style: const TextStyle(
                color: _goOutsBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.email,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'DOB: ${item.dob}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  item.address,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.city}  •  ${item.phone}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown time';
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = dateTime.day.toString();
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$day $month, $hour:$minute $period';
  }

  DateTime? _readDateTime(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];

    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  _TesterItem _mapTesterDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String status = (data['status'] ?? '').toString().trim().toLowerCase();
    final String joinedDriverName =
        (data['joinedDriverName'] ?? '').toString().trim();
    final String inviteeName = (data['inviteeName'] ?? '').toString().trim();
    final String inviteePhone = (data['inviteePhone'] ?? '').toString().trim();

    final String displayName = joinedDriverName.isNotEmpty
        ? joinedDriverName
        : inviteeName.isNotEmpty
            ? inviteeName
            : 'Unnamed Driver';

    final List<String> parts = displayName.split(RegExp(r'\s+'));
    String initials = '';

    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      initials += parts.first[0].toUpperCase();
    }
    if (parts.length > 1 && parts[1].isNotEmpty) {
      initials += parts[1][0].toUpperCase();
    }
    if (initials.isEmpty) {
      initials = 'D';
    }

    final DateTime? dateTime = _readDateTime(data, 'joinedAt') ??
        _readDateTime(data, 'resolvedAt') ??
        _readDateTime(data, 'sentAt') ??
        _readDateTime(data, 'updatedAt');

    return _TesterItem(
      displayName: displayName,
      displayPhone: inviteePhone.isEmpty ? 'No phone set' : inviteePhone,
      status: status,
      dateText: _formatDateTime(dateTime),
      initials: initials,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('This screen is only available in debug builds.'),
        ),
      );
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('No logged-in driver found.'),
        ),
      );
    }

    return FutureBuilder<String>(
      future: _resolveCollection(currentUser.uid),
      builder: (context, collectionSnapshot) {
        if (collectionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        _driverCollection = collectionSnapshot.data ?? 'drivers';
        return _buildMainScaffold(currentUser);
      },
    );
  }

  Widget _buildMainScaffold(User currentUser) {
    final DocumentReference<Map<String, dynamic>> currentDriverRef =
        FirebaseFirestore.instance.collection(_driverCollection).doc(currentUser.uid);

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Referral Scenario Tester',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: currentDriverRef.snapshots(),
        builder: (context, driverSnapshot) {
          if (driverSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            );
          }

          final String referralCode = _resolveOwnReferralCode(
            uid: currentUser.uid,
            currentDriverData: driverSnapshot.data?.data(),
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: currentDriverRef
                .collection('sent_invites')
                .where('source', isEqualTo: 'dev_tester')
                .snapshots(),
            builder: (context, testerSnapshot) {
              if (testerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _goOutsBlue),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  testerSnapshot.data?.docs ?? [];

              final List<_TesterItem> testerItems =
                  docs.map(_mapTesterDoc).toList();

              testerItems.sort((a, b) => b.dateText.compareTo(a.dateText));

              final int joinedCount = testerItems
                  .where((item) => item.status == 'joined')
                  .length;
              final int pendingCount = testerItems
                  .where((item) => item.status == 'pending')
                  .length;
              final int elsewhereCount = testerItems
                  .where((item) => item.status == 'joined_elsewhere')
                  .length;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    SizedBox(height: 16),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            'Current tester setup',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 8),
                          AutoSizeText(
                            'Referral code: $referralCode',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildStatusPill(
                                label: 'Joined: $joinedCount',
                                textColor: _joinedGreen,
                                backgroundColor: _joinedGreenBg,
                              ),
                              _buildStatusPill(
                                label: 'Pending: $pendingCount',
                                textColor: _pendingAmber,
                                backgroundColor: _pendingAmberBg,
                              ),
                              _buildStatusPill(
                                label: 'Elsewhere: $elsewhereCount',
                                textColor: _elsewhereRed,
                                backgroundColor: _elsewhereRedBg,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // City picker for single scenario buttons
                    Container(
                      clipBehavior: Clip.antiAlias,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            clipBehavior: Clip.antiAlias,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _goOutsBlue.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.location_city_rounded, color: _goOutsBlue, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'City for single scenarios',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButton<String>(
                                  value: _selectedCity,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  isDense: true,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                  items: _ukCities.map((city) {
                                    return DropdownMenuItem(value: city, child: Text(city));
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedCity = v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Create Pending scenario',
                      subtitle: 'Adds one pending invite with reminder-ready data.',
                      backgroundColor: const Color(0xFFD97706),
                      icon: Icons.schedule_rounded,
                      onTap: () => _runAction(() async {
                        await _createScenario(
                          userId: currentUser.uid,
                          referralCode: referralCode,
                          inviteeName: 'Paras Patel',
                          inviteePhone: '07123456789',
                          status: 'pending',
                          joinedDriverName: '',
                          resolutionReason: '',
                          tokenSuffix: 'PENDING',
                          inviteeCity: _selectedCity,
                        );
                        _showSnackBar('Pending tester scenario created ($_selectedCity).');
                      }),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Create Joined scenario',
                      subtitle: 'Adds one joined invite with final joined status.',
                      backgroundColor: const Color(0xFF16A34A),
                      icon: Icons.check_circle_outline_rounded,
                      onTap: () => _runAction(() async {
                        await _createScenario(
                          userId: currentUser.uid,
                          referralCode: referralCode,
                          inviteeName: 'Adam Khan',
                          inviteePhone: '07111222333',
                          status: 'joined',
                          joinedDriverName: 'Adam Khan',
                          resolutionReason: 'joined_with_this_referrer',
                          tokenSuffix: 'JOINED',
                          inviteeCity: _selectedCity,
                        );
                        _showSnackBar('Joined tester scenario created ($_selectedCity).');
                      }),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Create Joined elsewhere scenario',
                      subtitle: 'Adds one conflicting invite that resolves to red status.',
                      backgroundColor: const Color(0xFFDC2626),
                      icon: Icons.link_off_rounded,
                      onTap: () => _runAction(() async {
                        await _createScenario(
                          userId: currentUser.uid,
                          referralCode: referralCode,
                          inviteeName: 'Sara Ali',
                          inviteePhone: '07111999888',
                          status: 'joined_elsewhere',
                          joinedDriverName: 'Sara Ali',
                          resolutionReason: 'joined_with_other_referrer',
                          tokenSuffix: 'ELSEWHERE',
                          inviteeCity: _selectedCity,
                        );
                        _showSnackBar('Joined elsewhere tester scenario created ($_selectedCity).');
                      }),
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Create 100 test scenarios',
                      subtitle:
                          '10 entries per city across 10 UK & NI cities (100 total).',
                      backgroundColor: _goOutsBlue,
                      icon: Icons.auto_fix_high_rounded,
                      onTap: () => _runAction(() async {
                        await _clearTesterScenarios(currentUser.uid);
                        await _createAllCityScenarios(
                          userId: currentUser.uid,
                          referralCode: referralCode,
                        );
                        _showSnackBar('100 test scenarios created successfully.');
                      }),
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Clear tester scenarios',
                      subtitle: 'Deletes only dev_tester records from Firestore.',
                      backgroundColor: const Color(0xFF6B7280),
                      icon: Icons.delete_outline_rounded,
                      onTap: () => _runAction(() async {
                        await _clearTesterScenarios(currentUser.uid);
                        _showSnackBar('Tester scenarios cleared.');
                      }),
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Create 100 driver profiles',
                      subtitle: 'Adds 100 test drivers (10 per city, 10 cities) to the drivers collection.',
                      backgroundColor: const Color(0xFF7C3AED),
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: () => _runAction(() async {
                        await _createTestDriverProfiles();
                        _showSnackBar('100 test driver profiles created (10 cities × 10 drivers).');
                      }),
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      title: 'Clear driver profiles',
                      subtitle: 'Deletes dev_tester driver profiles from drivers collection.',
                      backgroundColor: const Color(0xFF9CA3AF),
                      icon: Icons.person_remove_outlined,
                      onTap: () => _runAction(() async {
                        await _clearTestDriverProfiles();
                        _showSnackBar('Test driver profiles cleared.');
                      }),
                    ),
                    SizedBox(height: 18),
                    AutoSizeText(
                      'Tester preview entries',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (testerItems.isEmpty)
                      Container(
                        clipBehavior: Clip.antiAlias,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: AutoSizeText(
                          'No tester scenarios yet. Create one above and then open My Referrals to check the real screen behavior.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: testerItems
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTesterItemCard(item),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 24),
                    AutoSizeText(
                      'Driver profile test entries',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AutoSizeText(
                      'These profiles appear in the Admin Panel driver management list.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('drivers')
                          .where('source', isEqualTo: 'dev_tester')
                          .snapshots(),
                      builder: (context, driverProfileSnap) {
                        if (driverProfileSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: _goOutsBlue));
                        }
                        final List<QueryDocumentSnapshot<Map<String, dynamic>>> profileDocs =
                            driverProfileSnap.data?.docs ?? [];

                        if (profileDocs.isEmpty) {
                          return Container(
                            clipBehavior: Clip.antiAlias,
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: AutoSizeText(
                              'No driver profiles yet. Tap "Create 100 driver profiles" above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        final List<_DriverProfileItem> profileItems = profileDocs.map((doc) {
                          final d = doc.data();
                          final String fn = (d['fullName'] ?? '').toString().trim();
                          final List<String> parts = fn.split(RegExp(r'\s+'));
                          String initials = '';
                          if (parts.isNotEmpty && parts.first.isNotEmpty) initials += parts.first[0].toUpperCase();
                          if (parts.length > 1 && parts[1].isNotEmpty) initials += parts[1][0].toUpperCase();
                          if (initials.isEmpty) initials = 'D';
                          final String bm = (d['birthMonth'] ?? '').toString();
                          final String by = (d['birthYear'] ?? '').toString();
                          final String dob = (bm.isNotEmpty && by.isNotEmpty) ? '$bm $by' : (bm + by).trim();
                          final String hn = (d['houseNoOrName'] ?? '').toString();
                          final String st = (d['streetName'] ?? '').toString();
                          final String pc = (d['postcode'] ?? '').toString();
                          final String addr = [hn, st, pc].where((s) => s.isNotEmpty).join(', ');
                          return _DriverProfileItem(
                            fullName: fn.isEmpty ? 'Unnamed' : fn,
                            email: (d['email'] ?? '').toString(),
                            dob: dob.isEmpty ? '—' : dob,
                            address: addr.isEmpty ? '—' : addr,
                            city: (d['city'] ?? '').toString(),
                            phone: (d['phoneNumber'] ?? '').toString(),
                            status: (d['status'] ?? 'PENDING').toString(),
                            initials: initials,
                          );
                        }).toList();

                        return Column(
                          children: profileItems.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDriverProfileCard(item),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TesterItem {
  final String displayName;
  final String displayPhone;
  final String status;
  final String dateText;
  final String initials;

  const _TesterItem({
    required this.displayName,
    required this.displayPhone,
    required this.status,
    required this.dateText,
    required this.initials,
  });
}
class _DriverProfileItem {
  final String fullName;
  final String email;
  final String dob;
  final String address;
  final String city;
  final String phone;
  final String status;
  final String initials;

  const _DriverProfileItem({
    required this.fullName,
    required this.email,
    required this.dob,
    required this.address,
    required this.city,
    required this.phone,
    required this.status,
    required this.initials,
  });
}
