import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'main_delivery_scaffold.dart';
import 'package:goouts_drapp/features/common/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 04_registration_screen as the visual
//  reference, card-by-card, on this app's existing single-page form (not
//  the mockup's separate Personal/Vehicle/Identity/Review pages — this form
//  has always submitted everything in one go, and turning that into a real
//  multi-step wizard is a bigger change than a visual reskin; the section
//  headers below label the same groupings without claiming they're
//  separate, un-submitted steps).
//
//  ⚠ REMOVED 7 September 2026 — the bank details section (Account Holder
//  Name, Routing Number, Account Number). It captured raw banking details
//  into plain TextEditingControllers, under a banner claiming "Secure
//  payments with Stripe" — but there was no Stripe integration anywhere in
//  this file, and _submit() never even saved the routing/account numbers
//  to Firestore. The fields went nowhere while promising bank-grade
//  security. Collecting real banking details needs a real Stripe Connect
//  (or equivalent) onboarding flow — that is a payout-system build, which
//  per this project's standing rule does not happen without being asked
//  for directly. Replaced with an honest "not collected yet" notice.
//
//  ⚠ CHANGED 7 September 2026 — the Phone Number field used to be an
//  editable text field that _submit() silently ignored (it saved
//  `_auth.currentUser?.phoneNumber` instead, the number already verified by
//  OTP). Editing it did nothing. Replaced with a read-only display of the
//  actually-verified number.
//
//  ⚠ CHANGED 7 September 2026 — the licence photo picker now opens the
//  camera directly (ImageSource.camera) instead of the gallery, matching
//  the "camera capture only, no gallery imports" anti-fraud note this
//  design carries — a real behavioural change, not just new copy.
//
//  ⚠ SOFTENED 7 September 2026 — the mockup's "£50 completion incentive
//  applied" is a specific, unconfirmed bonus figure (see
//  design/DRIVER_PAY_ALGORITHM_SPEC.md — no signup bonus has been decided).
//  Replaced with a description of what the referral system actually does
//  today: it credits the referrer's residual income once this driver is
//  approved.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const softBlueBg = Color(0xFFEFF5FD);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const success  = Color(0xFF16A34A);
  static const border   = Color(0xFFE2E8F0);
}

class DappRegistrationScreen extends StatefulWidget {
  const DappRegistrationScreen({super.key});

  @override
  State<DappRegistrationScreen> createState() =>
      _DappRegistrationScreenState();
}

class _DappRegistrationScreenState extends State<DappRegistrationScreen> {
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _referralCtrl  = TextEditingController();

  int  _vehicleIdx = 0; // 0=Bicycle, 1=Scooter, 2=Car
  File? _profilePhoto;
  File? _licenseFile;
  bool _loading = false;

