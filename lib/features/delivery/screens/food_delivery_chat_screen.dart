import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FoodDeliveryChatScreen (Driver) — Driver ↔ Customer in-app chat
//
//  Window: Driver can send while status is driver_heading_to_restaurant or
//          driver_picked_up, and for 30 min after deliveredAt.
//          After that, input is locked (read-only history preserved).
//
//  ⚠ Was 15 min here vs 30 min on the consumer side (food_delivery_chat_screen.dart
//  in goouts_app) — an asymmetric window meant the customer could still type
//  for 15 minutes after the driver's input had already locked, with no way for
//  the driver to reply. Matched to 30 min on 4 September 2026.
// ─────────────────────────────────────────────────────────────────────────────
class FoodDeliveryChatScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  const FoodDeliveryChatScreen({
    super.key,
    required this.orderId,
    required this.customerName,
  });

  @override
  State<FoodDeliveryChatScreen> createState() => _FoodDeliveryChatScreenState();
}

class _FoodDeliveryChatScreenState extends State<FoodDeliveryChatScreen> {
  static const Color _accent = Color(0xFF0392ca);
  static const Color _bg     = Color(0xFF031134);

  final _db        = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending    = false;
  bool _chatOpen   = false;

  StreamSubscription? _orderSub;
  String    _orderStatus = '';
  DateTime? _deliveredAt;
  Timer?    _lockTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToOrder();
  }

  void _subscribeToOrder() {
    _orderSub = _db.collection('food_orders').doc(widget.orderId).snapshots().listen((snap) {
      if (!mounted || !snap.exists) return;
      final data        = snap.data()!;
      final status      = data['status'] as String? ?? '';
      final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();
      setState(() {
        _orderStatus = status;
        _deliveredAt = deliveredAt;
        _chatOpen    = _computeChatOpen(status, deliveredAt);
      });
      _scheduleLock(deliveredAt);
    });
  }

  bool _computeChatOpen(String status, DateTime? deliveredAt) {
    const active = ['driver_heading_to_restaurant', 'driver_picked_up'];
    if (active.contains(status)) return true;
    if (status == 'delivered' && deliveredAt != null) {
      return DateTime.now().isBefore(deliveredAt.add(const Duration(minutes: 30)));
    }
    return false;
  }

  void _scheduleLock(DateTime? deliveredAt) {
    _lockTimer?.cancel();
    if (_orderStatus == 'delivered' && deliveredAt != null) {
      final rem = deliveredAt.add(const Duration(minutes: 30)).difference(DateTime.now());
      if (rem > Duration.zero) {
        _lockTimer = Timer(rem, () { if (mounted) setState(() => _chatOpen = false); });
      }
    }
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _lockTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || !_chatOpen || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final chatRef = _db.collection('order_chats').doc(widget.orderId);
      await chatRef.collection('messages').add({
        'senderId'  : uid,
        'senderRole': 'driver',
        'text'      : text,
        'sentAt'    : FieldValue.serverTimestamp(),
        'read'      : false,
      });
      await chatRef.set({'orderId': widget.orderId, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: _accent.withOpacity(0.15),
            child: const Icon(Icons.person_rounded, color: Color(0xFF0392ca), size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.customerName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_chatOpen ? 'Chat open' : 'Chat closed',
                style: TextStyle(color: _chatOpen ? Colors.greenAccent : Colors.white38, fontSize: 11)),
          ]),
        ]),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('order_chats').doc(widget.orderId)
                  .collection('messages').orderBy('sentAt').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0392ca)));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 44, color: Colors.white12),
                      SizedBox(height: 12),
                      Text('No messages yet', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ]),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d    = docs[i].data() as Map<String, dynamic>;
                    final isMe = (d['senderId'] as String?) == myUid;
                    final text = d['text'] as String? ?? '';
                    final ts   = (d['sentAt'] as Timestamp?)?.toDate();
                    return _bubble(text, isMe, ts);
                  },
                );
              },
            ),
          ),

          // Lock banner
          if (!_chatOpen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.white.withOpacity(0.04),
              child: Text(
                _orderStatus == 'delivered'
                    ? 'Chat closed — 30 min window has passed'
                    : 'Chat opens when you head to the restaurant',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),

          // Input
          Container(
            color: const Color(0xFF0b1a3d),
            padding: EdgeInsets.only(
                left: 12, right: 12, top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: _chatOpen,
                  maxLines: 3, minLines: 1,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _chatOpen ? 'Message customer…' : 'Chat closed',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const SizedBox(width: 44, height: 44,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0392ca))))
                  : GestureDetector(
                      onTap: _chatOpen ? _send : null,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _chatOpen ? _accent : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isMe, DateTime? ts) {
    final timeStr = ts != null
        ? '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}'
        : '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _accent : const Color(0xFF0b1a3d),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 3),
          Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        ]),
      ),
    );
  }
}
