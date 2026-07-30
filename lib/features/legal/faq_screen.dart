import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAQ Screen  —  GoOuts Delivery Driver
//
// Loads FAQ items from Firestore collection `delivery_driver_faqs`.
// Fields: question, answer, category, order, isActive.
// Falls back to the hardcoded defaults below when the collection is empty or
// unreachable. Managed from Admin Panel → Driver FAQs → Delivery Driver.
//
// IMPORTANT: this app previously read a collection called `faq`, which it
// shared with the GoOuts Lead enrolment app, and therefore showed enrolment
// and early access answers to working delivery drivers. The two apps now use
// separate collections. The collection name and the `isActive` field name must
// stay in step with _DriverFaqsPage in admin_panel/lib/admin_dashboard.dart.
// ─────────────────────────────────────────────────────────────────────────────

const String kDeliveryDriverFaqCollection = 'delivery_driver_faqs';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);

  /// Category display order. Anything not listed is appended at the end.
  static const List<String> _categoryOrder = [
    'Getting Started',
    'Deliveries',
    'Earnings',
    'Residual Income',
    'Referrals',
    'Safety',
    'Account',
  ];

  // ── Hardcoded fallback FAQs ────────────────────────────────────────────────
  // Screen names below match the real app: Trip Radar, the dashboard heatmap,
  // the safety toolkit, the earnings breakdown and the weekly residual summary.
  static const List<_FaqItem> _defaults = [
    // ── Getting Started ──────────────────────────────────────────────────────
    _FaqItem(
      category: 'Getting Started',
      question: 'What do I need before I can start delivering?',
      answer:
          'A verified GoOuts driver account, a valid identity document, the '
          'right to work in the United Kingdom, and the correct insurance for '
          'the vehicle you will be using. Once your documents are approved you '
          'can go online and start receiving orders.',
    ),
    _FaqItem(
      category: 'Getting Started',
      question: 'How do I go online and start receiving orders?',
      answer:
          'Open the app and switch yourself online from your dashboard. Nearby '
          'order offers then come through automatically. Tap an offer to see the '
          'pickup, the delivery address and exactly what you will be paid before '
          'you decide whether to accept it.',
    ),
    _FaqItem(
      category: 'Getting Started',
      question: 'What is Trip Radar?',
      answer:
          'Trip Radar shows you where orders are being placed around you in real '
          'time. Use it to position yourself close to busy restaurants instead '
          'of waiting in a quiet area.',
    ),
    _FaqItem(
      category: 'Getting Started',
      question: 'What is the heatmap on my dashboard?',
      answer:
          'The heatmap shades the areas with the most order activity at that '
          'moment. Warmer colours mean higher demand, so moving towards them '
          'usually means shorter waits between jobs.',
    ),

    // ── Deliveries ───────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Deliveries',
      question: 'Can I see what an order pays before I accept it?',
      answer:
          'Yes, always. Every offer shows the pickup location, the delivery '
          'address, the distance and your total payment before you accept. You '
          'are never asked to commit to a job without knowing what it pays.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'What happens if I decline an order?',
      answer:
          'Nothing at all. Declining an offer does not affect your account, your '
          'rating or the orders you are shown next. If a job does not work for '
          'you, let it go and wait for the following one.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'The restaurant is not ready. What should I do?',
      answer:
          'Stay at the venue and mark the order as waiting in the app so support '
          'can see the delay. Message the customer through the in app chat to '
          'let them know. Never leave without the food, and never mark an order '
          'as collected before it is actually in your hands.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'How do I confirm that I have collected the order?',
      answer:
          'Scan the order code shown by the restaurant, or enter the pickup code '
          'manually if scanning is not possible. This starts the delivery leg '
          'and begins sharing your live location with the customer waiting for '
          'the order.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'How do I complete a delivery?',
      answer:
          'Follow the confirmation method shown on the order screen. Depending '
          'on the delivery that is a photo of where you left the food, a code '
          'read out by the customer, or a signature. Complete that step in the '
          'app before you leave, otherwise the order stays open.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'The customer is not answering. What should I do?',
      answer:
          'Call and message the customer through the app first. If there is '
          'still no answer, wait for the time shown on the order screen and then '
          'follow the prompt to report the delivery as failed. Do not leave food '
          'unattended unless the customer has asked for it to be left somewhere '
          'specific.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'Can I cancel a delivery after I have accepted it?',
      answer:
          'You can, but please only do so when you genuinely cannot finish the '
          'job, for example a breakdown or a safety concern. Use the cancel '
          'option on the delivery screen so the order can be reassigned quickly, '
          'and tell support what happened.',
    ),
    _FaqItem(
      category: 'Deliveries',
      question: 'Something is missing from the order. Am I responsible?',
      answer:
          'No. Sealed bags are the restaurant’s responsibility and you are not '
          'expected to check their contents. Report the problem in the app so we '
          'can log it against the venue, and never open a sealed order.',
    ),

    // ── Earnings ─────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Earnings',
      question: 'How is my payment for each delivery calculated?',
      answer:
          'Each job is priced from the distance, the expected time and the '
          'current demand in that area. The full amount is shown on the offer '
          'before you accept, so there are no surprises afterwards.',
    ),
    _FaqItem(
      category: 'Earnings',
      question: 'Do I keep all of my tips?',
      answer:
          'Yes. One hundred percent of every tip goes to you. GoOuts does not '
          'take a share of tips and they are listed separately in your earnings '
          'breakdown so you can always see them.',
    ),
    _FaqItem(
      category: 'Earnings',
      question: 'Where can I see what I have earned?',
      answer:
          'Your earnings screen shows what you have made today, this week and in '
          'total. Open the earnings breakdown to see every individual job, the '
          'distance, the base payment and any tip that was added.',
    ),
    _FaqItem(
      category: 'Earnings',
      question: 'Why is my payment different from what I expected?',
      answer:
          'Open your earnings breakdown and look at that individual job. '
          'Payments change if the actual distance differed from the estimate, if '
          'a waiting adjustment was applied, or if a tip arrived after you '
          'finished. If the figure still looks wrong, raise it with support and '
          'quote the order number.',
    ),

    // ── Residual Income ──────────────────────────────────────────────────────
    _FaqItem(
      category: 'Residual Income',
      question: 'What is residual income and how does it work?',
      answer:
          'It is a thank you from GoOuts for helping us grow. When you introduce '
          'a restaurant, cafe, shop or takeaway to GoOuts and they go live, you '
          'earn a share of what that business pays GoOuts every week, '
          'automatically, for as long as they stay active. Once the introduction '
          'is made there is nothing further for you to do.',
    ),
    _FaqItem(
      category: 'Residual Income',
      question: 'Do I qualify for residual income right now?',
      answer:
          'Yes. We are in a grace period, so every active GoOuts driver '
          'qualifies automatically. There are no minimum delivery counts and no '
          'rating thresholds while the grace period is running. We will give you '
          'plenty of notice before any rules take effect.',
    ),
    _FaqItem(
      category: 'Residual Income',
      question: 'What rules will apply once the grace period ends?',
      answer:
          'You will need to meet a few straightforward targets: at least 200 '
          'completed GoOuts deliveries in total, at least 20 deliveries in the '
          'current month, a rating of 4.2 stars or above, and at least three '
          'months on the platform. Your referred business will also need to '
          'process at least 10 orders a month, and your account must be clear of '
          'active warnings or strikes. These figures can be updated by GoOuts '
          'and the current requirements are always shown in your app.',
    ),
    _FaqItem(
      category: 'Residual Income',
      question: 'Is it difficult to qualify?',
      answer:
          'If you are delivering regularly and looking after customers you will '
          'reach these targets without thinking about it. Twenty deliveries a '
          'month works out at roughly five a week, which most active drivers '
          'cover in a couple of shifts, and a 4.2 star rating is comfortably '
          'achievable by turning up on time and keeping customers informed.',
    ),
    _FaqItem(
      category: 'Residual Income',
      question: 'How much can I earn from residuals?',
      answer:
          'It depends on how many businesses you have introduced and how busy '
          'they are. Each week you receive a percentage of what your referred '
          'businesses pay GoOuts, so the more orders they take the more you '
          'earn. It builds up over time with no extra work from you.',
    ),
    _FaqItem(
      category: 'Residual Income',
      question: 'When are residuals paid?',
      answer:
          'Residuals are calculated every week and added to your GoOuts earnings '
          'wallet. Your weekly residual summary shows exactly which business '
          'contributed what amount, so you can always see where the money came '
          'from.',
    ),
    _FaqItem(
      category: 'Residual Income',
      question: 'Does a warning or a strike affect my residuals?',
      answer:
          'During the grace period, no. Once the rules are live, an active '
          'strike will pause your residual payments until the matter is '
          'resolved. Deliver safely and professionally and this will never come '
          'up.',
    ),

    // ── Referrals ────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Referrals',
      question: 'How do I introduce a business to GoOuts?',
      answer:
          'Go to your profile and open the refer a business option to get your '
          'unique link. Share it with any local restaurant, cafe, shop or '
          'takeaway that might want to join GoOuts. When they sign up and go '
          'live using your link, they are automatically attached to your '
          'account.',
    ),
    _FaqItem(
      category: 'Referrals',
      question:
          'I introduced a business but I cannot see them in my residuals.',
      answer:
          'Check three things first. Did they sign up using your link, are they '
          'live and taking orders, and is your own account in good standing. If '
          'all three are true and the residual still has not appeared after a '
          'week, contact support and we will trace it for you.',
    ),
    _FaqItem(
      category: 'Referrals',
      question: 'What happens if my referred business goes quiet?',
      answer:
          'If a business you introduced falls below the monthly order threshold '
          'once the rules are active, it will not contribute to your residuals '
          'that week. They keep their GoOuts account and your link to them stays '
          'in place, so you start earning again as soon as they pick back up.',
    ),

    // ── Safety ───────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Safety',
      question: 'What does the Emergency SOS button do?',
      answer:
          'It calls 999 and shares your live location with GoOuts support at the '
          'same time. Use it if you are in immediate danger. You are asked to '
          'confirm first so it cannot be triggered by accident.',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'Something happened but it was not an emergency.',
      answer:
          'Use the report option in your safety toolkit. It goes straight to the '
          'GoOuts safety team with your location and order details attached. Use '
          'it for aggression, unsafe premises, damage, or anything that felt '
          'wrong but did not need the police.',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'Who can see my location?',
      answer:
          'Your live location is only shared while you are on an active '
          'delivery, and only with the customer waiting for that order and with '
          'GoOuts support. It stops the moment the delivery is complete.',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'What should I do if I have an accident?',
      answer:
          'Look after yourself first and call 999 if anyone is hurt. Once you '
          'are safe, use the SOS or the report option so GoOuts knows what has '
          'happened. We will reassign the order and contact the customer for '
          'you.',
    ),

    // ── Account ──────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Account',
      question: 'How do I log in?',
      answer:
          'GoOuts uses your phone number instead of a password. Enter your '
          'number and we text you a single use code. Enter that code and you are '
          'in, so there is no password to forget.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'Why is my account pending verification?',
      answer:
          'Your documents are being checked. Most checks finish within a couple '
          'of minutes, but anything that needs a human review can take up to two '
          'working days. You will be notified as soon as a decision is made.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'How do I update my vehicle details or my documents?',
      answer:
          'Open your profile settings and go to the documents section. Upload '
          'the replacement and it will be reviewed before it takes effect. Leave '
          'the existing document in place until the new one is approved so you '
          'are not taken offline in the meantime.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'How do I contact support?',
      answer:
          'Open the support section in the app to raise a ticket or start a live '
          'chat. If your question is about a specific delivery, include the '
          'order number, because it gets you an answer considerably faster.',
    ),
  ];

  Future<List<_FaqItem>> _loadFaqs() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(kDeliveryDriverFaqCollection)
              .where('isActive', isEqualTo: true)
              .orderBy('order')
              .get();

      if (snapshot.docs.isEmpty) {
        return _defaults;
      }

      final List<_FaqItem> loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final rawCategory = (data['category'] ?? '').toString().trim();
            return _FaqItem(
              category: rawCategory.isEmpty ? 'General' : rawCategory,
              question: (data['question'] ?? '').toString().trim(),
              answer: (data['answer'] ?? '').toString().trim(),
            );
          })
          .where((item) => item.question.isNotEmpty && item.answer.isNotEmpty)
          .toList();

      // A collection full of blank rows should not produce an empty screen.
      return loaded.isEmpty ? _defaults : loaded;
    } catch (_) {
      // Firestore unavailable, offline, or the composite index is missing.
      return _defaults;
    }
  }

  /// Groups items by category, preserving [_categoryOrder] first and then any
  /// unrecognised categories in the order they were received.
  static List<_FaqSection> _group(List<_FaqItem> items) {
    final Map<String, List<_FaqItem>> buckets = <String, List<_FaqItem>>{};
    for (final item in items) {
      buckets.putIfAbsent(item.category, () => <_FaqItem>[]).add(item);
    }

    final List<String> ordered = <String>[
      ..._categoryOrder.where(buckets.containsKey),
      ...buckets.keys.where((k) => !_categoryOrder.contains(k)),
    ];

    return ordered
        .map((name) => _FaqSection(title: name, items: buckets[name]!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AutoSizeText(
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

          final List<_FaqSection> sections = _group(snapshot.data ?? _defaults);

          final List<Widget> rows = <Widget>[_buildHeader()];
          for (final section in sections) {
            rows.add(_buildCategoryHeading(section.title));
            for (final item in section.items) {
              rows.add(Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FaqTile(item: item),
              ));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
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
            Icon(Icons.help_outline_rounded, color: _goOutsBlue, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap any question to see the answer. If you cannot find what '
                'you need, open the support section and we will help.',
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
    );
  }

  Widget _buildCategoryHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ data model
// ─────────────────────────────────────────────────────────────────────────────

class _FaqItem {
  final String category;
  final String question;
  final String answer;

  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class _FaqSection {
  final String title;
  final List<_FaqItem> items;

  const _FaqSection({required this.title, required this.items});
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

class _FaqTileState extends State<_FaqTile> {
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _goOutsBlue,
          collapsedIconColor: Colors.black45,
          onExpansionChanged: (value) {
            if (!mounted) return;
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
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
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
