import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'message_detail_screen.dart';
import '../support/my_tickets_button.dart';
import 'package:auto_size_text/auto_size_text.dart';

class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);

  late final Future<_CurrentAccount?> _accountFuture;

  int _selectedTabIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _accountFuture = _loadCurrentAccount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllMessagesAsRead();
    });
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

  Future<void> _markAllMessagesAsRead() async {
    final _CurrentAccount? account = await _accountFuture;

    if (account == null) {
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> messagesSnapshot =
          await FirebaseFirestore.instance
              .collection(account.collection)
              .doc(account.uid)
              .collection('messages')
              .get();

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      bool hasUnread = false;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in messagesSnapshot.docs) {
        final bool isRead = _readBool(
          doc.data(),
          const <String>['isRead', 'read', 'seen'],
          fallback: false,
        );

        if (!isRead) {
          hasUnread = true;
          batch.set(
            doc.reference,
            <String, dynamic>{
              'isRead': true,
              'read': true,
              'seen': true,
              'readAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      if (hasUnread) {
        await batch.commit();
      }
    } catch (_) {
      // Keep inbox usable even if read status sync fails silently.
    }
  }

  String _formatListDate(DateTime? value) {
    if (value == null) {
      return 'Unknown date';
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

    final int hour24 = value.hour;
    final int hour12 = hour24 == 0
        ? 12
        : hour24 > 12
            ? hour24 - 12
            : hour24;
    final String minute = value.minute.toString().padLeft(2, '0');
    final String period = hour24 >= 12 ? 'PM' : 'AM';

    return '${value.day} ${months[value.month - 1]} · $hour12:$minute $period';
  }

  String _formatDetailDateTime(DateTime? value) {
    if (value == null) {
      return 'Unknown date';
    }

    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final int hour24 = value.hour;
    final int hour12 = hour24 == 0
        ? 12
        : hour24 > 12
            ? hour24 - 12
            : hour24;
    final String minute = value.minute.toString().padLeft(2, '0');
    final String period = hour24 >= 12 ? 'PM' : 'AM';

    return '${value.day} ${months[value.month - 1]} ${value.year} · $hour12:$minute $period';
  }

  _InboxMessage _buildMessage(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();

    final String title = _readString(
      data,
      const <String>['title', 'subject', 'heading'],
      fallback: 'GoOuts Message',
    );

    final String body = _readString(
      data,
      const <String>['body', 'message', 'content', 'text'],
      fallback: 'No message content available.',
    );

    final String preview = _readString(
      data,
      const <String>['preview', 'snippet', 'summary'],
      fallback: body.replaceAll('\n', ' '),
    );

    final String senderName = _readString(
      data,
      const <String>['senderName', 'fromName', 'sender'],
      fallback: 'GoOuts Admin',
    );

    final DateTime? createdAt = _readDateTime(
      data,
      const <String>['createdAt', 'sentAt', 'timestamp', 'updatedAt'],
    );

    final bool isRead = _readBool(
      data,
      const <String>['isRead', 'read', 'seen'],
      fallback: false,
    );

    final bool isArchived = _readBool(
      data,
      const <String>['isArchived'],
      fallback: false,
    );

    return _InboxMessage(
      id: doc.id,
      senderName: senderName,
      title: title,
      preview: preview,
      body: body,
      createdAt: createdAt,
      isRead: isRead,
      isArchived: isArchived,
      imageUrl: _readString(data, const <String>['imageUrl']),
      imageName: _readString(data, const <String>['imageName']),
      attachmentUrl: _readString(data, const <String>['attachmentUrl']),
      attachmentName: _readString(data, const <String>['attachmentName']),
      attachmentMimeType: _readString(data, const <String>['attachmentMimeType']),
      attachmentType: _readString(data, const <String>['attachmentType']),
    );
  }

  List<_InboxMessage> _filterMessages(List<_InboxMessage> messages) {
    // Always hide archived messages from main view
    List<_InboxMessage> filtered = messages.where((m) => !m.isArchived).toList();

    if (_selectedTabIndex == 1) {
      filtered = filtered.where((message) => !message.isRead).toList();
    }

    final String query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((message) {
        return message.title.toLowerCase().contains(query) ||
            message.preview.toLowerCase().contains(query) ||
            message.body.toLowerCase().contains(query) ||
            message.senderName.toLowerCase().contains(query) ||
            message.imageName.toLowerCase().contains(query) ||
            message.attachmentName.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  void _openMessageDetail({
    required BuildContext context,
    required String userId,
    required _InboxMessage message,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageDetailScreen(
          userId: userId,
          messageId: message.id,
          senderName: message.senderName,
          title: message.title,
          body: message.body,
          createdAtLabel: _formatDetailDateTime(message.createdAt),
          isRead: message.isRead,
          imageUrl: message.imageUrl,
          imageName: message.imageName,
          attachmentUrl: message.attachmentUrl,
          attachmentName: message.attachmentName,
          attachmentMimeType: message.attachmentMimeType,
          attachmentType: message.attachmentType,
        ),
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

  Widget _buildTopSummary({
    required bool isBusiness,
    required int allCount,
    required int unreadCount,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
            'Messages',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          AutoSizeText(
            '$allCount total messages · $unreadCount unread',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 10),
          AutoSizeText(
            isBusiness
                ? 'Messages sent to this business partner account will appear here.'
                : 'Messages sent to this driver account will appear here.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (String value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search messages',
        prefixIcon: Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isBusiness, required bool isUnreadView}) {
    final String title = isUnreadView ? 'No unread messages' : 'No messages available yet';
    final String description = isUnreadView
        ? 'New unread messages from GoOuts admin will appear here.'
        : isBusiness
            ? 'Messages for this business partner account will show here once sent.'
            : 'Messages for this driver account will show here once sent.';

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
                Icons.mark_email_read_outlined,
                color: _goOutsBlue,
                size: 34,
              ),
            ),
            SizedBox(height: 16),
            AutoSizeText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            AutoSizeText(
              description,
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

  // ── Swipe actions ────────────────────────────────────────────────────────────

  Future<void> _archiveMessage({
    required String collection,
    required String userId,
    required String messageId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(userId)
        .collection('messages')
        .doc(messageId)
        .set({'isArchived': true}, SetOptions(merge: true));
  }

  Future<void> _unarchiveMessage({
    required String collection,
    required String userId,
    required String messageId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(userId)
        .collection('messages')
        .doc(messageId)
        .set({'isArchived': false}, SetOptions(merge: true));
  }

  Future<void> _deleteMessage({
    required String collection,
    required String userId,
    required String messageId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(userId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // ── Message tile with swipe-to-archive / swipe-to-delete ─────────────────────

  Widget _buildSwipeableTile({
    required BuildContext context,
    required _CurrentAccount account,
    required _InboxMessage message,
  }) {
    return Dismissible(
      key: ValueKey(message.id),
      direction: DismissDirection.horizontal,

      // Swipe RIGHT → Archive (teal background)
      background: Container(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0891B2),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text('Archive', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),

      // Swipe LEFT → Delete (red background)
      secondaryBackground: Container(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),

      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Archive — no confirmation needed
          return true;
        }
        // Delete — confirm
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Delete message?', style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text('This will permanently remove the message from your inbox.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },

      onDismissed: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Archive
          await _archiveMessage(
            collection: account.collection,
            userId: account.uid,
            messageId: message.id,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Message archived'),
                backgroundColor: const Color(0xFF0891B2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: Colors.white,
                  onPressed: () => _unarchiveMessage(
                    collection: account.collection,
                    userId: account.uid,
                    messageId: message.id,
                  ),
                ),
              ),
            );
          }
        } else {
          // Delete
          await _deleteMessage(
            collection: account.collection,
            userId: account.uid,
            messageId: message.id,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Message deleted'),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      },

      child: _buildMessageTile(
        context: context,
        userId: account.uid,
        message: message,
      ),
    );
  }

  Widget _buildMessageTile({
    required BuildContext context,
    required String userId,
    required _InboxMessage message,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openMessageDetail(
        context: context,
        userId: userId,
        message: message,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: message.isRead ? Colors.transparent : _goOutsBlue.withOpacity(0.35),
          ),
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
                    message.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!message.isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _goOutsBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AutoSizeText(
              message.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AutoSizeText(
                  _formatListDate(message.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
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

        final CollectionReference<Map<String, dynamic>> messagesRef =
            FirebaseFirestore.instance
                .collection(account.collection)
                .doc(account.uid)
                .collection('messages');

        return Scaffold(
          backgroundColor: _screenBackground,
          appBar: AppBar(
            backgroundColor: _goOutsBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Messages',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: const [
              MyTicketsButton(invertColors: true),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: messagesRef.orderBy('createdAt', descending: true).snapshots(),
            builder: (BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _goOutsBlue),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load messages.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                );
              }

              final List<_InboxMessage> messages = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .map(_buildMessage)
                  .toList();

              final int unreadCount = messages.where((message) => !message.isRead).length;
              final List<_InboxMessage> visibleMessages = _filterMessages(messages);

              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildTopSummary(
                      isBusiness: account.isBusiness,
                      allCount: messages.length,
                      unreadCount: unreadCount,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildSearchField(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: <Widget>[
                          _buildTabButton(
                            title: 'All',
                            isSelected: _selectedTabIndex == 0,
                            onTap: () {
                              setState(() {
                                _selectedTabIndex = 0;
                              });
                            },
                          ),
                          _buildTabButton(
                            title: 'Unread',
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
                    child: visibleMessages.isEmpty
                        ? _buildEmptyState(
                            isBusiness: account.isBusiness,
                            isUnreadView: _selectedTabIndex == 1,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: visibleMessages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final _InboxMessage message = visibleMessages[index];
                              return _buildSwipeableTile(
                                context: context,
                                account: account,
                                message: message,
                              );
                            },
                          ),
                  ),
                ],
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

class _InboxMessage {
  final String id;
  final String senderName;
  final String title;
  final String preview;
  final String body;
  final DateTime? createdAt;
  final bool isRead;
  final bool isArchived;
  final String imageUrl;
  final String imageName;
  final String attachmentUrl;
  final String attachmentName;
  final String attachmentMimeType;
  final String attachmentType;

  const _InboxMessage({
    required this.id,
    required this.senderName,
    required this.title,
    required this.preview,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.isArchived,
    required this.imageUrl,
    required this.imageName,
    required this.attachmentUrl,
    required this.attachmentName,
    required this.attachmentMimeType,
    required this.attachmentType,
  });
}
