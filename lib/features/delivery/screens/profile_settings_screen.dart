import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/theme_provider.dart';
import '../../referral/referral_link_screen.dart';
import '../../referral/referral_list_screen.dart';
import '../../referral/merchant_invite_screen.dart';
import 'identity_verification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reskinned 7 September 2026 to the light theme design system in
//  design/STITCH_6_DRAPP.md, using 09_profile_settings_screen as the visual
//  reference.
//
//  ⚠ NOT carried over from the Stitch mockup: the fake driver identity
//  ("Callum Wright", a stock Unsplash avatar photo, "184 trips", "96.8%
//  Acceptance", "Soho • Fitzrovia" active zone — no zone concept exists),
//  the per-document fabricated statuses ("Passport verified", "Certificate
//  submitted", "Right to Work — Share code approved" — none of these are
//  real fields, and there is no UK right-to-work share-code integration
//  anywhere in this app), the Audio Alerts row ("Loud — Helmet speaker" —
//  an invented specific hardware preference with no backend), and the fake
//  "Account identifier GB-DRV-9024" (drivers are identified by their real
//  Firebase uid, not that scheme). The hero card below uses only real
//  `food_drivers` fields: name, photo, rating, totalDeliveries,
//  acceptanceRate, vehicleType, and tier.
//
//  ⚠ REMOVED 7 September 2026 — the "Bank Details •••• •••• •••• 4289
//  Verified" tile. Same problem as the bank fields removed from
//  dapp_registration_screen.dart today: a fabricated card number and a
//  false "Verified" claim on a dead onTap. Replaced with the same honest
//  "not collected yet" notice used there.
//
//  ⚠ CRITICAL: the Light Mode toggle below is real — it drives the actual
//  app-wide ThemeProvider, exactly as before this pass. The Stitch mockup's
//  own Light Mode toggle was fake local state (`bool _isLightMode`); this
//  screen was never going to use that, since the real one already existed
//  and worked.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF2F4F7);
  static const surface  = Color(0xFFFFFFFF);
  static const primary  = Color(0xFF0392CA);
  static const primaryDk = Color(0xFF006488);
  static const navy     = Color(0xFF0D1B3E);
  static const accent   = Color(0xFFF97316);
  static const paleTint = Color(0xFFE0F3FB);
  static const softBlueBox = Color(0xFFEFF4FF);
  static const body     = Color(0xFF475569);
  static const muted    = Color(0xFF94A3B8);
  static const success  = Color(0xFF16A34A);
  static const error    = Color(0xFFDC2626);
  static const errorBg  = Color(0xFFFEE2E2);
  static const border   = Color(0xFFE2E8F0);
}

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _prefs = SharedPreferencesAsync();

  Map<String, dynamic>? _driver;
  bool _showWelcomeBackBanner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Welcome-back carryover banner — added 8 September 2026.
  //  `carriedOverFromDriverApp` is stamped server-side (onFoodDriverRegistered,
  //  admin_panel/functions/food_driver_referral_carryover.js) the first time a
  //  returning driver_app ("GoOuts Lead") driver registers here. It means we
  //  found their existing /drivers record and copied over their verified KYC
  //  evidence and/or their referral relationship, so they don't have to redo
  //  either. Shown once per device, dismissible, per-uid so a shared/reset
  //  device doesn't wrongly suppress it for a different driver.
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('food_drivers').doc(uid).get();
    if (!mounted) return;
    final data = doc.data();
    final carriedOver = data?['carriedOverFromDriverApp'] == true;
    bool dismissed = false;
    if (carriedOver) {
      dismissed = await _prefs.getBool(_welcomeBackDismissedKey(uid)) ?? false;
    }
    if (!mounted) return;
    setState(() {
      _driver = data;
      _showWelcomeBackBanner = carriedOver && !dismissed;
    });
  }

  String _welcomeBackDismissedKey(String uid) => 'welcome_back_carryover_dismissed_$uid';

  Future<void> _dismissWelcomeBackBanner() async {
    final uid = _auth.currentUser?.uid;
    setState(() => _showWelcomeBackBanner = false);
    if (uid != null) {
      await _prefs.setBool(_welcomeBackDismissedKey(uid), true);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: _C.navy, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out? Live dispatch offers will pause.',
            style: TextStyle(color: _C.body, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _C.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  String _vehicleLabel(String? v) {
    switch (v) {
      case 'bicycle': return 'Bicycle';
      case 'scooter': return 'Scooter';
      case 'car':     return 'Car';
      default:        return 'Courier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final name    = (_driver?['name'] as String?)?.trim();
    final photo   = _driver?['profilePhotoUrl'] as String?;
    final rating  = (_driver?['rating']         ?? 5.0).toDouble();
    final trips   = (_driver?['totalDeliveries'] ?? 0) as int;
    final tier    = (_driver?['tier'] as String?) ?? 'Bronze';
    final acceptance = (_driver?['acceptanceRate'] ?? 94).toDouble();
    final vehicle = _vehicleLabel(_driver?['vehicleType'] as String?);
    final displayName = (name == null || name.isEmpty) ? 'Driver' : name;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0.5,
        title: const Text('GoOuts Driver',
            style: TextStyle(color: _C.navy, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          children: [

            // ── Profile hero card ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: _C.paleTint,
                            backgroundImage: photo != null ? NetworkImage(photo) : null,
                            child: photo == null
                                ? Text(displayName[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 26, color: _C.primary, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: _C.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _C.navy)),
                            const SizedBox(height: 2),
                            Text('$vehicle • $tier Tier',
                                style: const TextStyle(fontSize: 12.5, color: _C.body, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCEBFA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_outline_rounded, size: 15, color: _C.primaryDk),
                                  const SizedBox(width: 4),
                                  Text('${rating.toStringAsFixed(2)} Rating',
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: _C.primaryDk)),
                                  const SizedBox(width: 6),
                                  Container(width: 3.5, height: 3.5,
                                      decoration: const BoxDecoration(color: _C.primaryDk, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text('${_formatTrips(trips)} trips',
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w600, color: _C.primaryDk)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _metricBox('Deliveries', '$trips')),
                      const SizedBox(width: 10),
                      Expanded(child: _metricBox('Acceptance', '${acceptance.toInt()}%')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Welcome back — driver_app (GoOuts Lead) carryover ───────
            if (_showWelcomeBackBanner) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                      child: const Icon(Icons.waving_hand_rounded, size: 18, color: Color(0xFF047857)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome back!',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                          const SizedBox(height: 3),
                          Text(
                            (_driver?['referredBy'] as String?)?.isNotEmpty == true
                                ? 'We found your GoOuts Lead account — your verified documents and referral carried over, so nothing to redo.'
                                : 'We found your GoOuts Lead account — your verified documents carried over, so nothing to redo.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismissWelcomeBackBanner,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6, top: 2),
                        child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Light mode toggle — REAL, drives ThemeProvider ──────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  _settingIcon(Icons.wb_sunny_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Light Mode',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _C.navy)),
                        SizedBox(height: 2),
                        Text('Switch to a light layout for better daytime visibility',
                            style: TextStyle(fontSize: 11.5, color: _C.body)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: themeProvider.isLight,
                    onChanged: themeProvider.toggle,
                    activeThumbColor: _C.primaryDk,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

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
                      'Bank details aren\'t collected yet — payout setup will appear here once it\'s ready.',
                      style: TextStyle(fontSize: 12, color: _C.body, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Documents ─────────────────────────────────────────────
            _settingTile(
              icon: Icons.description_outlined,
              title: 'Documents',
              subtitle: 'Manage your required paperwork',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
              ),
            ),

            const SizedBox(height: 14),

            // ── Invite a Driver ───────────────────────────────────────
            _settingTile(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Invite a Driver',
              subtitle: 'Share your code, earn a residual on their deliveries',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReferralLinkScreen()),
              ),
            ),

            const SizedBox(height: 14),

            // ── My Referrals ──────────────────────────────────────────
            _settingTile(
              icon: Icons.groups_outlined,
              title: 'My Referrals',
              subtitle: 'Track who has joined and who is still pending',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReferralListScreen()),
              ),
            ),

            const SizedBox(height: 14),

            // ── Invite a Merchant ─────────────────────────────────────
            _settingTile(
              icon: Icons.storefront_outlined,
              title: 'Invite a Merchant',
              subtitle: 'Invite a restaurant to join GoOuts as a partner',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MerchantInviteScreen()),
              ),
            ),

            const SizedBox(height: 14),

            // ── App Language — informational only; the app is English
            // (UK) only today, so a picker with one option would be
            // decorative. Kept as a plain, honest label.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  _settingIcon(Icons.language_rounded),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('App Language',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _C.navy)),
                  ),
                  const Text('English (UK)', style: TextStyle(fontSize: 12.5, color: _C.body)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Sign Out ──────────────────────────────────────────────
            InkWell(
              onTap: _signOut,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: _C.errorBg, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.logout_rounded, color: _C.error, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Sign out',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.error)),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: _C.muted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _C.softBlueBox, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.body)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.navy)),
          ],
        ),
      );

  Widget _settingIcon(IconData icon) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: _C.softBlueBox, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _C.primaryDk, size: 20),
      );

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              _settingIcon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.navy)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: _C.body, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _C.muted),
            ],
          ),
        ),
      );

  String _formatTrips(int trips) {
    if (trips >= 1000) return '${(trips / 1000).toStringAsFixed(1)}K';
    return trips.toString();
  }
}
