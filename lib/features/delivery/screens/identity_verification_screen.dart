import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rebuilt 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 10_identity_verification_screen as a
//  loose visual reference — not a literal port.
//
//  ⚠ REPLACED, not just reskinned. The screen this file used to contain was
//  a live "facial scan" animation: tap Start Scan, wait 2 seconds
//  (`Future.delayed`), and it unconditionally set `_verified = true` and
//  showed "Identity Verified ✓" — with no camera, no biometric SDK, no
//  liveness check, and no Firestore write of any kind. On a screen titled
//  "Secure Your Account", that is a fabricated success state on the single
//  worst screen to fake one on.
//
//  The Stitch reference for this screen goes further in the other
//  direction — DVLA hologram checks, a Home Office Right to Work share-code
//  flow, specific licence expiry dates, "2 of 3 Verified" readiness scoring
//  — none of which this app has any backend for. There is no
//  courier_kyc/compliance_audits collection, no verification-status field
//  ever written by anything, and registration only ever collects one
//  document: the driving licence photo (see dapp_registration_screen.dart).
//
//  What replaces both: a real, working document screen. It shows whether a
//  licence photo has actually been submitted (reading `licenseUrl` off the
//  real `food_drivers` doc), lets the driver (re)capture it via the camera
//  — uploaded for real to Firebase Storage, written for real to Firestore,
//  same pattern as registration — and is honest that insurance and Right to
//  Work documents are not collected by this app yet, rather than inventing
//  fake Approved/Pending statuses for them.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const success  = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const softBox  = Color(0xFFF8FAFC);
  static const softBoxBorder = Color(0xFFEDF2F7);
}

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _db      = FirebaseFirestore.instance;
  final _auth    = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker  = ImagePicker();

  bool _loading = true;
  bool _uploading = false;
  String? _licenseUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final doc = await _db.collection('food_drivers').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _licenseUrl = doc.data()?['licenseUrl'] as String?;
      _loading = false;
    });
  }

  Future<void> _captureLicense() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // Camera only — matches the anti-fraud note below.
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final ref = _storage.ref('drivers/$uid/license.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _db.collection('food_drivers').doc(uid).set(
        {'licenseUrl': url},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {
        _licenseUrl = url;
        _uploading = false;
      });
    } catch (e) {
      // ⚠ FIXED 8 September 2026 — this used to fail completely silently:
      // the spinner would stop and the driver would be left assuming the
      // upload worked when it hadn't, with no way to tell without retrying
      // blind. Found during the post-build security/failure-mode review.
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t upload your photo — check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLicense = (_licenseUrl ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Documents',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Driving licence card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _C.paleTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.badge_outlined, color: _C.primaryDk, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Driving Licence',
                                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _C.navy)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: hasLicense ? _C.successBg : const Color(0xFFFFEDD5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          hasLicense ? 'Submitted' : 'Not submitted',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: hasLicense ? _C.success : const Color(0xFFC2410C)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasLicense
                                        ? 'On file — reviewed manually before your account is fully approved.'
                                        : 'Front side photo, all text legible',
                                    style: const TextStyle(fontSize: 12, color: _C.body),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (hasLicense)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_licenseUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _uploading ? null : _captureLicense,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                            label: Text(hasLicense ? 'Retake photo' : 'Take photo',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.primaryDk,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Insurance / Right to Work — honestly not collected ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.hourglass_empty_rounded, size: 18, color: _C.muted),
                          SizedBox(width: 8),
                          Text('Insurance & Right to Work',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _C.navy)),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'These aren\'t collected in the app yet. If they\'re required for your account, our team will contact you directly.',
                          style: TextStyle(fontSize: 12.5, color: _C.body, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Fraud prevention note ────────────────────────────
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
                        Icon(Icons.lock_person_outlined, color: _C.primaryDk, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Camera capture only — gallery imports are disabled for fraud prevention.',
                            style: TextStyle(fontSize: 12, color: _C.body, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
