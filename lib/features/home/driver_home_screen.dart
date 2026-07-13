import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart'; // for RoleIntroSlidesScreen
import '../auth/login_screen.dart';
import '../legal/faq_screen.dart';
import '../legal/terms_and_conditions_screen.dart';
import '../merchant/driver_earnings_screen.dart';
import '../merchant/merchant_onboarding_screen.dart';
import '../messages/messages_inbox_screen.dart';
import '../profile/driver_profile_screen.dart';
import '../referral/referral_dev_tester_screen.dart';
import '../referral/referral_link_screen.dart';
import '../referral/referral_list_screen.dart';
import '../support/help_support_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _pageBackground = Colors.white;
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder = Color(0xFFE8EEF3);
  static const Color _softBlueTint = Color(0xFFF4FAFD);

  late final Future<_CurrentAccount?> _accountFuture;
  int _unreadMessagesCount = 0;
  int _referralActivityCount = 0;
  int _totalReferralsCount = 0;
  DateTime? _lastViewedAt;
  bool _hasLoadedDashboardStats = false;

  @override
  void initState() {
    super.initState();
    _accountFuture = _loadCurrentAccount();
  }

  Future<_CurrentAccount?> _loadCurrentAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final Future<DocumentSnapshot<Map<String, dynamic>>> driverFuture =
        firestore.collection('drivers').doc(user.uid).get();
    final Future<DocumentSnapshot<Map<String, dynamic>>> businessFuture =
        firestore.collection('businesses').doc(user.uid).get();
    final Future<DocumentSnapshot<Map<String, dynamic>>> cabDriverFuture =
        firestore.collection('cab_drivers').doc(user.uid).get();

    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
      driverFuture,
      businessFuture,
      cabDriverFuture,
    ]);

    final DocumentSnapshot<Map<String, dynamic>> driverDoc = snapshots[0];
    final DocumentSnapshot<Map<String, dynamic>> businessDoc = snapshots[1];
    final DocumentSnapshot<Map<String, dynamic>> cabDriverDoc = snapshots[2];
    final Map<String, dynamic>? driverData = driverDoc.data();
    final Map<String, dynamic>? businessData = businessDoc.data();

    final bool businessLooksValid =
        businessDoc.exists && _looksLikeBusinessProfile(businessData);
    final bool driverLooksValid =
        driverDoc.exists && !_looksLikeBusinessProfile(driverData);

    if (businessLooksValid) {
      return _CurrentAccount(
        uid: user.uid,
        collection: 'businesses',
        isBusiness: true,
      );
    }

    if (driverLooksValid) {
      return _CurrentAccount(
        uid: user.uid,
        collection: 'drivers',
        isBusiness: false,
      );
    }

    if (cabDriverDoc.exists) {
      return _CurrentAccount(
        uid: user.uid,
        collection: 'cab_drivers',
        isBusiness: false,
      );
    }

    if (businessDoc.exists) {
      return _CurrentAccount(
        uid: user.uid,
        collection: 'businesses',
        isBusiness: true,
      );
    }

    if (driverDoc.exists) {
      return _CurrentAccount(
        uid: user.uid,
        collection: 'drivers',
        isBusiness: false,
      );
    }

    return _CurrentAccount(
      uid: user.uid,
      collection: 'drivers',
      isBusiness: false,
    );
  }

  Future<void> _loadDashboardStats(_CurrentAccount account) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentSnapshot<Map<String, dynamic>> accountDoc =
          await firestore.collection(account.collection).doc(account.uid).get();
      final Map<String, dynamic> accountData =
          accountDoc.data() ?? <String, dynamic>{};

      final DateTime? lastViewedAt = _readDateTime(
        accountData,
        const ['lastReferralActivityViewedAt'],
      );

      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot = await firestore
          .collection(account.collection)
          .doc(account.uid)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();

      final QuerySnapshot<Map<String, dynamic>> referralsSnapshot = await firestore
          .collection(account.collection)
          .doc(account.uid)
          .collection('sent_invites')
          .orderBy('sentAt', descending: true)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _lastViewedAt = lastViewedAt;
        _unreadMessagesCount = _getUnreadMessagesCount(messagesSnapshot.docs);
        _totalReferralsCount = referralsSnapshot.docs.length;
        _referralActivityCount = _getReferralActivityCount(
          referralsSnapshot.docs,
          lastViewedAt,
        );
        _hasLoadedDashboardStats = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasLoadedDashboardStats = true;
      });
    }
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
    final String companyNumber = (data['companyNumber'] ?? '').toString().trim();
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

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (!mounted) {
        return;
      }
      _accountFuture.then((final _CurrentAccount? account) {
        if (account != null) {
          _loadDashboardStats(account);
        }
      });
    });
  }

  void _copyReferralCode(BuildContext context, String referralCode) {
    if (referralCode.trim().isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: referralCode));

    GoOutsSheet.success(context, title: 'Copied!', message: 'Referral code copied to clipboard.');
  }

  Future<void> _logout() async {
    // Capture phone number BEFORE signing out
    final String? e164Phone =
        FirebaseAuth.instance.currentUser?.phoneNumber;
    String localMobile = '';
    if (e164Phone != null && e164Phone.startsWith('+44')) {
      localMobile = '0${e164Phone.substring(3)}';
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          arguments: <String, dynamic>{
            'accountType': 'driver',
            'mobile': localMobile,
            'isReturningUser': true,
          },
        ),
        builder: (_) => const LoginScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context)
      GoOutsSheet.info(context, title: 'Coming Soon', message: '$title will be connected next.');
  }

  void _openMenu({
    required BuildContext context,
    required _CurrentAccount account,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E3EC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _menuTile(
                  icon: Icons.home_rounded,
                  title: 'Home',
                  onTap: () => Navigator.pop(sheetContext),
                ),
                _menuTile(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openScreen(context, const DriverProfileScreen());
                  },
                ),
                _menuTile(
                  icon: Icons.share_outlined,
                  title: 'My Referral Code',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openScreen(context, const ReferralLinkScreen());
                  },
                ),
                
                if (kDebugMode)
                _menuTile(
                  icon: Icons.slideshow_outlined,
                  title: 'Intro Slides',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RoleIntroSlidesScreen(
                      accountType: 'driver',
                      openedFromMenu: true,
                  ),
                ),
               );
              },
            ),

                _menuTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openScreen(
                      context,
                      HelpSupportScreen(
                        accountType: account.isBusiness ? 'business' : 'driver',
                        collectionName: account.collection,
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.help_outline_rounded,
                  title: 'FAQ',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FaqScreen(),
                      ),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showTermsSheet(context);
                  },
                ),
                _menuTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = _goOutsBlue,
    Color textColor = _textPrimary,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: AutoSizeText(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning';
    }

    if (hour < 17) {
      return 'Good Afternoon';
    }

    return 'Good Evening';
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
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
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

      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized == 'true') {
          return true;
        }
        if (normalized == 'false') {
          return false;
        }
      }

      if (value is num) {
        return value != 0;
      }
    }

    return fallback;
  }

  DateTime? _readDateTime(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) {
      return null;
    }

    for (final String key in keys) {
      final dynamic value = data[key];
      if (value == null) {
        continue;
      }

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String && value.trim().isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    }

    return null;
  }

  String _displayName({
    required Map<String, dynamic>? data,
    required User? user,
    required bool isBusiness,
  }) {
    if (isBusiness) {
      final String fullName = _titleCase(
        _readString(
          data,
          const [
            'fullName',
            'contactPersonName',
          ],
        ),
      );
      if (fullName.isNotEmpty) {
        return fullName;
      }

      final String firstName = _readString(data, const ['firstName']);
      final String surname = _readString(data, const ['surname']);
      final String fromParts = _titleCase('$firstName $surname'.trim());
      if (fromParts.isNotEmpty) {
        return fromParts;
      }

      final String legalBusinessName = _titleCase(
        _readString(data, const ['legalBusinessName']),
      );
      if (legalBusinessName.isNotEmpty) {
        return legalBusinessName;
      }

      return 'Business Partner';
    }

    final String fullName = _titleCase(
      _readString(data, const ['fullName']),
    );
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final String firstName = _readString(data, const ['firstName']);
    final String surname = _readString(data, const ['surname']);
    final String fromParts = _titleCase('$firstName $surname'.trim());
    if (fromParts.isNotEmpty) {
      return fromParts;
    }

    final String phone = user?.phoneNumber?.trim() ?? '';
    if (phone.isNotEmpty) {
      return phone;
    }

    return 'Driver';
  }

  String _referralCode({
    required Map<String, dynamic>? data,
    required bool isBusiness,
    required String uid,
  }) {
    final String ownReferralCode =
        _readString(data, const ['ownReferralCode']).toUpperCase();
    if (ownReferralCode.isNotEmpty &&
        (!isBusiness || ownReferralCode.startsWith('GB'))) {
      return ownReferralCode;
    }

    final String referralCode =
        _readString(data, const ['referralCode']).toUpperCase();
    if (referralCode.isNotEmpty &&
        (!isBusiness || referralCode.startsWith('GB'))) {
      return referralCode;
    }

    final String cleaned =
        uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

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
      return 'GD100001';
    }

    if (cleaned.length >= 6) {
      return 'GD${cleaned.substring(cleaned.length - 6)}';
    }

    return 'GD${cleaned.padLeft(6, '0')}';
  }

  int _getUnreadMessagesCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int unreadCount = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      if (!_readBool(doc.data(), ['isRead', 'read', 'seen'])) {
        unreadCount++;
      }
    }
    return unreadCount;
  }

  int _getReferralActivityCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime? lastViewedAt,
  ) {
    if (lastViewedAt == null) {
      return docs.length;
    }

    int activityCount = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final DateTime? activityDate = _readDateTime(
        doc.data(),
        ['resolvedAt', 'joinedAt', 'updatedAt', 'sentAt'],
      );
      if (activityDate != null && activityDate.isAfter(lastViewedAt)) {
        activityCount++;
      }
    }
    return activityCount;
  }

  Widget _buildLoggedOutState() {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: true,
        title: AutoSizeText(
          'GoOuts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No logged-in account found.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          SizedBox(height: 10),
          AutoSizeText(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          AutoSizeText(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badgeCount = 0,
    Color? iconColor,
    Color? iconBgColor,
  }) {
    final ic = iconColor ?? _goOutsBlue;
    final ibg = iconBgColor ?? _softBlueTint;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: badgeCount > 0
                ? _goOutsBlue.withOpacity(0.40)
                : _softBorder,
            width: badgeCount > 0 ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeCount > 0
                  ? _goOutsBlue.withOpacity(0.08)
                  : const Color(0x0A000000),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ibg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: ic, size: 22),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Spacer(),
            AutoSizeText(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 6),
            AutoSizeText(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Row(
              children: [
                AutoSizeText(
                  'Open',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ic,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ic,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverWelcomeCard({
    required BuildContext context,
    required String name,
    required String referralCode,
    required int unreadMessagesCount,
    required int referralActivityCount,
    required int totalReferralsCount,
    required String accountStatus,
  }) {
    final bool isLive = accountStatus.toUpperCase() == 'APPROVED';
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0392CA),
            Color(0xFF0EA5E9),
          ],
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AutoSizeText(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isLive
                            ? const Color(0xFFBAE6FD)
                            : const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLive ? 'LIVE' : 'PENDING',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          AutoSizeText(
            'Manage your referral tools, profile details, and driver messages from one place.',
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
                        'Your Referral Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      AutoSizeText(
                        referralCode.isEmpty ? 'GD100001' : referralCode,
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
                IconButton(
                  onPressed: () => _copyReferralCode(
                    context,
                    referralCode.isEmpty ? 'GD100001' : referralCode,
                  ),
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _heroStatCard(
                  icon: Icons.mail_outline_rounded,
                  value: unreadMessagesCount.toString(),
                  label: 'Unread Messages',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStatCard(
                  icon: Icons.group_outlined,
                  value: totalReferralsCount.toString(),
                  label: 'Total Referral Details',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStatCard(
                  icon: Icons.notifications_active_outlined,
                  value: referralActivityCount.toString(),
                  label: 'Your New Activity',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return _buildLoggedOutState();
    }

    return FutureBuilder<_CurrentAccount?>(
      future: _accountFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<_CurrentAccount?> accountSnapshot,
      ) {
        if (accountSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            ),
          );
        }

        final _CurrentAccount? account = accountSnapshot.data;
        if (account == null) {
          return _buildLoggedOutState();
        }

        if (!_hasLoadedDashboardStats) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadDashboardStats(account);
            }
          });
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(account.collection)
              .doc(account.uid)
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: _goOutsBlue),
                ),
              );
            }

            final Map<String, dynamic>? data = snapshot.data?.data();
            final String displayName = _displayName(
              data: data,
              user: currentUser,
              isBusiness: account.isBusiness,
            );
            final String referralCode = _referralCode(
              data: data,
              isBusiness: account.isBusiness,
              uid: account.uid,
            );

            return Scaffold(
              backgroundColor: _pageBackground,
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: _textPrimary,
                elevation: 0,
                centerTitle: true,
                title: AutoSizeText(
                  account.isBusiness
                      ? 'GoOuts Business Partner'
                      : 'GoOuts Driver',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _openMenu(
                      context: context,
                      account: account,
                    ),
                    icon: Icon(Icons.menu_rounded),
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () => _loadDashboardStats(account),
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _driverWelcomeCard(
                          context: context,
                          name: displayName,
                          referralCode: referralCode,
                          unreadMessagesCount: _unreadMessagesCount,
                          referralActivityCount: _referralActivityCount,
                          totalReferralsCount: _totalReferralsCount,
                          accountStatus: (data?['status'] ?? '').toString(),
                        ),
                        SizedBox(height: 24),
                        AutoSizeText(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        AutoSizeText(
                          'Access your referral tools, profile and messages easily.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount:
                              MediaQuery.of(context).size.width < 360 ? 1 : 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              MediaQuery.of(context).size.width < 360
                                  ? 1.3
                                  : 0.92,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            // ── Sign up a Business ──
                            _buildQuickActionCard(
                              context: context,
                              icon: Icons.store_rounded,
                              title: 'Sign up a Business',
                              subtitle:
                                  'Onboard a new venue and earn residual commission',
                              iconColor: const Color(0xFF10B981),
                              iconBgColor:
                                  const Color(0xFF10B981).withOpacity(0.1),
                              onTap: () => _openScreen(
                                context,
                                const MerchantOnboardingScreen(),
                              ),
                            ),
                            // ── My Earnings ──
                            _buildQuickActionCard(
                              context: context,
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'My Earnings',
                              subtitle:
                                  'Track commission from your referred businesses',
                              iconColor: const Color(0xFFF59E0B),
                              iconBgColor:
                                  const Color(0xFFF59E0B).withOpacity(0.1),
                              onTap: () => _openScreen(
                                context,
                                const DriverEarningsScreen(),
                              ),
                            ),
                            _buildQuickActionCard(
                              context: context,
                              icon: Icons.share_outlined,
                              title: 'My Referral Link',
                              subtitle: 'Share your code and invite drivers',
                              onTap: () =>
                                  _openScreen(context, const ReferralLinkScreen()),
                            ),
                            _buildQuickActionCard(
                              context: context,
                              icon: Icons.groups_rounded,
                              title: 'My Referrals',
                              subtitle:
                                  'See all joined referrals and their status',
                              onTap: () =>
                                  _openScreen(context, const ReferralListScreen()),
                            ),
                            _buildQuickActionCard(
                              context: context,
                              icon: Icons.person_outline_rounded,
                              title: 'Profile',
                              subtitle: 'See your details and selfie',
                              onTap: () => _openScreen(
                                context,
                                const DriverProfileScreen(),
                              ),
                            ),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection(account.collection)
                                  .doc(account.uid)
                                  .collection('messages')
                                  .where('isRead', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, msgSnap) {
                                final unread = (msgSnap.data?.docs ?? [])
                                    .where((d) {
                                      final data = d.data() as Map<String, dynamic>;
                                      return data['isArchived'] != true;
                                    })
                                    .length;
                                return _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.mail_outline_rounded,
                                  title: 'Messages',
                                  subtitle: 'Open your driver inbox',
                                  badgeCount: unread,
                                  onTap: () => _openScreen(
                                    context,
                                    const MessagesInboxScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openScreen(
                                context,
                                const ReferralDevTesterScreen(),
                              ),
                              icon: const Icon(Icons.science_outlined, size: 18),
                              label: const Text('Dev: Create Test Entries'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
