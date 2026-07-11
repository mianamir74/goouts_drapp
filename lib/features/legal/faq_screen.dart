import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAQ Screen
//
// Loads FAQ items from Firestore `faq` collection (field: question, answer,
// order, isActive). Falls back to hardcoded defaults when the collection is
// empty or unavailable. Add / edit / delete entries from the Admin Panel.
// ─────────────────────────────────────────────────────────────────────────────

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);

  // ── Hardcoded fallback FAQs (shown when Firestore collection is empty) ──────
  static const List<_FaqItem> _defaults = [
    _FaqItem(
      question: 'What is GoOuts?',
      answer:
          'GoOuts is a pre-launch lead generation platform connecting delivery drivers, '
          'rider drivers, and business partners across the United Kingdom and Northern Ireland. '
          'Register now to secure your place ahead of the official launch.',
    ),
    _FaqItem(
      question: 'Is GoOuts live yet?',
      answer:
          'GoOuts is currently in its pre-launch phase. No live deliveries or commercial '
          'transactions take place within the app at this time. Early registrants will receive '
          'priority access and notifications when GoOuts goes live in their area.',
    ),
    _FaqItem(
      question: 'How do I register as a Delivery Driver?',
      answer:
          'Open the app and select "Delivery Driver" on the role selection screen. '
          'Complete your personal details, upload your selfie and identity documents, '
          'and submit your registration. Our team will review and approve your profile.',
    ),
    _FaqItem(
      question: 'How do I register as a Rider Driver?',
      answer:
          'Select "Rider Driver" on the role selection screen and follow the registration '
          'steps. You will need to provide personal details, a selfie, and valid identity '
          'documents to complete your profile.',
    ),
    _FaqItem(
      question: 'How do I register as a Business Partner?',
      answer:
          'Select "Business Partner" on the role selection screen. You will be asked to '
          'provide your business name, company number, business address, and supporting '
          'documents. Once submitted, your account will be reviewed by our team.',
    ),
    _FaqItem(
      question: 'What is the referral programme?',
      answer:
          'Every registered user receives a unique referral code. Share it with friends '
          'and contacts — when they register using your code, they are linked to your '
          'network. You can track who has joined, who is still pending, and grow your '
          'portfolio directly from the My Referrals section.',
    ),
    _FaqItem(
      question: 'How much can I earn through referrals?',
      answer:
          'GoOuts operates a residual income model. You can earn up to 5% from the earnings '
          'of drivers you refer. Full earnings details will be confirmed at launch. '
          'The more drivers you bring in before launch, the larger your network will be '
          'from day one.',
    ),
    _FaqItem(
      question: 'Why do I need to upload identity documents?',
      answer:
          'Identity verification is a legal and compliance requirement. We collect a selfie '
          'and government-issued ID (passport or driving licence) to confirm your identity '
          'and right to work. Your documents are stored securely and are never shared with '
          'third parties except where required by law.',
    ),
    _FaqItem(
      question: 'How do I send a reminder to a pending referral?',
      answer:
          'Go to My Referrals, find the person with a Pending status, and tap the '
          '"Send Reminder" button. This will open WhatsApp with a pre-filled reminder '
          'message addressed to that person so you can send it in one tap.',
    ),
    _FaqItem(
      question: 'What does "Joined Elsewhere" mean?',
      answer:
          '"Joined Elsewhere" means the person you invited completed their registration '
          'but used a different referral code. They are no longer linked to your referral '
          'network.',
    ),
    _FaqItem(
      question: 'How do I reset my password?',
      answer:
          'On the login screen tap "Forgot Password?" and enter your registered email '
          'address. You will receive a password reset link by email. If you registered '
          'using your phone number only, contact support at support@goouts.app.',
    ),
    _FaqItem(
      question: 'How do I contact GoOuts support?',
      answer:
          'You can reach us through the Help & Support section in the app menu, or '
          'email us directly at support@goouts.app. We aim to respond within 24 hours '
          'on business days.',
    ),
  ];

  Future<List<_FaqItem>> _loadFaqs() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('faq')
              .where('isActive', isEqualTo: true)
              .orderBy('order')
              .get();

      if (snapshot.docs.isEmpty) {
        return _defaults;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _FaqItem(
          question: (data['question'] ?? '').toString().trim(),
          answer: (data['answer'] ?? '').toString().trim(),
        );
      }).where((item) => item.question.isNotEmpty).toList();
    } catch (_) {
      // Firestore unavailable or index not yet created — use defaults
      return _defaults;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AutoSizeText(
          'FAQ',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<_FaqItem>>(
        future: _loadFaqs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            );
          }

          final List<_FaqItem> items = snapshot.data ?? _defaults;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: items.length + 1, // +1 for header
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader();
              }
              return _FaqTile(item: items[index - 1]);
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.help_outline_rounded,
                    color: _goOutsBlue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap any question to expand the answer. '
                    'Can\'t find what you\'re looking for? '
                    'Contact us via Help & Support in the menu.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A8A),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ data model
// ─────────────────────────────────────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable FAQ tile
// ─────────────────────────────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  static const Color _goOutsBlue = Color(0xFF0392CA);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? _goOutsBlue : const Color(0xFFE5E7EB),
          width: _expanded ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _goOutsBlue,
          collapsedIconColor: Colors.black45,
          onExpansionChanged: (value) {
            setState(() {
              _expanded = value;
            });
          },
          title: AutoSizeText(
            widget.item.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _expanded ? _goOutsBlue : const Color(0xFF1F2937),
              height: 1.4,
            ),
          ),
          children: [
            Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            SizedBox(height: 12),
            AutoSizeText(
              widget.item.answer,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF374151),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
