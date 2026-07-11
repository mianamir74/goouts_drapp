import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'my_tickets_screen.dart';

/// Reusable "My Tickets" AppBar button with live red unread badge.
///
/// [invertColors] = false (default) → blue pill on white/light AppBar
/// [invertColors] = true            → white pill on blue AppBar
class MyTicketsButton extends StatefulWidget {
  final bool invertColors;

  const MyTicketsButton({super.key, this.invertColors = false});

  @override
  State<MyTicketsButton> createState() => _MyTicketsButtonState();
}

class _MyTicketsButtonState extends State<MyTicketsButton> {
  static const Color _blue = Color(0xFF0392CA);

  String _collection = 'drivers';
  String _name       = 'Driver';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// One-time fetch to get the user's name and collection.
  Future<void> _loadUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fs = FirebaseFirestore.instance;

    for (final coll in ['drivers', 'businesses', 'cab_drivers']) {
      try {
        final doc = await fs.collection(coll).doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final firstName = (data['firstName'] ?? '').toString().trim();
          final surname   = (data['surname']   ?? '').toString().trim();
          final fullName  = [firstName, surname]
              .where((s) => s.isNotEmpty)
              .join(' ');
          if (mounted) {
            setState(() {
              _collection = coll;
              _name       = fullName.isNotEmpty ? fullName : 'Driver';
            });
          }
          return;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    final bool inv = widget.invertColors;
    final Color pillBg      = inv ? Colors.white.withOpacity(0.18) : _blue.withOpacity(0.09);
    final Color pillBorder  = inv ? Colors.white.withOpacity(0.40) : _blue.withOpacity(0.25);
    final Color iconColor   = inv ? Colors.white                    : _blue;
    final Color textColor   = inv ? Colors.white                    : _blue;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .where('uid', isEqualTo: uid)
          .where('unreadByDriver', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final unread = snap.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MyTicketsScreen(
                sourceCollection: _collection,
                driverName: _name,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: pillBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.confirmation_number_rounded, size: 16, color: iconColor),
                    const SizedBox(width: 5),
                    Text(
                      'My Tickets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ]),
                ),
                // Red badge
                if (unread > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
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
          ),
        );
      },
    );
  }
}
