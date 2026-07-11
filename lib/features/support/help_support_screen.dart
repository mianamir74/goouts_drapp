import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'support_ticket_chat_screen.dart';
import 'my_tickets_screen.dart';

// ── Category & sub-topic data ─────────────────────────────────────────────────

class _Category {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<String> subTopics;

  const _Category({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.subTopics,
  });
}

const List<_Category> _categories = [
  _Category(
    id: 'registration',
    label: 'Registration',
    subtitle: 'Stuck, documents, referral code',
    icon: Icons.app_registration_rounded,
    subTopics: ['Stuck during registration', 'Document upload issue', 'Referral code problem', 'Something else'],
  ),
  _Category(
    id: 'verification',
    label: 'Verification',
    subtitle: 'Identity check, approval, rejection',
    icon: Icons.verified_user_rounded,
    subTopics: ['Identity check failed', 'Approval taking too long', 'Account rejected', 'Something else'],
  ),
  _Category(
    id: 'referral',
    label: 'Referral',
    subtitle: 'Reward not credited, code not working',
    icon: Icons.card_giftcard_rounded,
    subTopics: ['Reward not credited', 'Referral code not working', 'Something else'],
  ),
  _Category(
    id: 'technical',
    label: 'Technical',
    subtitle: 'App crash, login, notifications',
    icon: Icons.settings_rounded,
    subTopics: ['App crashing or freezing', 'Cannot log in', 'Notifications not working', 'Something else'],
  ),
  _Category(
    id: 'general',
    label: 'General',
    subtitle: 'Anything else',
    icon: Icons.chat_bubble_outline_rounded,
    subTopics: ['How GoOuts works', 'Delete my account', 'Change my details', 'Something else'],
  ),
  _Category(
    id: 'other',
    label: 'Something Else',
    subtitle: 'Type your own subject',
    icon: Icons.edit_rounded,
    subTopics: [],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({
    super.key,
    required this.accountType,
    required this.collectionName,
  });

  final String accountType;
  final String collectionName;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const Color _goOutsBlue    = Color(0xFF0392CA);
  static const Color _textPrimary   = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder    = Color(0xFFE8EEF3);
  static const Color _softBlueTint  = Color(0xFFF4FAFD);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController    = TextEditingController();
  final TextEditingController _surnameController      = TextEditingController();
  final TextEditingController _emailController        = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _customSubjectController = TextEditingController();
  final TextEditingController _messageController      = TextEditingController();

  bool _isLoading    = true;
  bool _isSubmitting = false;

  _Category? _selectedCategory;
  String?    _selectedSubTopic;
  bool       _showCustomSubject = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _mobileNumberController.dispose();
    _referralCodeController.dispose();
    _customSubjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(user.uid)
              .get();

      final Map<String, dynamic> data = snapshot.data() ?? {};

      _firstNameController.text    = (data['firstName']   ?? '').toString().trim();
      _surnameController.text      = (data['surname']     ?? '').toString().trim();
      _emailController.text        = (data['email']       ?? '').toString().trim();
      _mobileNumberController.text = (data['mobileNumber'] ?? user.phoneNumber ?? '').toString().trim();
      _referralCodeController.text = (data['ownReferralCode'] ?? data['referralCode'] ?? '')
          .toString().trim().toUpperCase();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _softBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _softBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _goOutsBlue, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _emailValidator(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  // ── Category tile ─────────────────────────────────────────────────────────
  Widget _categoryTile(_Category cat) {
    final bool isSelected = _selectedCategory?.id == cat.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory   = cat;
          _selectedSubTopic   = null;
          _showCustomSubject  = cat.id == 'other';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _goOutsBlue.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _goOutsBlue : _softBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: isSelected ? _goOutsBlue.withOpacity(0.12) : const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, size: 18,
              color: isSelected ? _goOutsBlue : _textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat.label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isSelected ? _goOutsBlue : _textPrimary)),
              const SizedBox(height: 2),
              Text(cat.subtitle, style: const TextStyle(
                fontSize: 12, color: _textSecondary)),
            ],
          )),
          if (isSelected)
            const Icon(Icons.check_circle_rounded, color: _goOutsBlue, size: 20),
        ]),
      ),
    );
  }

  // ── Sub-topic tile ────────────────────────────────────────────────────────
  Widget _subTopicTile(String topic) {
    final bool isSelected = _selectedSubTopic == topic;
    final bool isSomethingElse = topic == 'Something else';
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubTopic  = topic;
          _showCustomSubject = isSomethingElse;
          if (!isSomethingElse) _customSubjectController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? _goOutsBlue.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _goOutsBlue : _softBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Icon(
            isSomethingElse ? Icons.edit_rounded : Icons.circle,
            size: isSomethingElse ? 16 : 8,
            color: isSelected ? _goOutsBlue : _textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(topic, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isSelected ? _goOutsBlue : _textPrimary))),
          if (isSelected)
            const Icon(Icons.check_circle_rounded, color: _goOutsBlue, size: 18),
        ]),
      ),
    );
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a category.'),
        behavior: SnackBarBehavior.floating));
      return;
    }

    if (_selectedCategory!.subTopics.isNotEmpty && _selectedSubTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a sub-topic.'),
        behavior: SnackBarBehavior.floating));
      return;
    }

    if (_showCustomSubject && _customSubjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please describe your issue.'),
        behavior: SnackBarBehavior.floating));
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    // Build subject string
    final String subjectLabel = _showCustomSubject
        ? _customSubjectController.text.trim()
        : (_selectedSubTopic ?? _selectedCategory!.label);

    final String fullSubject = _selectedCategory!.id == 'other'
        ? subjectLabel
        : '${_selectedCategory!.label} — $subjectLabel';

    try {
      final String driverName =
          '${_firstNameController.text.trim()} ${_surnameController.text.trim()}'.trim();
      final String messageText = _messageController.text.trim();

      final docRef = await FirebaseFirestore.instance
          .collection('support_requests')
          .add({
        'uid':              user.uid,
        'accountType':      widget.accountType,
        'sourceCollection': widget.collectionName,
        'firstName':        _firstNameController.text.trim(),
        'surname':          _surnameController.text.trim(),
        'email':            _emailController.text.trim(),
        'mobileNumber':     _mobileNumberController.text.trim(),
        'referralCode':     _referralCodeController.text.trim().toUpperCase(),
        'category':         _selectedCategory!.id,
        'categoryLabel':    _selectedCategory!.label,
        'subTopic':         _selectedSubTopic ?? '',
        'subject':          fullSubject,
        'message':          messageText,
        'status':           'new',
        'lastMessage':      messageText,
        'lastMessageAt':    FieldValue.serverTimestamp(),
        'lastMessageBy':    'driver',
        'unreadByAdmin':    true,
        'unreadByDriver':   false,
        'createdAt':        FieldValue.serverTimestamp(),
      });

      // Save ticket number back into document
      await docRef.update({'ticketNumber': docRef.id});

      // Save original message as first entry in messages subcollection
      await docRef.collection('messages').add({
        'sender':     'driver',
        'senderName': driverName,
        'text':       messageText,
        'imageUrl':   '',
        'isRead':     false,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      final String shortTicket = 'SR-${docRef.id.substring(0, 8).toUpperCase()}';

      if (!mounted) return;

      // Show success bottom sheet — returns true if driver chose "Open My Ticket"
      if (!mounted) return;
      final bool openedTicket = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                clipBehavior: Clip.antiAlias,
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
              ),
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Ticket Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B3E))),
              const SizedBox(height: 8),
              Text(
                'Thanks for contacting us. We\'re looking into this and will be in touch shortly.\n\nTicket: $shortTicket',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Return true so we know to navigate to chat, not pop the form
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                  label: const Text('Open My Ticket',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goOutsBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(height: 10),
              // Back to Help — just closes sheet, stays on Help & Support form
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Back to Help',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      ) ?? false;

      if (!mounted) return;

      if (openedTicket) {
        // Navigate to the chat thread for this ticket
        // Do NOT pop HelpSupportScreen — chat sits on top, back arrow returns here
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SupportTicketChatScreen(
            ticketId:         docRef.id,
            subject:          fullSubject,
            ticketNumber:     shortTicket,
            driverName:       driverName,
            sourceCollection: widget.collectionName,
          ),
        ));
      }

      // Always reset form after successful submission
      // so if driver stays on Help & Support they get a fresh form
      _messageController.clear();
      _customSubjectController.clear();
      setState(() {
        _selectedCategory  = null;
        _selectedSubTopic  = null;
        _showCustomSubject = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to submit. Please try again.'),
        behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const AutoSizeText('Help & Support',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          _MyTicketsButton(
            collectionName: widget.collectionName,
            getFullName: () {
              final firstName = _firstNameController.text.trim();
              final surname   = _surnameController.text.trim();
              return [firstName, surname].where((s) => s.isNotEmpty).join(' ');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _goOutsBlue))
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    // ── My Tickets banner ───────────────────────────────────
                    GestureDetector(
                      onTap: () {
                        final firstName = _firstNameController.text.trim();
                        final surname   = _surnameController.text.trim();
                        final fullName  = [firstName, surname]
                            .where((s) => s.isNotEmpty).join(' ');
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => MyTicketsScreen(
                            sourceCollection: widget.collectionName,
                            driverName: fullName.isNotEmpty ? fullName : 'Driver',
                          ),
                        ));
                      },
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _goOutsBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.confirmation_number_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('View My Support Tickets',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                              SizedBox(height: 2),
                              Text('Already submitted a request? Track and reply here.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      height: 1.3)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white70, size: 22),
                        ]),
                      ),
                    ),

                    // ── Info banner ─────────────────────────────────────────
                    Container(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: _softBlueTint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _softBorder)),
                      child: Text(
                        widget.accountType == 'business'
                            ? 'Send a support message for your business account.'
                            : 'Send a support message for your driver account.',
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: _textSecondary,
                            fontWeight: FontWeight.w600)),
                    ),

                    // ── Category tiles ──────────────────────────────────────
                    _SectionCard(
                      title: 'What is your issue about?',
                      subtitle: 'Select the category that best fits your problem.',
                      children: [
                        ..._categories.map((cat) => _categoryTile(cat)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Sub-topic tiles (appears after category selected) ────
                    if (_selectedCategory != null &&
                        _selectedCategory!.subTopics.isNotEmpty) ...[
                      _SectionCard(
                        title: 'Select the specific issue',
                        subtitle: '',
                        children: [
                          ..._selectedCategory!.subTopics
                              .map((t) => _subTopicTile(t)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Custom subject (Something else) ─────────────────────
                    if (_showCustomSubject) ...[
                      _SectionCard(
                        title: 'Describe your issue',
                        subtitle: '',
                        children: [
                          TextFormField(
                            controller: _customSubjectController,
                            decoration:
                                _inputDecoration(label: 'Brief description'),
                            validator: (v) =>
                                (_showCustomSubject &&
                                        (v == null || v.trim().isEmpty))
                                    ? 'Please describe your issue'
                                    : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Message + Submit ─────────────────────────────────────
                    if (_selectedCategory != null &&
                        (_selectedSubTopic != null ||
                            _selectedCategory!.id == 'other')) ...[
                      _SectionCard(
                        title: 'Your Message',
                        subtitle: 'Provide as much detail as possible.',
                        children: [
                          TextFormField(
                            controller: _messageController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: _inputDecoration(
                              label: 'Describe your issue in detail',
                              alignLabelWithHint: true,
                            ),
                            validator: (v) =>
                                _requiredValidator(v, 'Message'),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 54,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _goOutsBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14))),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white))
                                  : const AutoSizeText('Submit',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// ── My Tickets AppBar button with unread badge ───────────────────────────────
class _MyTicketsButton extends StatelessWidget {
  final String collectionName;
  final String Function() getFullName;

  const _MyTicketsButton({
    required this.collectionName,
    required this.getFullName,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .where('uid', isEqualTo: uid)
          .where('unreadByDriver', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final unreadCount = snap.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () {
            final fullName = getFullName();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyTicketsScreen(
                  sourceCollection: collectionName,
                  driverName: fullName.isNotEmpty ? fullName : 'Driver',
                ),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0392CA).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF0392CA).withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.confirmation_number_rounded, size: 16, color: Color(0xFF0392CA)),
                  SizedBox(width: 5),
                  Text(
                    'My Tickets',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0392CA),
                    ),
                  ),
                ]),
              ),
              // Red badge
              if (unreadCount > 0)
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
                      unreadCount > 9 ? '9+' : '$unreadCount',
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
        );
      },
    );
  }
}

// ── Reusable section card ─────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1C))),
          const SizedBox(height: 4),
          AutoSizeText(subtitle,
            style: const TextStyle(fontSize: 12, height: 1.45,
              color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}