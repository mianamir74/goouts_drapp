import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'support_ticket_chat_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final String sourceCollection; // 'drivers' | 'cab_drivers' | 'businesses'
  final String driverName;

  const MyTicketsScreen({
    super.key,
    required this.sourceCollection,
    required this.driverName,
  });

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  static const Color _blue    = Color(0xFF0392CA);
  static const Color _bg      = Color(0xFFF2F3F7);
  static const Color _muted   = Color(0xFF60717D);
  static const Color _border  = Color(0xFFE8EEF3);

  String _filter = 'all'; // all | open | closed

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Status helpers ──────────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'new':             return const Color(0xFF3B82F6);
      case 'in_progress':     return const Color(0xFFD97706);
      case 'need_more_info':  return const Color(0xFF7C3AED);
      case 'waiting_driver':  return const Color(0xFF0891B2);
      case 'resolved':        return const Color(0xFF16A34A);
      case 'closed':          return const Color(0xFF64748B);
      default:                return _muted;
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

  bool _isOpenStatus(String s) =>
      s == 'new' || s == 'in_progress' || s == 'need_more_info' || s == 'waiting_driver';

  // ── Date formatter ──────────────────────────────────────────────────────────
  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(d.year, d.month, d.day);
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (msgDay == today) return 'Today $time';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ── Filter tab ──────────────────────────────────────────────────────────────
  Widget _tab(String id, String label, IconData icon) {
    final sel = _filter == id;
    return GestureDetector(
      onTap: () => setState(() => _filter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? _blue : _border),
          boxShadow: sel
              ? [BoxShadow(color: _blue.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : _muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : _muted,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Ticket card ─────────────────────────────────────────────────────────────
  Widget _ticketCard(Map<String, dynamic> data, String docId) {
    final status       = (data['status'] ?? 'new').toString();
    final subject      = (data['subject'] ?? 'Support Request').toString();
    final categoryLabel = (data['categoryLabel'] ?? '').toString();
    final subTopic     = (data['subTopic'] ?? '').toString();
    final lastMessage  = (data['lastMessage'] ?? data['message'] ?? '').toString();
    final createdAt    = data['createdAt'] as Timestamp?;
    final lastMsgAt    = data['lastMessageAt'] as Timestamp?;
    final lastMessageBy = (data['lastMessageBy'] ?? '').toString();
    final unreadByDriver = data['unreadByDriver'] == true;
    final rawTicketNum = (data['ticketNumber'] ?? docId).toString();
    final ticketNumber = 'SR-${rawTicketNum.substring(0, rawTicketNum.length >= 8 ? 8 : rawTicketNum.length).toUpperCase()}';

    final isOpen  = _isOpenStatus(status);
    final statusColor = _statusColor(status);
    final hasNewReply = unreadByDriver && lastMessageBy == 'admin';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupportTicketChatScreen(
              ticketId:         docId,
              subject:          subject,
              ticketNumber:     ticketNumber,
              driverName:       widget.driverName,
              sourceCollection: widget.sourceCollection,
            ),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasNewReply
                ? _blue.withOpacity(0.45)
                : isOpen
                    ? _border
                    : const Color(0xFFE2E8F0),
            width: hasNewReply ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasNewReply
                  ? _blue.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row: ticket number + status badge
            Row(children: [
              Text(
                ticketNumber,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // New reply indicator
              if (hasNewReply) ...[
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                ),
              ],
              // Status badge
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // Subject
            Text(
              subject,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1C)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Category / sub-topic
            if (categoryLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subTopic.isNotEmpty ? '$categoryLabel · $subTopic' : categoryLabel,
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],

            const SizedBox(height: 10),

            // Last message preview
            if (lastMessage.isNotEmpty)
              Container(
                clipBehavior: Clip.antiAlias,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
              ),

            const SizedBox(height: 10),

            // Footer: date + action hint
            Row(children: [
              Icon(Icons.access_time_rounded, size: 12, color: _muted),
              const SizedBox(width: 4),
              Text(
                _fmtDate(lastMsgAt ?? createdAt),
                style: TextStyle(fontSize: 11, color: _muted),
              ),
              const Spacer(),
              if (hasNewReply)
                Row(children: [
                  const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF0392CA)),
                  const SizedBox(width: 4),
                  const Text(
                    'New reply — tap to read',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0392CA)),
                  ),
                ])
              else if (isOpen)
                Row(children: [
                  Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
                  Text(
                    'Continue conversation',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ]),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('Not logged in.')));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('My Support Tickets', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_requests')
            .where('uid', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0392CA)));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final allDocs = snap.data?.docs ?? [];

          // Sort by createdAt descending in memory (avoids Firestore index requirement)
          allDocs.sort((a, b) {
            final aTs = ((a.data() as Map)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTs = ((b.data() as Map)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bTs.compareTo(aTs);
          });

          // Apply filter
          final filtered = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'new').toString();
            if (_filter == 'open')   return _isOpenStatus(status);
            if (_filter == 'closed') return !_isOpenStatus(status);
            return true;
          }).toList();

          final openCount   = allDocs.where((d) => _isOpenStatus(((d.data() as Map)['status'] ?? '').toString())).length;
          final closedCount = allDocs.length - openCount;

          return Column(children: [
            // ── Summary banner ────────────────────────────────────────────────
            Container(
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                _summaryChip('Total', allDocs.length, _blue),
                const SizedBox(width: 12),
                _summaryChip('Open', openCount, const Color(0xFFD97706)),
                const SizedBox(width: 12),
                _summaryChip('Closed', closedCount, const Color(0xFF64748B)),
              ]),
            ),

            // ── Filter tabs ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                _tab('all',    'All',    Icons.list_rounded),
                const SizedBox(width: 8),
                _tab('open',   'Open',   Icons.pending_rounded),
                const SizedBox(width: 8),
                _tab('closed', 'Closed', Icons.lock_outline_rounded),
              ]),
            ),

            // ── Ticket list ───────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc  = filtered[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _ticketCard(data, doc.id);
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, size: 34, color: Color(0xFF0392CA)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tickets yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'open'
                ? 'You have no open support requests.'
                : _filter == 'closed'
                    ? 'No closed tickets to show.'
                    : 'When you submit a support request, it will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.45),
          ),
        ]),
      ),
    );
  }
}
