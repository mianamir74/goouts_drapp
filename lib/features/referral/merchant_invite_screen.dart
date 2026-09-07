import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MerchantInviteScreen — a driver invites a restaurant/business to join
//  GoOuts as a cashback partner.
//
//  Written 7 September 2026. food_drivers already reserved
//  merchantReferralCount and merchantResidualEarned (see firestore.rules and
//  earnings_screen.dart, which has been reading and displaying both since
//  before this screen existed) — the residual-earning idea was already real,
//  there was just no screen to actually send a merchant invite from. This
//  mirrors referral_link_screen.dart's proven WhatsApp-invite pattern
//  (driver invites), aimed at a business instead of a driver.
//
//  Reuses the SAME referral code as driver invites — one code per driver,
//  food_drivers.referralCode, tracked by invite type rather than by a second
//  code. sent_merchant_invites is a NEW subcollection, separate from
//  sent_invites (driver invites), so the two never collide.
//
//  ⚠ NOT BUILT: a "My Merchant Referrals" list screen equivalent to
//  referral_list_screen.dart. sent_merchant_invites is written correctly
//  from here so that screen can be built later without a data migration —
//  today there is just no UI reading it back. Flagged, not faked.
// ─────────────────────────────────────────────────────────────────────────────
class MerchantInviteScreen extends StatefulWidget {
  const MerchantInviteScreen({super.key});

  @override
  State<MerchantInviteScreen> createState() => _MerchantInviteScreenState();
}

