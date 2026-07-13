import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';

class SupportTicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final String ticketNumber;
  final String driverName;
  final String sourceCollection;

  const SupportTicketChatScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.ticketNumber,
    required this.driverName,
    required this.sourceCollection,
  });

  @override
  State<SupportTicketChatScreen> createState() => _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState extends State<SupportTicketChatScreen> {
  static const Color _goOutsBlue  = Color(0xFF0392CA);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _softBorder  = Color(0xFFE8EEF3);
  static const Color _bgGrey      = Color(0xFFF2F3F7);

  final TextEditingController _replyCtrl      = TextEditingController();
  final ScrollController       _scrollCtrl    = ScrollController();
  final FocusNode              _replyFocus    = FocusNode();
  final ImagePicker            _picker        = ImagePicker();

  bool   _sending    = false;
  bool   _uploading  = false;
  String _ticketStatus = 'new';

  @override
  void initState() {
    super.initState();
    _markMessagesRead();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _focusReplyField() {
    _replyFocus.requestFocus();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markMessagesRead() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .collection('messages')
          .where('sender', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .update({'unreadByDriver': false});
    } catch (_) {}
  }

  Future<void> _sendMessage({String text = '', String imageUrl = ''}) async {
    if (text.trim().isEmpty && imageUrl.isEmpty) return;
    if (_ticketStatus == 'closed' || _ticketStatus == 'resolved') return;

    setState(() => _sending = true);
    try {
      final messageText = text.trim().isEmpty ? '📎 Image attached' : text.trim();

      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'sender':     'driver',
        'senderName': widget.driverName,
        'text':       text.trim(),
        'imageUrl':   imageUrl,
        'isRead':     false,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .update({
        'lastMessage':   messageText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': 'driver',
        'unreadByAdmin': true,
        'status':        _ticketStatus == 'closed' ? 'closed' : 'in_progress',
        'updatedAt':     FieldValue.serverTimestamp(),
      });

      _replyCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        GoOutsSheet.error(context, title: 'Send Failed', message: 'Failed to send: $e');
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: _goOutsBlue),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _goOutsBlue),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (source == null) return;

    final XFile? picked = await _picker.pickImage(
      source: source, imageQuality: 70, maxWidth: 1200);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final fileName = 'support_${widget.ticketId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref('support_attachments/${widget.ticketId}/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _sendMessage(imageUrl: url);
    } catch (e) {
      if (mounted) {
        GoOutsSheet.error(context, title: 'Upload Failed', message: 'Upload failed: $e');
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _markResolved() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Mark as Resolved'),
        content: const Text(
          'Are you happy that your issue has been resolved?\n\n'
          'This will close the ticket.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, keep open')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, resolved')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Add closing message to thread
      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'sender':     'driver',
        'senderName': widget.driverName,
        'text':       '✅ Driver confirmed issue resolved. Ticket closed.',
        'imageUrl':   '',
        'isRead':     false,
        'createdAt':  FieldValue.serverTimestamp(),
        'isSystemMessage': true,
      });

      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .update({
        'status':        'resolved',
        'resolvedAt':    FieldValue.serverTimestamp(),
        'resolvedBy':    'driver',
        'unreadByAdmin': true,
        'updatedAt':     FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _ticketStatus = 'resolved');
        // Show rating sheet after closing
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _showRatingSheet();
      }
    } catch (e) {
      if (mounted) {
        GoOutsSheet.error(context, title: 'Error', message: 'Error: $e');
      }
    }
  }

  Future<void> _showRatingSheet() async {
    int selectedStars = 0;
    final commentCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle bar
                Container(width: 40, height: 4,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),

                // Icon
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: _goOutsBlue.withOpacity(0.10),
                    shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded,
                    size: 32, color: _goOutsBlue)),
                const SizedBox(height: 14),

                // Title
                const Text('Rate Your Support Experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1C))),
                const SizedBox(height: 6),
                const Text('How was your experience with GoOuts Support?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280),
                    height: 1.4)),
                const SizedBox(height: 22),

                // Stars
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (int i = 1; i <= 5; i++)
                    GestureDetector(
                      onTap: () => setSheetState(() => selectedStars = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          i <= selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 40,
                          color: i <= selectedStars
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFCBD5E1)),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),

                // Star label
                Text(
                  selectedStars == 0 ? 'Tap a star to rate'
                    : selectedStars == 1 ? 'Poor'
                    : selectedStars == 2 ? 'Fair'
                    : selectedStars == 3 ? 'Good'
                    : selectedStars == 4 ? 'Very Good'
                    : 'Excellent!',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: selectedStars == 0
                        ? const Color(0xFF94A3B8)
                        : selectedStars >= 4
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 18),

                // Comment field
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Leave a comment (optional)...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EEF3))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EEF3))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _goOutsBlue, width: 1.4)),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedStars == 0 ? null : () async {
                      Navigator.pop(ctx);
                      await _submitRating(
                        stars: selectedStars,
                        comment: commentCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _goOutsBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                    child: const Text('Submit Rating',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),

                // Skip
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Skip for now',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ),
              ]),
            );
          },
        );
      },
    );
    // commentCtrl is a local variable — it will be garbage collected automatically.
    // Do NOT call commentCtrl.dispose() here; the bottom sheet animation is still
    // running when this line is reached, and disposing while the TextField still
    // holds a reference causes the '_dependents.isEmpty' assertion crash.
  }

  Future<void> _submitRating({required int stars, required String comment}) async {
    try {
      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.ticketId)
          .update({
        'rating':          stars,
        'ratingComment':   comment,
        'ratedAt':         FieldValue.serverTimestamp(),
        'ratingLabel':     stars == 1 ? 'Poor'
                         : stars == 2 ? 'Fair'
                         : stars == 3 ? 'Good'
                         : stars == 4 ? 'Very Good'
                         : 'Excellent',
      });

      if (mounted) {
        GoOutsSheet.success(context, title: 'Thank You! ⭐', message: 'Thank you for your feedback!',
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {}
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'new':             return _goOutsBlue;
      case 'in_progress':     return const Color(0xFFD97706);
      case 'need_more_info':  return const Color(0xFF7C3AED);
      case 'waiting_driver':  return const Color(0xFF0891B2);
      case 'resolved':        return const Color(0xFF16A34A);
      case 'closed':          return const Color(0xFF60717D);
      default:                return _goOutsBlue;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'new':             return 'New';
      case 'in_progress':     return 'In Progress';
      case 'need_more_info':  return 'Need More Info';
      case 'waiting_driver':  return 'Waiting for You';
      case 'resolved':        return 'Resolved';
      case 'closed':          return 'Closed';
      default:                return s;
    }
  }

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate().toLocal();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final day = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '$day $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AutoSizeText(widget.subject,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 1),
          Text(widget.ticketNumber,
            style: const TextStyle(fontSize: 11, color: _goOutsBlue,
              fontWeight: FontWeight.w600)),
        ]),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_requests')
                .doc(widget.ticketId)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>? ?? {};
              final status = (data['status'] ?? 'new').toString();
              if (_ticketStatus != status) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _ticketStatus = status);
                });
              }
              final color = _statusColor(status);
              return Container(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.30))),
                child: Text(_statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: color)),
              );
            },
          ),
        ],
      ),

      body: Column(children: [
        // ── Messages thread ───────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_requests')
                .doc(widget.ticketId)
                .collection('messages')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _goOutsBlue));
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No messages yet.',
                    style: TextStyle(color: Colors.grey)));
              }

              _scrollToBottom();

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isDriver    = data['sender'] == 'driver';
                  final isSystem    = data['isSystemMessage'] == true;
                  final text        = (data['text'] ?? '').toString();
                  final imageUrl    = (data['imageUrl'] ?? '').toString();
                  final ts          = data['createdAt'] as Timestamp?;

                  if (isSystem) {
                    return Center(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(text,
                          style: const TextStyle(fontSize: 12,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600))));
                  }

                  final isLast = (i == docs.length - 1);
                  return Align(
                    alignment: isDriver
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: isDriver
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDriver ? 'You' : 'GoOuts Support',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: isDriver ? _goOutsBlue
                                  : const Color(0xFF475569))),
                          const SizedBox(height: 3),
                          Container(
                            clipBehavior: Clip.antiAlias,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDriver ? _goOutsBlue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft:     const Radius.circular(16),
                                topRight:    const Radius.circular(16),
                                bottomLeft:  Radius.circular(isDriver ? 16 : 4),
                                bottomRight: Radius.circular(isDriver ? 4 : 16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (text.isNotEmpty)
                                  Text(text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDriver
                                          ? Colors.white
                                          : _textPrimary,
                                      height: 1.4)),
                                if (imageUrl.isNotEmpty) ...[
                                  if (text.isNotEmpty) const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imageUrl,
                                      width: 200, fit: BoxFit.cover,
                                      loadingBuilder: (_, child, progress) =>
                                          progress == null ? child
                                              : const SizedBox(height: 100,
                                                  child: Center(child: CircularProgressIndicator(
                                                    color: _goOutsBlue, strokeWidth: 2))))),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(_fmtTime(ts),
                            style: const TextStyle(fontSize: 10,
                              color: Color(0xFF94A3B8))),

                          // ── Reply / Upload buttons on admin messages ─────────
                          if (!isDriver &&
                              (_ticketStatus != 'closed' && _ticketStatus != 'resolved') &&
                              isLast) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              // Reply button
                              _QuickActionBtn(
                                icon: Icons.reply_rounded,
                                label: 'Reply',
                                color: _goOutsBlue,
                                onTap: _focusReplyField,
                              ),
                              const SizedBox(width: 8),
                              _QuickActionBtn(
                                icon: Icons.upload_file_rounded,
                                label: 'Upload Document',
                                color: _goOutsBlue,
                                onTap: _pickAndUploadImage,
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Closed banner ─────────────────────────────────────────────────────
        if (_ticketStatus == 'resolved' || _ticketStatus == 'closed')
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFDCFCE7),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'This ticket is closed. Open a new request if you need further help.',
                style: TextStyle(fontSize: 12, color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w600))),
            ]),
          )

        // ── Always-visible reply bar (open ticket) ────────────────────────────
        else
          SafeArea(
            top: false,
            child: Container(
              clipBehavior: Clip.antiAlias,
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 14, right: 14, top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Input row: upload + text field + send
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Upload Document button
                GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadImage,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _goOutsBlue,
                      borderRadius: BorderRadius.circular(12)),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file_rounded,
                            size: 20, color: Colors.white)),
                ),
                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    focusNode: _replyFocus,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _softBorder)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _softBorder)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _goOutsBlue, width: 1.4)),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sending ? null : () => _sendMessage(text: _replyCtrl.text),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _goOutsBlue,
                      borderRadius: BorderRadius.circular(12)),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            size: 20, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 10),

              // Close Ticket button — blue, no icon
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _markResolved,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goOutsBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8)),
                  child: const Text('Issue Resolved — Close Ticket',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                ),
              ),
            ]),
          ),
          ), // SafeArea
      ]),
    );
  }
}

// ── Quick-action button shown on last admin message ──────────────────────────
class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            )),
        ]),
      ),
    );
  }
}
