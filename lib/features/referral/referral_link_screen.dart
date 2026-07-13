import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/models/driver_model.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

class ReferralLinkScreen extends StatefulWidget {
  const ReferralLinkScreen({super.key});

  @override
  State<ReferralLinkScreen> createState() => _ReferralLinkScreenState();
}

class _ReferralLinkScreenState extends State<ReferralLinkScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);
  static const String _inviteBaseUrl = 'https://goouts.app/invite';
  static const String _defaultDriverReferralCode = 'GD100001';
  static const String _defaultBusinessReferralCode = 'GB000001';
  static const int _driverReferralCodeCoreLength = 6;
  static const int _businessReferralCodeCoreLength = 6;

  bool _isEnsuringReferralCode = false;

  String _generateOwnReferralCode(String uid) {
    final String cleaned =
        uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    if (cleaned.isEmpty) {
      return _defaultDriverReferralCode;
    }

    final String core = cleaned.length >= _driverReferralCodeCoreLength
        ? cleaned.substring(cleaned.length - _driverReferralCodeCoreLength)
        : cleaned.padLeft(_driverReferralCodeCoreLength, '0');

    return 'GD' + core;
  }

  String _generateBusinessReferralCode(String uid) {
    final String cleaned =
        uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    if (cleaned.isEmpty) {
      return _defaultBusinessReferralCode;
    }

    final String core = cleaned.length >= _businessReferralCodeCoreLength
        ? cleaned.substring(cleaned.length - _businessReferralCodeCoreLength)
        : cleaned.padLeft(_businessReferralCodeCoreLength, '0');

    return 'GB' + core;
  }

  String _resolveDriverReferralCode({
    required String uid,
    required Map<String, dynamic>? data,
  }) {
    final Map<String, dynamic> merged = <String, dynamic>{
      'uid': uid,
      ...?data,
    };

    final DriverModel driver = DriverModel.fromMap(merged);
    String ownCode = driver.referralCode.trim().toUpperCase();

    if (ownCode.isNotEmpty) {
      return _normalizeDriverCode(ownCode, uid);
    }

    String fallbackOwnCode =
        (data?['ownReferralCode'] ?? '').toString().trim().toUpperCase();
    if (fallbackOwnCode.isNotEmpty) {
      return _normalizeDriverCode(fallbackOwnCode, uid);
    }

    return _generateOwnReferralCode(uid);
  }

  String _normalizeDriverCode(String code, String uid) {
    String normalized =
        code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (!normalized.startsWith('GD')) {
      return _generateOwnReferralCode(uid);
    }

    normalized = normalized.substring(2);
    if (normalized.isEmpty) {
      return _generateOwnReferralCode(uid);
    }

    if (normalized.length > _driverReferralCodeCoreLength) {
      normalized =
          normalized.substring(normalized.length - _driverReferralCodeCoreLength);
    } else if (normalized.length < _driverReferralCodeCoreLength) {
      normalized = normalized.padLeft(_driverReferralCodeCoreLength, '0');
    }

    return 'GD' + normalized;
  }

  String _resolveBusinessReferralCode({
    required String uid,
    required Map<String, dynamic>? data,
  }) {
    String ownCode =
        (data?['ownReferralCode'] ?? '').toString().trim().toUpperCase();

    if (ownCode.isNotEmpty) {
      return _normalizeBusinessCode(ownCode, uid);
    }

    String referralCode =
        (data?['referralCode'] ?? '').toString().trim().toUpperCase();

    if (referralCode.isNotEmpty) {
      return _normalizeBusinessCode(referralCode, uid);
    }

    return _generateBusinessReferralCode(uid);
  }

  String _normalizeBusinessCode(String code, String uid) {
    String normalized =
        code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (!normalized.startsWith('GB')) {
      return _generateBusinessReferralCode(uid);
    }

    normalized = normalized.substring(2);
    if (normalized.isEmpty) {
      return _generateBusinessReferralCode(uid);
    }

    if (normalized.length > _businessReferralCodeCoreLength) {
      normalized =
          normalized.substring(normalized.length - _businessReferralCodeCoreLength);
    } else if (normalized.length < _businessReferralCodeCoreLength) {
      normalized = normalized.padLeft(_businessReferralCodeCoreLength, '0');
    }

    return 'GB' + normalized;
  }

  Future<void> _ensureOwnReferralCode({
    required String uid,
    required String existingCode,
    required bool isBusiness,
  }) async {
    if (_isEnsuringReferralCode) return;
    if (existingCode.trim().isNotEmpty) return;

    setState(() {
      _isEnsuringReferralCode = true;
    });

    try {
      final String generatedCode = isBusiness
          ? _generateBusinessReferralCode(uid)
          : _generateOwnReferralCode(uid);

      final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore
          .instance
          .collection(isBusiness ? 'businesses' : 'drivers')
          .doc(uid);

      await docRef.set(
        <String, dynamic>{
          'referralCode': generatedCode,
          'ownReferralCode': generatedCode,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!isBusiness)
            'referralDetails': <String, dynamic>{
              'ownReferralCode': generatedCode,
            },
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEnsuringReferralCode = false;
        });
      }
    }
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizeUkPhoneForWhatsApp(String phone) {
    final String digits = _digitsOnly(phone);

    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('07') && digits.length == 11) {
      return '44${digits.substring(1)}';
    }

    if (digits.startsWith('7') && digits.length == 10) {
      return '44$digits';
    }

    if (digits.startsWith('44') && digits.length == 12) {
      final String localPart = digits.substring(2);
      if (localPart.startsWith('7') && localPart.length == 10) {
        return digits;
      }
    }

    return '';
  }

  String _formatUkPhoneForDisplay(String phone) {
    final String digits = _digitsOnly(phone);

    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('07') && digits.length <= 11) {
      return digits;
    }

    if (digits.startsWith('7') && digits.length <= 10) {
      return '0$digits';
    }

    if (digits.startsWith('44') && digits.length <= 12) {
      final String localPart = digits.substring(2);
      if (localPart.startsWith('7')) {
        return '0$localPart';
      }
    }

    return digits;
  }

  String? _ukPhoneValidator(String? value) {
    final String raw = value?.trim() ?? '';

    if (raw.isEmpty) {
      return 'Please enter WhatsApp number';
    }

    final String digits = _digitsOnly(raw);

    if (digits.startsWith('07')) {
      if (digits.length != 11) {
        return 'Enter full UK mobile number';
      }
    } else if (digits.startsWith('7')) {
      if (digits.length != 10) {
        return 'Enter full UK mobile number';
      }
    } else {
      return 'Use a UK mobile starting with 07';
    }

    final String normalized = _normalizeUkPhoneForWhatsApp(raw);

    if (normalized.isEmpty) {
      return 'Enter a valid UK WhatsApp mobile';
    }

    return null;
  }

  List<TextInputFormatter> _ukPhoneFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(11),
      TextInputFormatter.withFunction((oldValue, newValue) {
        final String digits = _digitsOnly(newValue.text);

        if (digits.isEmpty) {
          return const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          );
        }

        if (digits.length == 1) {
          if (digits != '0' && digits != '7') {
            return oldValue;
          }
        }

        if (digits.length >= 2) {
          final bool validPrefix =
              digits.startsWith('07') || digits.startsWith('7');
          if (!validPrefix) {
            return oldValue;
          }
        }

        if (digits.startsWith('7') && !digits.startsWith('07')) {
          if (digits.length > 10) {
            return oldValue;
          }
        }

        if (digits.startsWith('07') && digits.length > 11) {
          return oldValue;
        }

        return TextEditingValue(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length),
        );
      }),
    ];
  }

  String _generateInviteToken({
    required String inviterUid,
    required String inviteePhone,
  }) {
    final String phonePart =
        inviteePhone.replaceAll(RegExp(r'[^0-9]'), '').padLeft(10, '0');
    final String uidPart =
        inviterUid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final String timestampPart = DateTime.now().millisecondsSinceEpoch.toString();

    final String uidSuffix = uidPart.isEmpty
        ? 'GD0000'
        : (uidPart.length > 6
            ? uidPart.substring(uidPart.length - 6)
            : uidPart.padLeft(6, '0'));

    final String phoneSuffix = phonePart.length > 6
        ? phonePart.substring(phonePart.length - 6)
        : phonePart.padLeft(6, '0');

    return '$uidSuffix$phoneSuffix$timestampPart'.toUpperCase();
  }

  String _buildInviteLink(String inviteToken) {
    return '$_inviteBaseUrl?token=$inviteToken';
  }

  String _buildInviteMessage({
    required String inviteeName,
    required String referralCode,
    required String inviteLink,
    required bool isBusiness,
    bool isCabDriver = false,
  }) {
    final String safeName =
        inviteeName.trim().isEmpty ? 'there' : inviteeName.trim();

    if (isBusiness) {
      return "Hi $safeName,\n\n"
          "I'm a Business Partner with GoOuts and I'd like to invite you to join as a food delivery driver.\n\n"
          "GoOuts is expanding and looking for drivers who want flexible delivery work with a simple onboarding process.\n\n"
          "You can also earn additional income by inviting other drivers once you join.\n\n"
          "Please download the GoOuts Driver Registration app and enter this referral code during registration:\n\n"
          "$referralCode\n\n"
          "Complete your signup here:\n"
          "$inviteLink";
    }

    if (isCabDriver) {
      return "Hi $safeName,\n\n"
          "I've joined GoOuts Rider Driver, a new platform launching soon with a strong residual income model for drivers.\n\n"
          "You can earn up to 5% from your referrals' earnings, grow your portfolio automatically, and track everything from your dashboard.\n\n"
          "Secure your spot early and start inviting friends - because if you don't invite them, someone else will.\n\n"
          "Download the GoOuts Driver Registration app and enter this referral code during registration:\n\n"
          "$referralCode\n\n"
          "Complete your signup here:\n"
          "$inviteLink";
    }

    return "Hi $safeName,\n\n"
        "I've joined GoOuts Food Delivery, a new platform launching soon with a strong residual income model for drivers.\n\n"
        "You can earn up to 5% from your referrals' earnings, grow your portfolio automatically, and track everything from your dashboard.\n\n"
        "Secure your spot early and start inviting friends - because if you don't invite them, someone else will.\n\n"
        "Download the GoOuts Driver Registration app and enter this referral code during registration:\n\n"
        "$referralCode\n\n"
        "Complete your signup here:\n"
        "$inviteLink";
  }

  String _buildPreviewMessage({
    required String inviteeName,
    required String referralCode,
    required bool isBusiness,
    bool isCabDriver = false,
  }) {
    final String safeName =
        inviteeName.trim().isEmpty ? '[Invitee Name]' : inviteeName.trim();

    if (isBusiness) {
      return "Hi $safeName,\n\n"
          "I'm a Business Partner with GoOuts and I'd like to invite you to join as a food delivery driver.\n\n"
          "GoOuts is expanding and looking for drivers who want flexible delivery work with a simple onboarding process.\n\n"
          "You can also earn additional income by inviting other drivers once you join.\n\n"
          "Please download the GoOuts Driver Registration app and enter this referral code during registration:\n\n"
          "$referralCode\n\n"
          "Complete your signup here:\n"
          "[Invite Link will be added automatically]";
    }

    if (isCabDriver) {
      return "Hi $safeName,\n\n"
          "I've joined GoOuts Rider Driver, a new platform launching soon with a strong residual income model for drivers.\n\n"
          "You can earn up to 5% from your referrals' earnings, grow your portfolio automatically, and track everything from your dashboard.\n\n"
          "Secure your spot early and start inviting friends - because if you don't invite them, someone else will.\n\n"
          "Download the GoOuts Driver Registration app and enter this referral code during registration:\n\n"
          "$referralCode\n\n"
          "Complete your signup here:\n"
          "[Invite Link will be added automatically]";
    }

    return "Hi $safeName,\n\n"
        "I've joined GoOuts Food Delivery, a new platform launching soon with a strong residual income model for drivers.\n\n"
        "You can earn up to 5% from your referrals' earnings, grow your portfolio automatically, and track everything from your dashboard.\n\n"
        "Secure your spot early and start inviting friends - because if you don't invite them, someone else will.\n\n"
        "Download the GoOuts Driver Registration app and enter this referral code during registration:\n\n"
        "$referralCode\n\n"
        "Complete your signup here:\n"
        "[Invite Link will be added automatically]";
  }

  Future<void> _copyText(
    BuildContext context, {
    required String text,
    required String successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    _showSnackBarMessage(successMessage);
  }

  void _showSnackBarMessage(String message) {
    if (!mounted) return;
    GoOutsSheet.info(context, title: 'GoOuts', message: message);
  }

  Future<bool> _launchWhatsAppToPhone({
    required String normalizedPhone,
    required String message,
  }) async {
    final Uri uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );

    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _saveInviteRecord({
    required String inviterUid,
    required String inviterReferralCode,
    required String inviteId,
    required String inviteToken,
    required String inviteeName,
    required String inviteePhoneRaw,
    required String inviteePhoneNormalized,
    required String inviteLink,
    required bool isBusiness,
    bool isCabDriver = false,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String ownerCollection = isBusiness ? 'businesses' : isCabDriver ? 'cab_drivers' : 'drivers';
    final String ownerAccountType = isBusiness ? 'business' : isCabDriver ? 'cab_driver' : 'driver';

    final Map<String, dynamic> inviteData = <String, dynamic>{
      'inviteId': inviteId,
      'inviteToken': inviteToken,
      'inviterUid': inviterUid,
      'inviteeName': inviteeName.trim(),
      'inviteePhone': _formatUkPhoneForDisplay(inviteePhoneRaw),
      'inviteePhoneNormalized': inviteePhoneNormalized,
      'referralCode': inviterReferralCode,
      'status': 'pending',
      'source': 'whatsapp',
      'accountType': ownerAccountType,
      'sentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reminderCount': 0,
      'inviteLink': inviteLink,
      'joinedDriverUid': '',
      'joinedDriverName': '',
      'joinedDriverSelfieUrl': '',
      'clickedAt': null,
      'startedAt': null,
      'joinedAt': null,
      'lastReminderAt': null,
      'isDemo': false,
    };

    final WriteBatch batch = firestore.batch();

    batch.set(
      firestore
          .collection(ownerCollection)
          .doc(inviterUid)
          .collection('sent_invites')
          .doc(inviteId),
      inviteData,
      SetOptions(merge: true),
    );

    batch.set(
      firestore.collection('invites').doc(inviteToken),
      inviteData,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Widget _ukPhonePrefix() {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(left: 12, right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoSizeText(
            '🇬🇧',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(width: 6),
          Text(
            '+44',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteDriverSheet({
    required String inviterUid,
    required String referralCode,
    required bool isBusiness,
    bool isCabDriver = false,
  }) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    bool isSubmitting = false;
    bool hasAcceptedNotice = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final String previewMessage = _buildPreviewMessage(
              inviteeName: nameController.text.trim(),
              referralCode: referralCode,
              isBusiness: isBusiness,
              isCabDriver: isCabDriver,
            );

            Future<void> submitInvite() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              if (!hasAcceptedNotice) {
                _showSnackBarMessage(
                  'Please confirm that this invite will be saved in My Referrals.',
                );
                return;
              }

              final String inviteeName = nameController.text.trim();
              final String inviteePhoneRaw = phoneController.text.trim();
              final String inviteePhoneNormalized =
                  _normalizeUkPhoneForWhatsApp(inviteePhoneRaw);

              if (inviteePhoneNormalized.isEmpty) {
                _showSnackBarMessage('Please enter a valid UK WhatsApp number.');
                return;
              }

              setModalState(() {
                isSubmitting = true;
              });

              final String ownerCollection = isBusiness ? 'businesses' : isCabDriver ? 'cab_drivers' : 'drivers';

              final String inviteId = FirebaseFirestore.instance
                  .collection(ownerCollection)
                  .doc(inviterUid)
                  .collection('sent_invites')
                  .doc()
                  .id;

              final String inviteToken = _generateInviteToken(
                inviterUid: inviterUid,
                inviteePhone: inviteePhoneNormalized,
              );

              final String inviteLink = _buildInviteLink(inviteToken);

              final String inviteMessage = _buildInviteMessage(
                inviteeName: inviteeName,
                referralCode: referralCode,
                inviteLink: inviteLink,
                isBusiness: isBusiness,
                isCabDriver: isCabDriver,
              );

              try {
                await _saveInviteRecord(
                  inviterUid: inviterUid,
                  inviterReferralCode: referralCode,
                  inviteId: inviteId,
                  inviteToken: inviteToken,
                  inviteeName: inviteeName,
                  inviteePhoneRaw: inviteePhoneRaw,
                  inviteePhoneNormalized: inviteePhoneNormalized,
                  inviteLink: inviteLink,
                  isBusiness: isBusiness,
                  isCabDriver: isCabDriver,
                );

                final bool launched = await _launchWhatsAppToPhone(
                  normalizedPhone: inviteePhoneNormalized,
                  message: inviteMessage,
                );

                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }

                if (!launched) {
                  await Clipboard.setData(ClipboardData(text: inviteMessage));
                  _showSnackBarMessage(
                    'Invite saved in My Referrals. WhatsApp could not open, so the message was copied.',
                  );
                  return;
                }

                _showSnackBarMessage(
                  'Invite saved in My Referrals and WhatsApp opened successfully.',
                );
              } catch (e) {
                setModalState(() {
                  isSubmitting = false;
                });

                _showSnackBarMessage('Failed to save invite.\n$e');
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
              child: Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              clipBehavior: Clip.antiAlias,
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _goOutsBlue.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.person_add_alt_1_rounded,
                                color: _goOutsBlue,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AutoSizeText(
                                    'Invite Driver',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  AutoSizeText(
                                    'Save the invite first, then send it on WhatsApp.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: AutoSizeText(
                            'The invitee name and WhatsApp number entered here will be saved in your dashboard under My Referrals so you can track whether they are still pending or have joined GoOuts.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _sheetInputDecoration(
                            label: 'Invitee Name',
                            hint: 'Enter full name',
                          ),
                          onChanged: (_) {
                            setModalState(() {});
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter invitee name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: _ukPhoneFormatters(),
                          decoration: _sheetInputDecoration(
                            label: 'WhatsApp Number',
                            hint: '07000000000',
                            prefixWidget: _ukPhonePrefix(),
                          ).copyWith(
                            helperText:
                                'Enter UK mobile number e.g. 07000000000',
                          ),
                          validator: _ukPhoneValidator,
                        ),
                        SizedBox(height: 14),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AutoSizeText(
                                'Message Preview',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              SizedBox(height: 10),
                              AutoSizeText(
                                previewMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.55,
                                  color: Color(0xFF4B5563),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        CheckboxListTile(
                          value: hasAcceptedNotice,
                          contentPadding: EdgeInsets.zero,
                          activeColor: _goOutsBlue,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: AutoSizeText(
                            'I understand this contact will be saved in My Referrals so I can track their join status.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              hasAcceptedNotice = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _goOutsBlue,
                                  side: const BorderSide(color: _goOutsBlue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting ? null : submitInvite,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save & WhatsApp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }

  static InputDecoration _sheetInputDecoration({
    required String label,
    required String hint,
    Widget? prefixWidget,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      prefixIcon: prefixWidget,
      prefixIconConstraints: prefixWidget == null
          ? null
          : const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
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
        borderSide: BorderSide(
          color: _goOutsBlue,
          width: 1.3,
        ),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(
          color: Colors.red,
          width: 1.3,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadBusinessData(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection('businesses').doc(uid).get();
    return snapshot.data();
  }

  bool _isBusinessProfile(Map<String, dynamic>? data) {
    if (data == null) {
      return false;
    }

    final String accountType =
        (data['accountType'] ?? '').toString().trim().toLowerCase();
    final String dashboardRole =
        (data['dashboardRole'] ?? '').toString().trim().toLowerCase();
    final String legalBusinessName =
        (data['legalBusinessName'] ?? '').toString().trim();
    final String companyNumber =
        (data['companyNumber'] ?? '').toString().trim();

    return accountType == 'business' ||
        dashboardRole == 'business' ||
        legalBusinessName.isNotEmpty ||
        companyNumber.isNotEmpty;
  }

  Widget _buildReferralContent({
    required User currentUser,
    required String referralCode,
    required bool isBusiness,
    bool isCabDriver = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _goOutsBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 34,
                    color: _goOutsBlue,
                  ),
                ),
                SizedBox(height: 16),
                AutoSizeText(
                  'Your Referral Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 10),
                AutoSizeText(
                  referralCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _goOutsBlue,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _copyText(
                      context,
                      text: referralCode,
                      successMessage: 'Referral code copied',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _goOutsBlue,
                      side: const BorderSide(color: _goOutsBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Copy Referral Code',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  'Invite Driver via WhatsApp',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                const Text(
                  'Enter the invitee name and UK WhatsApp number, save the invite, and then send it on WhatsApp. The saved invite will appear in My Referrals so you can track whether they stay pending or later join.',
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _showInviteDriverSheet(
                      inviterUid: currentUser.uid,
                      referralCode: referralCode,
                      isBusiness: isBusiness,
                      isCabDriver: isCabDriver,
                    ),
                    icon: Icon(Icons.person_add_alt_1_rounded),
                    label: AutoSizeText(
                      'Invite Driver via WhatsApp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _goOutsBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverStream(User currentUser, {bool isCabDriver = false}) {
    final String driverCollection = isCabDriver ? 'cab_drivers' : 'drivers';
    final DocumentReference<Map<String, dynamic>> currentDriverRef =
        FirebaseFirestore.instance.collection(driverCollection).doc(currentUser.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: currentDriverRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isEnsuringReferralCode) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load referral details.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final Map<String, dynamic>? data = snapshot.data?.data();

        final String referralCode = _resolveDriverReferralCode(
          uid: currentUser.uid,
          data: data,
        );

        debugPrint(
          'REFERRAL DEBUG: ${data?['referralCode']} / ${data?['ownReferralCode']} -> $referralCode',
        );

        if (referralCode.isEmpty) {
          _ensureOwnReferralCode(
            uid: currentUser.uid,
            existingCode: referralCode,
            isBusiness: false,
          );

          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return _buildReferralContent(
          currentUser: currentUser,
          referralCode: referralCode,
          isBusiness: false,
          isCabDriver: isCabDriver,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('No logged-in user found.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'My Referral Link',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadBusinessData(currentUser.uid),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final Map<String, dynamic>? businessData = businessSnapshot.data;
          final bool isBusiness = _isBusinessProfile(businessData);

          if (isBusiness) {
            final String referralCode = _resolveBusinessReferralCode(
              uid: currentUser.uid,
              data: businessData,
            );

            if (referralCode.isEmpty) {
              _ensureOwnReferralCode(
                uid: currentUser.uid,
                existingCode: referralCode,
                isBusiness: true,
              );

              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return _buildReferralContent(
              currentUser: currentUser,
              referralCode: referralCode,
              isBusiness: true,
            );
          }

          // Check cab_drivers before falling back to drivers
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('cab_drivers')
                .doc(currentUser.uid)
                .get(),
            builder: (context, cabSnapshot) {
              if (cabSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final bool isCabDriver = cabSnapshot.data?.exists ?? false;
              return _buildDriverStream(currentUser, isCabDriver: isCabDriver);
            },
          );
        },
      ),
    );
  }
}
