import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rebuilt 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 17_food_delivery_chat_screen as a loose
//  visual reference — not a literal port. All real logic (the Firestore
//  message stream, the 30-minute post-delivery lock window, dispose/timer
//  handling) is unchanged.
//
//  Not carried over from the Stitch mockup: its fake hardcoded conversation
//  ("Sarah Jenkins", a stock Unsplash avatar, invented message text and
//  timestamps), a fake "Order accepted at 13:42" specific time (no
//  `acceptedAt` field is tracked), a fake static "ETA 6 mins" (no ETA is
//  computed anywhere in this screen), read-receipt checkmarks (messages do
//  write a `read` field but nothing ever flips it to true, so a checkmark
//  would be a false claim), and — most importantly — a masked-calling phone
//  button that only showed a snackbar claiming to connect via "GoOuts Masked
//  Calling". There is no `customerPhone` field anywhere on a food_orders
//  document (only `restaurantPhone`) and no Twilio/masked-calling backend
//  exists yet — active_delivery_screen.dart already disables this exact
//  button for the same reason; this screen now matches that instead of
//  faking a working call.
//
//  Made real instead of decorative: the quick-reply chips send through the
//  same Firestore pipeline as typed messages, and the camera/attach button
//  now actually opens the camera, uploads to Storage, and sends a real
//  image message — it no longer just shows a snackbar.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F4F7);
  static const surface   = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy      = Color(0xFF0D1B3E);
  static const body      = Color(0xFF475569);
  static const muted     = Color(0xFF94A3B8);
  static const paleTint  = Color(0xFFE0F3FB);
  static const transitBg = Color(0xFFDCEBFA);
  static const transitText = Color(0xFF0284C7);
  static const maskedBg  = Color(0xFFE0F2FE);
  static const maskedText = Color(0xFF0369A1);
  static const milestoneBg = Color(0xFFF1F5F9);
  static const border    = Color(0xFFE2E8F0);
}

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
  static const _quickReplies = <Map<String, String>>[
    {'emoji': '🛵', 'text': 'Arriving in 5 minutes'},
    {'emoji': '🚪', 'text': 'At your door'},
    {'emoji': '🔔', 'text': 'Buzzer not working'},
  ];

  final _db        = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _storage   = FirebaseStorage.instance;
  final _picker    = ImagePicker();
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending    = false;
  bool _chatOpen   = false;

  StreamSubscription? _orderSub;
  String    _orderStatus = '';
  String    _restaurantName = '';
  String    _deliveryAddress = '';
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
        _orderStatus     = status;
        _restaurantName  = data['restaurantName'] as String? ?? '';
        _deliveryAddress = data['deliveryAddress'] as String? ?? '';
        _deliveredAt     = deliveredAt;
        _chatOpen        = _computeChatOpen(status, deliveredAt);
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

  Future<void> _sendText(String text) async {
    if (text.isEmpty || !_chatOpen || _sending) return;
    setState(() => _sending = true);
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

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await _sendText(text);
  }

  Future<void> _attachPhoto() async {
    if (!_chatOpen || _sending) return;
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final path = 'order_chats/${widget.orderId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref  = _storage.ref(path);
      await ref.putFile(File(picked.path));
      final url  = await ref.getDownloadURL();
      final chatRef = _db.collection('order_chats').doc(widget.orderId);
      await chatRef.collection('messages').add({
        'senderId'  : uid,
        'senderRole': 'driver',
        'imageUrl'  : url,
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
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Customer Chat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Order context card ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: _C.paleTint, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.two_wheeler_rounded, color: _C.primaryDk, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _chatOpen ? 'CHAT OPEN' : 'CHAT CLOSED',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _chatOpen ? _C.transitText : _C.muted, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _deliveryAddress.isNotEmpty ? _deliveryAddress : widget.customerName,
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.navy, letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // ⚠ Disabled — no customerPhone field exists and no
                    // masked-calling backend exists yet. Matches the same
                    // disabled state on active_delivery_screen.dart.
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(Icons.phone_disabled_rounded, color: _C.muted, size: 18),
                    ),
                  ],
                ),
              ),
            ),

            // ── Messages ────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // limitToLast, not limit — this keeps the most RECENT 200
                // messages in an ascending-order query, rather than the
                // oldest 200 with everything after silently missing. Added
                // 8 September 2026 in the post-build performance review:
                // this was an unbounded listener, fine for one order's
                // chat in practice but worth capping defensively.
                stream: _db
                    .collection('order_chats').doc(widget.orderId)
                    .collection('messages').orderBy('sentAt').limitToLast(200).snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: _C.primary));
                  }
                  final docs = snap.data!.docs;
                  return ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      if (_restaurantName.isNotEmpty) _milestonePill('Order picked up from $_restaurantName'),
                      if (_restaurantName.isNotEmpty) const SizedBox(height: 10),
                      _maskedPill(),
                      const SizedBox(height: 16),
                      if (docs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 30),
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 44, color: _C.muted),
                              SizedBox(height: 12),
                              Text('No messages yet', style: TextStyle(color: _C.muted, fontSize: 14)),
                            ]),
                          ),
                        ),
                      ...docs.map((doc) {
                        final d       = doc.data() as Map<String, dynamic>;
                        final isMe    = (d['senderId'] as String?) == myUid;
                        final text    = d['text'] as String?;
                        final imgUrl  = d['imageUrl'] as String?;
                        final ts      = (d['sentAt'] as Timestamp?)?.toDate();
                        return _bubble(text: text, imageUrl: imgUrl, isMe: isMe, ts: ts);
                      }),
                      if (docs.isNotEmpty) const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),

            // ── Lock banner ────────────────────────────────────────────
            if (!_chatOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: _C.paleTint,
                child: Text(
                  _orderStatus == 'delivered'
                      ? 'Chat closed — 30 min window has passed'
                      : 'Chat opens when you head to the restaurant',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.body, fontSize: 12),
                ),
              ),

            // ── Quick replies ───────────────────────────────────────────
            if (_chatOpen)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _quickReplies.map((r) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      onPressed: () => _sendText(r['text']!),
                      backgroundColor: _C.surface,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _C.border)),
                      avatar: Text(r['emoji']!, style: const TextStyle(fontSize: 13)),
                      label: Text(r['text']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.primaryDk)),
                    ),
                  )).toList(),
                ),
              ),
            if (_chatOpen) const SizedBox(height: 8),

            // ── Compose bar ─────────────────────────────────────────────
            Container(
              color: _C.surface,
              padding: EdgeInsets.only(
                  left: 12, right: 12, top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.camera_alt_outlined, color: _chatOpen ? _C.navy : _C.muted, size: 22),
                  onPressed: _chatOpen ? _attachPhoto : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    enabled: _chatOpen,
                    maxLines: 3, minLines: 1,
                    style: const TextStyle(color: _C.navy),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _chatOpen ? 'Message customer…' : 'Chat closed',
                      hintStyle: const TextStyle(color: _C.muted),
                      filled: true,
                      fillColor: _C.bg,
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
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)))
                    : GestureDetector(
                        onTap: _chatOpen ? _send : null,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: _chatOpen ? _C.primaryDk : _C.border,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _milestonePill(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: _C.milestoneBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 14, color: _C.body),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.navy)),
          ],
        ),
      ),
    );
  }

  Widget _maskedPill() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: _C.maskedBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline_rounded, size: 14, color: _C.maskedText),
            SizedBox(width: 6),
            Text('In-app chat only — not shared outside this order',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.maskedText)),
          ],
        ),
      ),
    );
  }

  Widget _bubble({String? text, String? imageUrl, required bool isMe, DateTime? ts}) {
    final timeStr = ts != null
        ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
        : '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: imageUrl != null ? const EdgeInsets.all(6) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _C.primaryDk : _C.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(18),
          ),
          boxShadow: isMe ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(imageUrl, width: 200, fit: BoxFit.cover),
            )
          else
            Text(text ?? '', style: TextStyle(color: isMe ? Colors.white : _C.navy, fontSize: 14, height: 1.4)),
          const SizedBox(height: 3),
          Padding(
            padding: imageUrl != null ? const EdgeInsets.only(right: 4, top: 2) : EdgeInsets.zero,
            child: Text(timeStr, style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : _C.muted)),
          ),
        ]),
      ),
    );
  }
}
