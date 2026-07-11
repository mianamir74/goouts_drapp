import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:flutter/material.dart';

    class BusinessMessagesInboxScreen extends StatefulWidget {
      const BusinessMessagesInboxScreen({super.key});

      @override
      State<BusinessMessagesInboxScreen> createState() =>
          _BusinessMessagesInboxScreenState();
    }

    class _BusinessMessagesInboxScreenState extends State<BusinessMessagesInboxScreen> {
      static const Color _goOutsBlue = Color(0xFF0392CA);
      static const Color _screenBackground = Color(0xFFF2F3F7);

      String _searchQuery = '';

      @override
      void initState() {
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markAllMessagesAsRead();
        });
      }

      Future<void> _markAllMessagesAsRead() async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return;
        }

        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('businesses')
              .doc(currentUser.uid)
              .collection('messages')
              .get();

          final unreadDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            final value = data['isRead'] ?? data['read'] ?? data['seen'];
            return value != true;
          }).toList();

          if (unreadDocs.isEmpty) {
            return;
          }

          final batch = FirebaseFirestore.instance.batch();
          for (final doc in unreadDocs) {
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
          await batch.commit();
        } catch (_) {}
      }

      String _readString(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
        return '';
      }

      DateTime? _readDateTime(Map<String, dynamic> data) {
        final value = data['createdAt'] ?? data['sentAt'] ?? data['updatedAt'];
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
      }

      String _formatTime(DateTime? value) {
        if (value == null) return 'Now';
        final now = DateTime.now();
        final diff = now.difference(value);
        if (diff.inMinutes < 1) return 'Now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m';
        if (diff.inHours < 24 &&
            now.day == value.day &&
            now.month == value.month &&
            now.year == value.year) {
          final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
          final minute = value.minute.toString().padLeft(2, '0');
          final period = value.hour >= 12 ? 'PM' : 'AM';
          return '$hour:$minute $period';
        }
        return '${value.day}/${value.month}/${value.year}';
      }

      @override
      Widget build(BuildContext context) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return const Scaffold(
            body: Center(child: Text('No logged-in business user found.')),
          );
        }

        return Scaffold(
          backgroundColor: _screenBackground,
          appBar: AppBar(
            backgroundColor: _goOutsBlue,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: const Text(
              'Messages',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search messages',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(currentUser.uid)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
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
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final filtered = docs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data();
                      final blob = [
                        _readString(data, const <String>['title', 'subject']),
                        _readString(data, const <String>['body', 'message', 'content']),
                        _readString(data, const <String>['senderName', 'fromName']),
                      ].join(' ').toLowerCase();
                      return blob.contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Messages sent to this business account will show here.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = filtered[index].data();
                        final title = _readString(data, const <String>['title', 'subject']);
                        final preview = _readString(data, const <String>['preview', 'body', 'message', 'content']);
                        final senderName = _readString(data, const <String>['senderName', 'fromName', 'from']);
                        final createdAt = _readDateTime(data);
                        final body = _readString(data, const <String>['body', 'message', 'content', 'preview']);

                        return InkWell(
                          onTap: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(title.isEmpty ? 'Message' : title),
                                content: SingleChildScrollView(
                                  child: Text(body.isEmpty ? preview : body),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x11000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
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
                                        title.isEmpty ? 'Message' : title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                    AutoSizeText(
                                      _formatTime(createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (senderName.isNotEmpty) ...<Widget>[
                                  SizedBox(height: 6),
                                  AutoSizeText(
                                    senderName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _goOutsBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                SizedBox(height: 8),
                                AutoSizeText(
                                  preview.isEmpty ? 'Open to view message details.' : preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: Color(0xFF4B5563),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    }
