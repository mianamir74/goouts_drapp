import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'main_delivery_scaffold.dart';

class DappRegistrationScreen extends StatefulWidget {
  const DappRegistrationScreen({super.key});

  @override
  State<DappRegistrationScreen> createState() =>
      _DappRegistrationScreenState();
}

class _DappRegistrationScreenState extends State<DappRegistrationScreen> {
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _accountHolder = TextEditingController();
  final _routingCtrl   = TextEditingController();
  final _accountCtrl   = TextEditingController();
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
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneCtrl,
      _accountHolder, _routingCtrl, _accountCtrl, _referralCtrl
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _profilePhoto = File(picked.path));
  }

  Future<void> _pickLicense() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
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
        'referralCode':    _referralCtrl.text.trim(),
        'bankAccountHolder': _accountHolder.text.trim(),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Registration',
            style: TextStyle(
                color: Color(0xFF0392ca),
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Step indicator ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Step 1 of 4',
                    style: TextStyle(
                        color: Color(0xFF0392ca),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const Text('Personal Info',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFF0392ca)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 28),

            // ── Profile photo ─────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFF0b1a3d),
                      backgroundImage: _profilePhoto != null
                          ? FileImage(_profilePhoto!)
                          : null,
                      child: _profilePhoto == null
                          ? const Icon(Icons.add_a_photo_outlined,
                              size: 34, color: Colors.white54)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text('Upload Profile Photo',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Form fields ───────────────────────────────────────
            _field('Full Name', 'John Doe', _nameCtrl),
            const SizedBox(height: 18),
            _field('Email Address', 'john@example.com', _emailCtrl,
                type: TextInputType.emailAddress),
            const SizedBox(height: 18),
            _field('Phone Number', '+1 (555) 000-0000', _phoneCtrl,
                type: TextInputType.phone),

            const SizedBox(height: 28),

            // ── Vehicle type ──────────────────────────────────────
            const Text('Vehicle Type',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: [
                _vehicle(Icons.directions_bike, 'Bicycle', 0),
                const SizedBox(width: 10),
                _vehicle(Icons.moped, 'Scooter', 1),
                const SizedBox(width: 10),
                _vehicle(Icons.directions_car, 'Car', 2),
              ],
            ),

            const SizedBox(height: 28),

            // ── License upload ────────────────────────────────────
            const Text("Driver's License (Front)",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickLicense,
              child: Container(
                width: double.infinity,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white24,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _licenseFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_licenseFile!,
                            fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_upload_outlined,
                              size: 32, color: Color(0xFF0392ca)),
                          SizedBox(height: 10),
                          Text('Tap to upload image',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Stripe banner ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0392ca).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0392ca).withOpacity(0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      size: 20, color: Color(0xFF0392ca)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Secure payments with Stripe',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white)),
                        SizedBox(height: 4),
                        Text(
                          'Your bank details are securely processed by Stripe. We do not store your banking information directly.',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Bank details ──────────────────────────────────────
            _field('Account Holder Name', 'John Doe', _accountHolder),
            const SizedBox(height: 18),
            _field('Routing Number', '000000000', _routingCtrl,
                type: TextInputType.number),
            const SizedBox(height: 18),
            _field('Account Number', '••••••••••••', _accountCtrl,
                obscure: true, type: TextInputType.number),

            const SizedBox(height: 40),

            // ── Referral code ─────────────────────────────────────
            Center(
              child: Column(
                children: [
                  const Icon(Icons.card_giftcard,
                      size: 52, color: Color(0xFF10b981)),
                  const SizedBox(height: 14),
                  const Text('Got a Referral Code?',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter it below to claim your sign-up bonus after your first 10 deliveries.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0b1a3d),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: _referralCtrl,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'CODE123',
                        hintStyle: TextStyle(
                            color: Colors.white24,
                            letterSpacing: 4,
                            fontSize: 22),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => _referralCtrl.clear(),
                    child: const Text('Skip for now',
                        style: TextStyle(
                            color: Colors.white54,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white54)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Continue button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0392ca),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Continue',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white70)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0b1a3d),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: type,
              obscureText: obscure,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24),
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
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0b1a3d),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? const Color(0xFF0392ca)
                  : Colors.white10,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: sel
                      ? const Color(0xFF0392ca)
                      : Colors.white54,
                  size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : Colors.white54,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