class _MerchantInviteScreenState extends State<MerchantInviteScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);
  static const String _inviteBaseUrl = 'https://goouts.app/invite';
  static const String _defaultReferralCode = 'GD100001';
  static const int _referralCodeCoreLength = 6;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isEnsuringReferralCode = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _generateReferralCode(String uid) {
    final String cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return _defaultReferralCode;
    final String core = cleaned.length >= _referralCodeCoreLength
        ? cleaned.substring(cleaned.length - _referralCodeCoreLength)
        : cleaned.padLeft(_referralCodeCoreLength, '0');
    return 'GD' + core;
  }

  String _resolveReferralCode(String uid, Map<String, dynamic>? data) {
    final String ownCode = ((data?['referralCode'] ?? data?['ownReferralCode']) ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (ownCode.isNotEmpty) return ownCode;
    return _generateReferralCode(uid);
  }

  Future<void> _ensureReferralCode(String uid, String existingCode) async {
    if (_isEnsuringReferralCode || existingCode.trim().isNotEmpty) return;
    setState(() => _isEnsuringReferralCode = true);
    try {
      final String generated = _generateReferralCode(uid);
      await FirebaseFirestore.instance.collection('food_drivers').doc(uid).set(
        {
          'referralCode': generated,
          'ownReferralCode': generated,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) setState(() => _isEnsuringReferralCode = false);
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _normalizeUkPhoneForWhatsApp(String phone) {
    final String digits = _digitsOnly(phone);
    if (digits.isEmpty) return '';
    if (digits.startsWith('07') && digits.length == 11) return '44${digits.substring(1)}';
    if (digits.startsWith('7') && digits.length == 10) return '44$digits';
    if (digits.startsWith('44') && digits.length == 12) {
      final String local = digits.substring(2);
      if (local.startsWith('7') && local.length == 10) return digits;
    }
    return '';
  }

  String? _ukPhoneValidator(String? value) {
    final String raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Please enter a WhatsApp number';
    final String digits = _digitsOnly(raw);
    if (digits.startsWith('07')) {
      if (digits.length != 11) return 'Enter full UK mobile number';
    } else if (digits.startsWith('7')) {
      if (digits.length != 10) return 'Enter full UK mobile number';
    } else {
      return 'Use a UK mobile starting with 07';
    }
    if (_normalizeUkPhoneForWhatsApp(raw).isEmpty) {
      return 'Enter a valid UK WhatsApp mobile';
    }
    return null;
  }

  List<TextInputFormatter> _ukPhoneFormatters() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ];

  String _generateInviteToken({required String inviterUid, required String inviteePhone}) {
    final String phonePart = inviteePhone.replaceAll(RegExp(r'[^0-9]'), '').padLeft(10, '0');
    final String uidPart = inviterUid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final String timestampPart = DateTime.now().millisecondsSinceEpoch.toString();
    final String uidSuffix = uidPart.isEmpty
        ? 'GD0000'
        : (uidPart.length > 6 ? uidPart.substring(uidPart.length - 6) : uidPart.padLeft(6, '0'));
    final String phoneSuffix =
        phonePart.length > 6 ? phonePart.substring(phonePart.length - 6) : phonePart.padLeft(6, '0');
    return '$uidSuffix$phoneSuffix$timestampPart'.toUpperCase();
  }

  String _buildInviteMessage({
    required String businessName,
    required String contactName,
    required String referralCode,
    required String inviteLink,
  }) {
    final String safeContact = contactName.trim().isEmpty ? 'there' : contactName.trim();
    final String safeBusiness = businessName.trim().isEmpty ? 'your business' : businessName.trim();
    return "Hi $safeContact,\n\n"
        "I'm a GoOuts delivery driver and I'd like to invite $safeBusiness to join GoOuts as a cashback partner.\n\n"
        "GoOuts customers pay with their GoOuts card at partner restaurants, pubs, cafes and shops and earn cashback automatically, "
        "bringing you more footfall from a network that's already looking for places like yours.\n\n"
        "Please enter this referral code when you sign up:\n\n"
        "$referralCode\n\n"
        "Get started here:\n"
        "$inviteLink";
  }

  Future<void> _saveInviteRecord({
    required String inviterUid,
    required String inviterReferralCode,
    required String businessName,
    required String contactName,
    required String phoneRaw,
    required String phoneNormalized,
    required String inviteToken,
    required String inviteLink,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final String inviteId =
        firestore.collection('food_drivers').doc(inviterUid).collection('sent_merchant_invites').doc().id;

    final Map<String, dynamic> inviteData = {
      'inviteId': inviteId,
      'inviteToken': inviteToken,
      'inviterUid': inviterUid,
      'businessName': businessName.trim(),
      'contactName': contactName.trim(),
      'inviteePhone': phoneRaw.trim(),
      'inviteePhoneNormalized': phoneNormalized,
      'referralCode': inviterReferralCode,
      'status': 'pending',
      'source': 'whatsapp',
      'accountType': 'food_driver',
      'inviteType': 'merchant',
      'sentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reminderCount': 0,
      'inviteLink': inviteLink,
      'joinedBusinessUid': '',
      'joinedAt': null,
      'lastReminderAt': null,
    };

    final batch = firestore.batch();
    batch.set(
      firestore.collection('food_drivers').doc(inviterUid).collection('sent_merchant_invites').doc(inviteId),
      inviteData,
      SetOptions(merge: true),
    );
    // Mirrors 'invites' (driver invites) — a separate top-level collection
    // so a merchant clicking their link doesn't collide with driver-invite
    // token lookups.
    batch.set(
      firestore.collection('merchant_invites').doc(inviteToken),
      inviteData,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    GoOutsSheet.info(context, title: 'GoOuts', message: message);
  }

  Future<void> _submit(String referralCode) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String businessName = _businessNameController.text.trim();
    final String contactName = _contactNameController.text.trim();
    final String phoneRaw = _phoneController.text.trim();
    final String phoneNormalized = _normalizeUkPhoneForWhatsApp(phoneRaw);

    if (phoneNormalized.isEmpty) {
      _showMessage('Please enter a valid UK WhatsApp number.');
      return;
    }

    setState(() => _isSubmitting = true);

    final String inviteToken = _generateInviteToken(inviterUid: user.uid, inviteePhone: phoneNormalized);
    final String inviteLink = '$_inviteBaseUrl?merchantToken=$inviteToken';
    final String message = _buildInviteMessage(
      businessName: businessName,
      contactName: contactName,
      referralCode: referralCode,
      inviteLink: inviteLink,
    );

    try {
      await _saveInviteRecord(
        inviterUid: user.uid,
        inviterReferralCode: referralCode,
        businessName: businessName,
        contactName: contactName,
        phoneRaw: phoneRaw,
        phoneNormalized: phoneNormalized,
        inviteToken: inviteToken,
        inviteLink: inviteLink,
      );

      final Uri uri = Uri.parse('https://wa.me/$phoneNormalized?text=${Uri.encodeComponent(message)}');
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        await Clipboard.setData(ClipboardData(text: message));
        _showMessage('Invite saved. WhatsApp could not open, so the message was copied instead.');
      } else {
        _showMessage('Invite saved and WhatsApp opened.');
        _businessNameController.clear();
        _contactNameController.clear();
        _phoneController.clear();
      }
    } catch (e) {
      _showMessage('Failed to save invite.\n$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _goOutsBlue, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No logged-in user found.')));
    }

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Invite a Merchant', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('food_drivers').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isEnsuringReferralCode) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          final String referralCode = _resolveReferralCode(user.uid, data);

          if (referralCode.isEmpty) {
            _ensureReferralCode(user.uid, referralCode);
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _goOutsBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.storefront_rounded, size: 34, color: _goOutsBlue),
                        ),
                        const SizedBox(height: 16),
                        const AutoSizeText('Your Referral Code',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(height: 10),
                        AutoSizeText(referralCode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _goOutsBlue)),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'The same code you use to invite drivers — GoOuts tracks driver and merchant referrals separately under it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Business details',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter the restaurant or business you want to invite, and it will be saved so you can track whether they join.',
                          style: TextStyle(color: Colors.black54, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _businessNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDecoration(label: 'Business Name', hint: "e.g. Joe's Pizza Corner"),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a business name' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _contactNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDecoration(label: 'Contact Name', hint: 'Owner or manager name'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a contact name' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: _ukPhoneFormatters(),
                          decoration: _fieldDecoration(label: 'WhatsApp Number', hint: '07000000000'),
                          validator: _ukPhoneValidator,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : () => _submit(referralCode),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.storefront_outlined),
                            label: const Text('Invite via WhatsApp',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
