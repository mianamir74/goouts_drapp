import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auto_size_text/auto_size_text.dart';

enum _InviteStatus {
  joined,
  pending,
  joinedElsewhere,
}

class BusinessReferralListScreen extends StatefulWidget {
  const BusinessReferralListScreen({super.key});

  @override
  State<BusinessReferralListScreen> createState() => _BusinessReferralListScreenState();
}

class _BusinessReferralListScreenState extends State<BusinessReferralListScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);
  static const Color _joinedGreen = Color(0xFF16A34A);
  static const Color _joinedGreenBg = Color(0xFFDCFCE7);
  static const Color _pendingAmber = Color(0xFFD97706);
  static const Color _pendingAmberBg = Color(0xFFFFF3D6);
  static const Color _elsewhereRed = Color(0xFFDC2626);
  static const Color _elsewhereRedBg = Color(0xFFFEE2E2);

  late final Future<_CurrentAccount?> _accountFuture;

  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _accountFuture = _loadCurrentAccount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReferralActivityViewed();
    });
  }

  Future<_CurrentAccount?> _loadCurrentAccount() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return null;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final DocumentSnapshot<Map<String, dynamic>> driverDoc =
        await firestore.collection('drivers').doc(currentUser.uid).get();

    if (driverDoc.exists) {
      return _CurrentAccount(
        uid: currentUser.uid,
        collection: 'drivers',
        isBusiness: false,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> businessDoc =
        await firestore.collection('businesses').doc(currentUser.uid).get();

    if (businessDoc.exists) {
      return _CurrentAccount(
        uid: currentUser.uid,
        collection: 'businesses',
        isBusiness: true,
      );
    }

    return _CurrentAccount(
      uid: currentUser.uid,
      collection: 'drivers',
      isBusiness: false,
    );
  }

  Future<void> _markReferralActivityViewed() async {
    final _CurrentAccount? account = await _accountFuture;

    if (account == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(account.collection)
          .doc(account.uid)
          .set(
        <String, dynamic>{
          'lastReferralActivityViewedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Keep referral list usable even if badge-clear sync fails silently.
    }
  }

  String _readString(Map<String, dynamic>? data, List<String> keys, {String fallback = ''}) {
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

  DateTime? _readDateTime(Map<String, dynamic>? data, List<String> keys) {
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

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      if (value is String && value.trim().isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
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

  String _generateDriverReferralCode(String uid) {
    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    if (cleaned.isEmpty) {
      return 'GO1001';
    }

    if (cleaned.length >= 6) {
      return 'GO${cleaned.substring(cleaned.length - 6)}';
    }

    return 'GO${cleaned.padLeft(6, '0')}';
  }

  String _generateBusinessReferralCode(String uid) {
    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    if (cleaned.isEmpty) {
      return 'BG0001';
    }

    if (cleaned.length >= 4) {
      return 'BG${cleaned.substring(cleaned.length - 4)}';
    }

    return 'BG${cleaned.padLeft(4, '0')}';
  }

  String _resolveOwnReferralCode({
    required String uid,
    required Map<String, dynamic>? currentData,
    required bool isBusiness,
  }) {
    final String ownCode = _readString(
      currentData,
      const <String>['ownReferralCode', 'referralCode'],
    ).toUpperCase();

    if (ownCode.isNotEmpty) {
      return ownCode;
    }

    return isBusiness
        ? _generateBusinessReferralCode(uid)
        : _generateDriverReferralCode(uid);
  }

  _InviteStatus _resolveInviteStatus({
    required String status,
    required String joinedDriverUid,
    required String resolutionReason,
  }) {
    final String normalizedStatus = status.trim().toLowerCase();
    final String normalizedReason = resolutionReason.trim().toLowerCase();

    if (normalizedStatus == 'joined_elsewhere' ||
        normalizedStatus == 'joined elsewhere' ||
        normalizedReason == 'joined_with_other_referrer') {
      return _InviteStatus.joinedElsewhere;
    }

    if (normalizedStatus == 'joined' ||
        normalizedStatus == 'live' ||
        normalizedStatus == 'registered' ||
        normalizedStatus == 'active') {
      return _InviteStatus.joined;
    }

    if (joinedDriverUid.trim().isNotEmpty) {
      return _InviteStatus.joined;
    }

    return _InviteStatus.pending;
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown time';
    }

    const List<String> months = <String>[
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

    final int hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.day} ${months[dateTime.month - 1]}, $hour:$minute $period';
  }

  String _normalizePhoneForWhatsApp(String phone) {
    final String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');

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

  String _buildReminderMessage({
    required String referralName,
    required String referralCode,
    required String inviteLink,
    required bool isBusiness,
  }) {
    final String safeName = referralName.trim().isEmpty ? 'there' : referralName.trim();

    if (isBusiness) {
      if (inviteLink.trim().isEmpty) {
        return 'Hi $safeName,\n\n'
            'I’d like to remind you about joining GoOuts as a delivery driver.\n\n'
            'Please use my business partner referral code during registration:\n\n'
            '$referralCode';
      }

      return 'Hi $safeName,\n\n'
          'I’d like to remind you about joining GoOuts as a delivery driver.\n\n'
          'Please use my business partner referral code during registration:\n\n'
          '$referralCode\n\n'
          'Complete your signup here:\n'
          '$inviteLink';
    }

    if (inviteLink.trim().isEmpty) {
      return 'Hi $safeName,\n\n'
          'This is a reminder to join GoOuts Food Delivery.\n\n'
          'Please use my referral code during registration:\n\n'
          '$referralCode';
    }

    return 'Hi $safeName,\n\n'
        'This is a reminder to join GoOuts Food Delivery.\n\n'
        'Please use my referral code during registration:\n\n'
        '$referralCode\n\n'
        'Complete your signup here:\n'
        '$inviteLink';
  }

  Future<void> _sendReminder({
    required _ReferralInviteItem item,
    required _CurrentAccount account,
  }) async {
    if (!item.isPending) {
      return;
    }

    final String normalizedPhone = _normalizePhoneForWhatsApp(item.phone);

    if (normalizedPhone.isEmpty) {
      _showSnackBar('Phone number is not available for this invite.');
      return;
    }

    final String message = _buildReminderMessage(
      referralName: item.name,
      referralCode: item.referralCode,
      inviteLink: item.inviteLink,
      isBusiness: account.isBusiness,
    );

    final Uri whatsappUri = Uri.parse(
      'whatsapp://send?phone=$normalizedPhone&text=${Uri.encodeComponent(message)}',
    );
    final Uri webUri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );

    bool launched = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      launched = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    }

    if (!launched) {
      _showSnackBar('Could not open WhatsApp reminder.');
      return;
    }

    if (item.inviteId.trim().isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(account.collection)
          .doc(account.uid)
          .collection('sent_invites')
          .doc(item.inviteId)
          .set(
        <String, dynamic>{
          'lastReminderAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reminderCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Keep reminder flow usable even if stats update fails silently.
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  _ReferralInviteItem _mapInviteDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();

    final String name = _titleCase(
      _readString(data, const <String>['inviteeName', 'name'], fallback: 'Invitee'),
    );

    final String phone = _readString(
      data,
      const <String>['inviteePhone', 'phone'],
    );

    final String city = _titleCase(
      _readString(data, const <String>['city', 'joinedDriverCity', 'inviteeCity']),
    );

    final DateTime? rawDate = _readDateTime(
      data,
      const <String>['joinedAt', 'resolvedAt', 'sentAt', 'createdAt', 'updatedAt'],
    );

    final String referralCode = _readString(
      data,
      const <String>['referralCode'],
    ).toUpperCase();

    final String inviteLink = _readString(
      data,
      <String>['inviteLink'],
    );

    final _InviteStatus status = _resolveInviteStatus(
      status: _readString(data, <String>['status']),
      joinedDriverUid: _readString(data, <String>['joinedDriverUid']),
      resolutionReason: _readString(data, <String>['resolutionReason']),
    );

    return _ReferralInviteItem(
      inviteId: doc.id,
      name: name,
      phone: phone,
      city: city,
      dateText: _formatDateTime(rawDate),
      status: status,
      rawDate: rawDate,
      referralCode: referralCode,
      inviteLink: inviteLink,
    );
  }

  Widget _buildSummaryCard({
    required String ownReferralCode,
    required bool isBusiness,
    required List<_ReferralInviteItem> allItems,
    required List<_ReferralInviteItem> joinedItems,
    required int pendingCount,
    required int elsewhereCount,
  }) {
    final int totalCount = allItems.length;
    final int joinedCount = joinedItems.length;
    final int cityCount = allItems
        .map((i) => i.city.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;

    Widget countTile(String label, int value) {
      return Expanded(
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: _screenBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AutoSizeText(
            isBusiness ? 'Business Referral Summary' : 'Referral Summary',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          AutoSizeText(
            'Your referral code: $ownReferralCode',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              countTile('Total', totalCount),
              const SizedBox(width: 6),
              countTile('Joined', joinedCount),
              const SizedBox(width: 6),
              countTile('Pending', pendingCount + elsewhereCount),
              const SizedBox(width: 6),
              countTile('Cities', cityCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _goOutsBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(_InviteStatus status) {
    switch (status) {
      case _InviteStatus.joined:
        return _joinedGreen;
      case _InviteStatus.joinedElsewhere:
        return _elsewhereRed;
      case _InviteStatus.pending:
        return _pendingAmber;
    }
  }

  Color _statusBackground(_InviteStatus status) {
    switch (status) {
      case _InviteStatus.joined:
        return _joinedGreenBg;
      case _InviteStatus.joinedElsewhere:
        return _elsewhereRedBg;
      case _InviteStatus.pending:
        return _pendingAmberBg;
    }
  }

  String _statusLabel(_InviteStatus status) {
    switch (status) {
      case _InviteStatus.joined:
        return 'Joined';
      case _InviteStatus.joinedElsewhere:
        return 'Joined Elsewhere';
      case _InviteStatus.pending:
        return 'Pending';
    }
  }

  Widget _buildInviteCard({
    required _ReferralInviteItem item,
    required _CurrentAccount account,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusBackground(item.status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(item.status),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (item.phone.trim().isNotEmpty)
            AutoSizeText(
              item.phone,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          if (item.city.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: 4),
            AutoSizeText(
              item.city,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
          SizedBox(height: 8),
          AutoSizeText(
            item.dateText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          AutoSizeText(
            'Referral code: ${item.referralCode}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.isPending) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _sendReminder(item: item, account: account),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Send Reminder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _goOutsBlue,
                side: const BorderSide(color: _goOutsBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferralsList({
    required List<_ReferralInviteItem> items,
    required _CurrentAccount account,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _goOutsBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: _goOutsBlue,
                  size: 34,
                ),
              ),
              SizedBox(height: 16),
              AutoSizeText(
                _selectedTabIndex == 0 ? 'No joined referrals yet' : 'No pending referrals yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              AutoSizeText(
                _selectedTabIndex == 0
                    ? 'Joined invites will appear here once registration is completed.'
                    : account.isBusiness
                        ? 'Saved business invites that are still pending will appear here.'
                        : 'Saved business invites that are still pending will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildInviteCard(
          item: items[index],
          account: account,
        );
      },
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

        final DocumentReference<Map<String, dynamic>> currentAccountRef =
            FirebaseFirestore.instance.collection(account.collection).doc(account.uid);

        return Scaffold(
          backgroundColor: _screenBackground,
          appBar: AppBar(
            backgroundColor: _goOutsBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'My Referrals',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: currentAccountRef.snapshots(),
            builder: (BuildContext context,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> currentSnapshot) {
              if (currentSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _goOutsBlue),
                );
              }

              final String ownReferralCode = _resolveOwnReferralCode(
                uid: account.uid,
                currentData: currentSnapshot.data?.data(),
                isBusiness: account.isBusiness,
              );

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: currentAccountRef
                    .collection('sent_invites')
                    .orderBy('sentAt', descending: true)
                    .snapshots(),
                builder: (BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> invitesSnapshot) {
                  if (invitesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _goOutsBlue),
                    );
                  }

                  if (invitesSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Failed to load referrals.\n${invitesSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                    );
                  }

                  final List<_ReferralInviteItem> items =
                      (invitesSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map(_mapInviteDoc)
                          .toList();

                  items.sort((a, b) {
                    final DateTime? aDate = a.rawDate;
                    final DateTime? bDate = b.rawDate;

                    if (aDate == null && bDate == null) {
                      return 0;
                    }
                    if (aDate == null) {
                      return 1;
                    }
                    if (bDate == null) {
                      return -1;
                    }
                    return bDate.compareTo(aDate);
                  });

                  final List<_ReferralInviteItem> joinedItems = items
                      .where((item) => item.status == _InviteStatus.joined)
                      .toList();

                  final List<_ReferralInviteItem> pendingSideItems = items
                      .where((item) => item.status != _InviteStatus.joined)
                      .toList();

                  final int pendingCount = items
                      .where((item) => item.status == _InviteStatus.pending)
                      .length;

                  final int elsewhereCount = items
                      .where((item) => item.status == _InviteStatus.joinedElsewhere)
                      .length;

                  final List<_ReferralInviteItem> visibleItems =
                      _selectedTabIndex == 0 ? joinedItems : pendingSideItems;

                  return Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: _buildSummaryCard(
                          ownReferralCode: ownReferralCode,
                          isBusiness: account.isBusiness,
                          allItems: items,
                          joinedItems: joinedItems,
                          pendingCount: pendingCount,
                          elsewhereCount: elsewhereCount,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: <Widget>[
                              _buildTabButton(
                                title: 'Joined',
                                isSelected: _selectedTabIndex == 0,
                                onTap: () {
                                  setState(() {
                                    _selectedTabIndex = 0;
                                  });
                                },
                              ),
                              _buildTabButton(
                                title: 'Pending',
                                isSelected: _selectedTabIndex == 1,
                                onTap: () {
                                  setState(() {
                                    _selectedTabIndex = 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildReferralsList(
                          items: visibleItems,
                          account: account,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
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

class _ReferralInviteItem {
  final String inviteId;
  final String name;
  final String phone;
  final String city;
  final String dateText;
  final _InviteStatus status;
  final DateTime? rawDate;
  final String referralCode;
  final String inviteLink;

  const _ReferralInviteItem({
    required this.inviteId,
    required this.name,
    required this.phone,
    required this.city,
    required this.dateText,
    required this.status,
    required this.rawDate,
    required this.referralCode,
    required this.inviteLink,
  });

  bool get isPending => status == _InviteStatus.pending;
}
