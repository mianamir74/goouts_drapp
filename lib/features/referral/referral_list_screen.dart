import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auto_size_text/auto_size_text.dart';

Future<String> _resolveDriverCollection(String uid) async {
  final firestore = FirebaseFirestore.instance;
  final results = await Future.wait([
    firestore.collection('cab_drivers').doc(uid).get(),
    firestore.collection('businesses').doc(uid).get(),
  ]);
  if (results[0].exists) return 'cab_drivers';
  if (results[1].exists) return 'businesses';
  return 'drivers';
}

enum _InviteStatus {
  joined,
  pending,
  joinedElsewhere,
}

class ReferralListScreen extends StatefulWidget {
  const ReferralListScreen({super.key});

  @override
  State<ReferralListScreen> createState() => _ReferralListScreenState();
}

class _ReferralListScreenState extends State<ReferralListScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);
  static const Color _joinedGreen = Color(0xFF16A34A);
  static const Color _joinedGreenBg = Color(0xFFDCFCE7);
  static const Color _pendingAmber = Color(0xFFD97706);
  static const Color _pendingAmberBg = Color(0xFFFFF3D6);
  static const Color _elsewhereRed = Color(0xFFDC2626);
  static const Color _elsewhereRedBg = Color(0xFFFEE2E2);
  static const String _defaultDriverReferralCode = 'G01001';

  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReferralActivityViewed();
    });
  }

  Future<void> _markReferralActivityViewed() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final String collection = await _resolveDriverCollection(currentUser.uid);
      await FirebaseFirestore.instance.collection(collection).doc(currentUser.uid).set({
        'lastReferralActivityViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep screen usable even if badge-clear sync fails.
    }
  }

  String _readString(Map<String, dynamic>? data, List<String> keys, {String fallback = ''}) {
    if (data == null) return fallback;
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  DateTime? _readDateTime(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _titleCase(String value) {
    if (value.trim().isEmpty) return '';
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  String _generateDriverReferralCode(String uid) {
    final cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return _defaultDriverReferralCode;
    if (cleaned.length >= 5) return 'G${cleaned.substring(cleaned.length - 5)}';
    return 'G${cleaned.padLeft(5, '0')}';
  }

  String _resolveOwnReferralCode({
    required String uid,
    required Map<String, dynamic>? currentData,
  }) {
    final ownCode = _readString(
      currentData,
      const ['ownReferralCode', 'referralCode'],
    ).toUpperCase();
    if (ownCode.isNotEmpty) return ownCode;
    return _generateDriverReferralCode(uid);
  }

  _InviteStatus _resolveInviteStatus({
    required String status,
    required String joinedDriverUid,
    required String resolutionReason,
  }) {
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedReason = resolutionReason.trim().toLowerCase();

    if (normalizedStatus == 'joined_elsewhere' || normalizedReason == 'joined_elsewhere') {
      return _InviteStatus.joinedElsewhere;
    }
    if (normalizedStatus == 'joined' || joinedDriverUid.trim().isNotEmpty) {
      return _InviteStatus.joined;
    }
    return _InviteStatus.pending;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Date not available';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year · $hour:$minute';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendReminder(
    _ReferralInviteItem item, {
    required String collection,
    required String userId,
  }) async {
    if (item.phone.trim().isEmpty) {
      _showSnackBar('Phone number is missing for this invite');
      return;
    }

    final digits = item.phone.replaceAll(RegExp(r'[^0-9]'), '');
    String normalizedPhone = digits;
    if (digits.startsWith('07') && digits.length == 11) {
      normalizedPhone = '44${digits.substring(1)}';
    } else if (digits.startsWith('7') && digits.length == 10) {
      normalizedPhone = '44$digits';
    }

    if (normalizedPhone.isEmpty) {
      _showSnackBar('Could not normalise phone number');
      return;
    }

    final String message = item.inviteLink.trim().isNotEmpty
        ? 'Hi ${item.name},\n\nThis is a reminder to complete your GoOuts driver signup using referral code ${item.referralCode}.\n\n${item.inviteLink}'
        : 'Hi ${item.name},\n\nThis is a reminder to complete your GoOuts driver signup using referral code ${item.referralCode}.';

    // Try WhatsApp app directly first, then fall back to wa.me web link
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
      _showSnackBar('Could not open WhatsApp');
      return;
    }

    // Update Firestore reminder count and timestamp
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore
          .collection(collection)
          .doc(userId)
          .collection('sent_invites')
          .doc(item.inviteId);

      await docRef.set(
        <String, dynamic>{
          'reminderCount': FieldValue.increment(1),
          'lastReminderAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-critical — WhatsApp already opened, just log silently
    }
  }

  _ReferralInviteItem _mapInviteDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final name = _titleCase(
      _readString(data, const ['inviteeName', 'name'], fallback: 'Invitee'),
    );
    final phone = _readString(data, const ['inviteePhone', 'phone']);
    final city = _titleCase(_readString(data, const ['city', 'joinedDriverCity', 'inviteeCity']));
    final rawDate = _readDateTime(
      data,
      ['joinedAt', 'resolvedAt', 'sentAt', 'createdAt', 'updatedAt'],
    );
    final referralCode = _readString(data, ['referralCode']).toUpperCase();
    final inviteLink = _readString(data, ['inviteLink']);
    final status = _resolveInviteStatus(
      status: _readString(data, ['status']),
      joinedDriverUid: _readString(data, ['joinedDriverUid']),
      resolutionReason: _readString(data, ['resolutionReason']),
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
    required List<_ReferralInviteItem> allItems,
    required List<_ReferralInviteItem> joinedItems,
    required int pendingCount,
    required int elsewhereCount,
  }) {
    final totalCount = allItems.length;
    final joinedCount = joinedItems.length;
    final cityCount = allItems
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
            children: [
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText(
            'Driver Referral Summary',
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
            children: [
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
    required String collection,
    required String userId,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
          if (item.city.trim().isNotEmpty) ...[
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
          if (item.isPending) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _sendReminder(
                item,
                collection: collection,
                userId: userId,
              ),
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
    required String collection,
    required String userId,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                    ? 'Joined driver invites will appear here once registration is completed.'
                    : 'Saved driver invites that are still pending will appear here.',
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
      itemBuilder: (context, index) {
        return _buildInviteCard(
          item: items[index],
          collection: collection,
          userId: userId,
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

    return FutureBuilder<String>(
      future: _resolveDriverCollection(currentUser.uid),
      builder: (context, collectionSnapshot) {
        if (collectionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final String collection = collectionSnapshot.data ?? 'drivers';
        return _buildContent(context, currentUser, collection);
      },
    );
  }

  Widget _buildContent(BuildContext context, User currentUser, String collection) {
    final currentAccountRef = FirebaseFirestore.instance.collection(collection).doc(currentUser.uid);

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
        builder: (context, currentSnapshot) {
          if (currentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            );
          }

          final ownReferralCode = _resolveOwnReferralCode(
            uid: currentUser.uid,
            currentData: currentSnapshot.data?.data(),
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: currentAccountRef.collection('sent_invites').orderBy('sentAt', descending: true).snapshots(),
            builder: (context, invitesSnapshot) {
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

              final items = (invitesSnapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .map(_mapInviteDoc)
                  .toList();

              items.sort((a, b) {
                final aDate = a.rawDate;
                final bDate = b.rawDate;
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });

              final joinedItems = items.where((item) => item.status == _InviteStatus.joined).toList();
              final pendingSideItems = items.where((item) => item.status != _InviteStatus.joined).toList();
              final pendingCount = items.where((item) => item.status == _InviteStatus.pending).length;
              final elsewhereCount = items.where((item) => item.status == _InviteStatus.joinedElsewhere).length;
              final visibleItems = _selectedTabIndex == 0 ? joinedItems : pendingSideItems;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildSummaryCard(
                      ownReferralCode: ownReferralCode,
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
                          Expanded(
                            child: _buildTabButton(
                              title: 'Joined',
                              isSelected: _selectedTabIndex == 0,
                              onTap: () => setState(() => _selectedTabIndex = 0),
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              title: 'Pending & Elsewhere',
                              isSelected: _selectedTabIndex == 1,
                              onTap: () => setState(() => _selectedTabIndex = 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildReferralsList(
                      items: visibleItems,
                      collection: collection,
                      userId: currentUser.uid,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
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
