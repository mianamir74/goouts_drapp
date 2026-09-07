import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Rebuilt 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md. No Stitch mockup exists for this screen —
//  rebuilt from the live file alone.
//
//  ⚠ REPLACED, not just reskinned. `_capturePhoto()` used to just be
//  `setState(() => _photoTaken = true)` with a comment "In production: use
//  camera_awesome or image_picker" — no camera ever opened, no photo ever
//  taken, uploaded, or stored anywhere. Tapping the shutter instantly showed
//  "PHOTO CAPTURED" for a photo that didn't exist. `_confirm()` then just
//  did `Navigator.pop(context, true)`, and the caller (active_delivery_
//  screen's `_markDelivered`) marks the order `delivered` in Firestore the
//  moment it sees `true` — so on a screen with a "Photo Verification —
//  REQUIRED" badge and a "Privacy note: Photos are only stored temporarily"
//  disclaimer, no photo was ever required, taken, or stored. Now: a real
//  camera capture via image_picker, uploaded to Firebase Storage at
//  `orders/{orderId}/proof_of_delivery.jpg`, with the URL written to the
//  order doc before the screen reports success.
//
//  Also removed: the "Enter Customer PIN" fallback. It accepted any 4
//  digits and called the same `_confirm()` with zero validation — there is
//  no `deliveryPin`/`dropOffCode` field anywhere in the schema for it to
//  check against, so it was a fake security check, not a real alternative.
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
  static const success   = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
}

/// Called from ActiveDeliveryScreen when the driver taps "Mark Delivered".
/// The driver takes a real photo of the package at the door.
class DeliveryVerificationScreen extends StatefulWidget {
  final String orderId;
  const DeliveryVerificationScreen({super.key, required this.orderId});

  @override
  State<DeliveryVerificationScreen> createState() =>
      _DeliveryVerificationScreenState();
}

class _DeliveryVerificationScreenState
    extends State<DeliveryVerificationScreen> {
  final _picker  = ImagePicker();
  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  XFile? _photo;
  bool _confirming = false;

  Future<void> _capturePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _photo = picked);
  }

  Future<void> _confirm() async {
    if (_photo == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final ref = _storage.ref('orders/${widget.orderId}/proof_of_delivery.jpg');
      await ref.putFile(File(_photo!.path));
      final url = await ref.getDownloadURL();
      await _db.collection('food_orders').doc(widget.orderId).set(
        {'proofOfDeliveryUrl': url},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save photo: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photo != null;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Photo Verification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.navy)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: _C.paleTint, borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.center,
            child: Row(
              children: const [
                Icon(Icons.verified_user, color: _C.primaryDk, size: 14),
                SizedBox(width: 4),
                Text('REQUIRED', style: TextStyle(color: _C.primaryDk, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Instruction card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _C.paleTint, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.door_front_door_outlined, color: _C.primaryDk),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Confirm Delivery Spot',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.navy)),
                          SizedBox(height: 4),
                          Text(
                            'Take a clear photo of the package at the customer\'s '
                            'door. Ensure the apartment number is visible if possible.',
                            style: TextStyle(color: _C.body, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Camera preview ─────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: _capturePhoto,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: _C.surface,
                      border: Border.all(color: hasPhoto ? _C.success : const Color(0xFFE2E8F0), width: hasPhoto ? 2 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: hasPhoto
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(File(_photo!.path), fit: BoxFit.cover),
                                Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                          color: _C.success.withOpacity(0.92), borderRadius: BorderRadius.circular(12)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 12),
                                          Text('PHOTO CAPTURED',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(color: _C.paleTint, shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt_outlined, color: _C.primaryDk, size: 28),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text('TAP TO CAPTURE',
                                          style: TextStyle(color: _C.navy, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Shutter ────────────────────────────────────────────────
              _shutterBtn(),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (hasPhoto && !_confirming) ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _confirming
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check),
                            SizedBox(width: 8),
                            Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: const [
                  Icon(Icons.info_outline, color: _C.primary, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This photo is stored to confirm the delivery and may be shared with GoOuts Support if there\'s a dispute.',
                      style: TextStyle(color: _C.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shutterBtn() => GestureDetector(
        onTap: _capturePhoto,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: _C.paleTint, shape: BoxShape.circle),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: const BoxDecoration(color: _C.primaryDk, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
          ),
        ),
      );
}
