import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/login_screen.dart';
import '../legal/terms_and_conditions_screen.dart';
import '../messages/business_messages_inbox_screen.dart';
import '../profile/business_profile_screen.dart';
import '../legal/faq_screen.dart';
import '../referral/business_referral_link_screen.dart';
import '../referral/business_referral_list_screen.dart';
import '../referral/referral_dev_tester_screen.dart';
import '../support/help_support_screen.dart';
import '../../main.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _pageBackground = Colors.white;
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder = Color(0xFFE8EEF3);
  static const Color _softBlueTint = Color(0xFFF4FAFD);

  User? get _user => FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  String _displayName = 'Business Partner';
  String _referralCode = 'BG0001';
  String _accountStatus = '';
  int _unreadMessagesCount = 0;
  int _referralActivityCount = 0;
  int _totalReferralsCount = 0;
  DateTime? _lastViewedAt;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final User? user = _user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentSnapshot<Map<String, dynamic>> businessDoc =
          await firestore.collection('businesses').doc(user.uid).get();
      final Map<String, dynamic> businessData =
          businessDoc.data() ?? <String, dynamic>{};

      _displayName = _businessDisplayName(businessData, user);
      _accountStatus = (businessData['status'] ?? '').toString();
      _referralCode =
          (businessData['ownReferralCode'] ?? businessData['referralCode'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
      if (_referralCode.isEmpty) {
        _referralCode = 'BG0001';
      }

      _lastViewedAt =
          _readDateTime(businessData, const ['lastReferralActivityViewedAt']);

      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot = await firestore
          .collection('businesses')
          .doc(user.uid)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();
      _unreadMessagesCount = _getUnreadMessagesCount(messagesSnapshot.docs);

      final QuerySnapshot<Map<String, dynamic>> referralsSnapshot = await firestore
          .collection('businesses')
          .doc(user.uid)
          .collection('sent_invites')
          .orderBy('sentAt', descending: true)
          .get();
      _totalReferralsCount = referralsSnapshot.docs.length;
      _referralActivityCount =
          _getReferralActivityCount(referralsSnapshot.docs, _lastViewedAt);
    } catch (_) {}

    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _loadDashboard());
  }

  void _copyReferralCode(BuildContext context, String referralCode) {
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
            'accountType': 'business',
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

  void _openMenu(BuildContext context) {
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
                  _openScreen(context, const BusinessProfileScreen());
                },
              ),
              _menuTile(
                icon: Icons.share_outlined,
                title: 'My Referral Code',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openScreen(context, const BusinessReferralLinkScreen());
                },
              ),
              if (kDebugMode)
              _menuTile(
                icon: Icons.slideshow_outlined,
                title: 'Intro Slides',
                 onTap: () {
                    Navigator.pop(sheetContext);
                    _openScreen(
                    context,
                    RoleIntroSlidesScreen(
                    accountType: 'business',
                    openedFromMenu: true,
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
                    const HelpSupportScreen(
                      accountType: 'business',
                      collectionName: 'businesses',
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
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

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

  bool _readBool(Map<String, dynamic> data, List<String> keys,
      {bool fallback = false}) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value is bool) return value;
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      if (value is num) return value != 0;
    }
    return fallback;
  }

  DateTime? _readDateTime(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value == null) continue;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _businessDisplayName(Map<String, dynamic>? data, User user) {
    final String fullName = _titleCase((data?['fullName'] ?? '').toString());
    if (fullName.isNotEmpty) return fullName;
    final String contactPersonName =
        _titleCase((data?['contactPersonName'] ?? '').toString());
    if (contactPersonName.isNotEmpty) return contactPersonName;
    final String firstName = _titleCase((data?['firstName'] ?? '').toString());
    final String surname = _titleCase((data?['surname'] ?? '').toString());
    final String combined = '$firstName $surname'.trim();
    if (combined.isNotEmpty) return combined;
    final String legalBusinessName =
        _titleCase((data?['legalBusinessName'] ?? '').toString());
    if (legalBusinessName.isNotEmpty) return legalBusinessName;
    return user.phoneNumber ?? 'Business Partner';
  }

  int _getUnreadMessagesCount(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
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
    if (lastViewedAt == null) return docs.length;
    int activityCount = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final DateTime? activityDate =
          _readDateTime(doc.data(), ['resolvedAt', 'joinedAt', 'updatedAt', 'sentAt']);
      if (activityDate != null && activityDate.isAfter(lastViewedAt)) {
        activityCount++;
      }
    }
    return activityCount;
  }

  Widget _sectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 4),
        AutoSizeText(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
          ),
        ),
      ],
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

  Widget _welcomeCard({
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
            'Manage your business profile, messages and referrals from one place.',
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
                        referralCode.isEmpty ? 'BG0001' : referralCode,
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
                    referralCode.isEmpty ? 'BG0001' : referralCode,
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
                  label: 'Total Referrals Details',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStatCard(
                  icon: Icons.notifications_active_outlined,
                  value: referralActivityCount.toString(),
                  label: 'New Referral Activity',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String accentLabel,
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _softBlueTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _goOutsBlue),
                ),
                Spacer(),
                Container(
                  clipBehavior: Clip.antiAlias,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _softBlueTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badgeCount > 0 ? '$accentLabel • $badgeCount' : accentLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _goOutsBlue,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('No logged-in business user found.')),
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
          'GoOuts Business Partner',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _openMenu(context),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _welcomeCard(
                      context: context,
                      name: _displayName,
                      referralCode: _referralCode,
                      unreadMessagesCount: _unreadMessagesCount,
                      referralActivityCount: _referralActivityCount,
                      totalReferralsCount: _totalReferralsCount,
                      accountStatus: _accountStatus,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      decoration: BoxDecoration(
                        color: _softBlueTint,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _softBorder),
                      ),
                      child: _sectionTitle(
                        title: 'Quick Actions',
                        subtitle:
                            'Everything important for your business account is here.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount:
                          MediaQuery.of(context).size.width < 360 ? 1 : 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      childAspectRatio:
                          MediaQuery.of(context).size.width < 360 ? 1.55 : 1.0,
                      children: [
                        _actionCard(
                          context: context,
                          title: 'My Referral Link',
                          subtitle:
                              'Share your code and invite business contacts',
                          accentLabel: 'Share',
                          icon: Icons.share_outlined,
                          onTap: () => _openScreen(
                            context,
                            const BusinessReferralLinkScreen(),
                          ),
                        ),
                        _actionCard(
                          context: context,
                          title: 'My Referrals',
                          subtitle:
                              'See joined referrals and their latest status',
                          accentLabel:
                              _referralActivityCount > 0 ? 'New' : 'Track',
                          icon: Icons.group_outlined,
                          badgeCount: _referralActivityCount,
                          onTap: () => _openScreen(
                            context,
                            const BusinessReferralListScreen(),
                          ),
                        ),
                        _actionCard(
                          context: context,
                          title: 'Business Profile',
                          subtitle: 'See your business details',
                          accentLabel: 'Account',
                          icon: Icons.business_center_outlined,
                          onTap: () => _openScreen(
                            context,
                            const BusinessProfileScreen(),
                          ),
                        ),
                        _actionCard(
                          context: context,
                          title: 'Messages',
                          subtitle: 'Open your business inbox',
                          accentLabel: _unreadMessagesCount > 0 ? 'New' : 'Inbox',
                          icon: Icons.mail_outline_rounded,
                          badgeCount: _unreadMessagesCount,
                          onTap: () => _openScreen(
                            context,
                            const BusinessMessagesInboxScreen(),
                          ),
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
    );
  }
}