  final _picker = ImagePicker();
  final _db     = FirebaseFirestore.instance;
  final _auth   = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _referralCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _profilePhoto = File(picked.path));
  }

  Future<void> _pickLicense() async {
    // Camera only — matches the anti-fraud note below, and this app has no
    // gallery-swap fraud check, so it should not offer a gallery path here.
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _licenseFile = File(picked.path));
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    setState(() => _loading = true);
    try {
      final uid  = _auth.currentUser!.uid;
      String? photoUrl;
      String? licenseUrl;

      if (_profilePhoto != null) {
        final ref = _storage.ref('drivers/$uid/profile.jpg');
        await ref.putFile(_profilePhoto!);
        photoUrl = await ref.getDownloadURL();
      }
      if (_licenseFile != null) {
        final ref = _storage.ref('drivers/$uid/license.jpg');
        await ref.putFile(_licenseFile!);
        licenseUrl = await ref.getDownloadURL();
      }

      await _db.collection('food_drivers').doc(uid).set({
        'uid':             uid,
        'name':            name,
        'email':           _emailCtrl.text.trim(),
        'phone':           _auth.currentUser?.phoneNumber ?? '',
        'vehicleType':     ['bicycle', 'scooter', 'car'][_vehicleIdx],
        'profilePhotoUrl': photoUrl,
        'licenseUrl':      licenseUrl,
        // ⚠ FIXED 8 September 2026 — this used to write ONLY 'referralCode',
        // but food_driver_referral_carryover.js's onFoodDriverRegistered
        // reads 'referralCodeUsed' to resolve who referred this driver.
        // Every brand-new registration that typed a code here was silently
        // never resolving it (only driver_app veterans with a legacy
        // /drivers.referredBy already set were ever getting credited, via
        // that trigger's fallback path). Writing both: 'referralCode' stays
        // for whatever else may read it, 'referralCodeUsed' is the one the
        // resolver actually needs.
        'referralCode':     _referralCtrl.text.trim(),
        'referralCodeUsed': _referralCtrl.text.trim(),
        'isOnline':        false,
        'status':          'pending_approval',
        'rating':          5.0,
        'totalDeliveries': 0,
        'deliveriesToday': 0,
        'earnedToday':     0.0,
        'tipsToday':       0.0,
        'tier':            'Bronze',
        'createdAt':       FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const MainDeliveryScaffold()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    GoOutsSheet.error(context, title: 'Error', message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final verifiedPhone = _auth.currentUser?.phoneNumber ?? 'Not verified';

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Driver Registration',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Personal details card ────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.badge_outlined, size: 20, color: _C.primary),
                      SizedBox(width: 8),
                      Text('Personal details',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _C.navy)),
                    ]),
                    const SizedBox(height: 16),

                    // Profile photo
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: _C.paleTint,
                              backgroundImage: _profilePhoto != null
                                  ? FileImage(_profilePhoto!)
                                  : null,
                              child: _profilePhoto == null
                                  ? const Icon(Icons.add_a_photo_outlined,
                                      size: 30, color: _C.primary)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            const Text('Upload profile photo',
                                style: TextStyle(color: _C.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _field('Full Name', 'John Doe', _nameCtrl),
                    const SizedBox(height: 16),
                    _field('Email Address', 'john@example.com', _emailCtrl,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 16),

                    const Text('Mobile number',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _C.body)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _C.softBlueBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.primary.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.verified_rounded, size: 16, color: _C.success),
                        const SizedBox(width: 8),
                        Text(verifiedPhone,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _C.navy)),
                        const Spacer(),
                        const Text('Verified',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _C.success)),
                      ]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Vehicle selector card ────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.directions_car_outlined, size: 20, color: _C.primary),
                      SizedBox(width: 8),
                      Text('Registered vehicle',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _C.navy)),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _vehicle(Icons.directions_bike_rounded, 'Bicycle', 0),
                        const SizedBox(width: 10),
                        _vehicle(Icons.electric_moped_rounded, 'E-Scooter /\nMoped', 1),
                        const SizedBox(width: 10),
                        _vehicle(Icons.directions_car_rounded, 'Car', 2),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Identity & compliance card ───────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.verified_user_outlined, size: 20, color: _C.accent),
                      SizedBox(width: 8),
                      Text('Identity & compliance',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _C.navy)),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.shield_outlined, size: 18, color: _C.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Camera capture only — gallery imports are disabled for fraud prevention.',
                              style: TextStyle(fontSize: 11.5, color: _C.body, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickLicense,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _licenseFile != null ? _C.success : _C.border,
                          ),
                        ),
                        child: _licenseFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_licenseFile!,
                                    height: 100, fit: BoxFit.cover),
                              )
                            : Column(
                                children: const [
                                  Icon(Icons.camera_alt_outlined,
                                      size: 26, color: _C.primary),
                                  SizedBox(height: 8),
                                  Text('Take photo of driving licence (front)',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _C.primary)),
                                  SizedBox(height: 2),
                                  Text('Tap to open camera',
                                      style: TextStyle(fontSize: 11, color: _C.muted)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Payout details — honestly not collected yet ──────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.paleTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 16, color: _C.primaryDk),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bank details aren\'t collected during sign-up yet — you\'ll be prompted to set up payouts securely once your account is approved.',
                        style: TextStyle(fontSize: 12, color: _C.body, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Referral code card ────────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Referral code (Optional)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.navy)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF5FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.primary.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _referralCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.navy,
                            letterSpacing: 0.5),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter referral code',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Credits your referrer\'s residual income once you\'re approved.',
                      style: TextStyle(fontSize: 12, color: _C.body),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accent,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: _C.accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Submit Application',
                                style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),

              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'By continuing you confirm that the captured documents belong to you and comply with UK right to work regulations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: _C.body, height: 1.35),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _field(
    String label,
    String hint,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: _C.body)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: type,
              obscureText: obscure,
              style: const TextStyle(color: _C.navy, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _C.muted),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      );

  Widget _vehicle(IconData icon, String label, int idx) {
    final sel = _vehicleIdx == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleIdx = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: sel ? _C.primaryDk : const Color(0xFFEFF5FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? _C.primaryDk : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: sel ? Colors.white : _C.primary, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sel ? Colors.white : _C.navy,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 11.5,
                      height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
