import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/theme_provider.dart';
import 'identity_verification_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _driver;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('food_drivers').doc(uid).get();
    if (!mounted) return;
    setState(() => _driver = doc.data());
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0b1a3d),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFf43f5e))),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final name    = _driver?['name']           ?? 'Alex Rodriguez';
    final photo   = _driver?['profilePhotoUrl'] as String?;
    final rating  = (_driver?['rating']         ?? 4.92).toDouble();
    final trips   = _driver?['totalDeliveries'] ?? 3421;
    final tier    = _driver?['tier']            ?? 'Gold Partner';
    final tierPts = _driver?['ptsToNextTier']   ?? 45;
    final tierProg = (_driver?['tierProgress']  ?? 0.75).toDouble();

    final licenseOk   = _driver?['licenseVerified']   ?? true;
    final insuranceOk = _driver?['insuranceVerified']  ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031134),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('GoOuts Driver',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFF0b1a3d),
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          children: [

            // ── Profile card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFF031134),
                        backgroundImage: photo != null
                            ? NetworkImage(photo)
                            : null,
                        child: photo == null
                            ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'D',
                                style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0392ca),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.star,
                              color: Color(0xFFf97316), size: 16),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          Text('• ${_formatTrips(trips)} Trips',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white54, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Tier progress ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CURRENT TIER',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold)),
                      Text('$tierPts pts to Platinum',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('- ',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 16)),
                    Text(tier,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0392ca))),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: tierProg,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0392ca)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Light mode toggle ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0b1a3d),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.light_mode_outlined,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Light Mode',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    Switch(
                      value: themeProvider.isLight,
                      onChanged: themeProvider.toggle,
                      activeThumbColor: const Color(0xFF0392ca),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 36),
                    child: Text(
                      'Switch to a light layout for better daytime visibility',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Bank details ──────────────────────────────────────────
            _settingTile(
              icon: Icons.account_balance_outlined,
              title: 'Bank Details',
              subtitle: '•••• •••• •••• 4289',
              trailing: const Text('Verified',
                  style: TextStyle(
                      color: Color(0xFF10b981),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              onTap: () {},
            ),

            const SizedBox(height: 14),

            // ── Documents ─────────────────────────────────────────────
            _settingTile(
              icon: Icons.description_outlined,
              title: 'Documents',
              subtitle: 'Manage your required paperwork',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _docBadge('License', licenseOk),
                  const SizedBox(width: 8),
                  _docBadge('Insurance', insuranceOk),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const IdentityVerificationScreen()),
              ),
            ),

            const SizedBox(height: 32),

            // ── Sign Out ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_outlined, size: 20),
                label: const Text('Sign Out',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf43f5e),
                  side: BorderSide(
                      color: const Color(0xFFf43f5e).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0b1a3d),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    if (trailing == null)
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13))
                    else ...[
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 8),
                      trailing,
                    ],
                  ],
                ),
              ),
              if (trailing == null) ...[
                trailing ?? const SizedBox.shrink(),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ] else
                const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      );

  Widget _docBadge(String label, bool ok) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ok
              ? const Color(0xFF10b981).withOpacity(0.12)
              : const Color(0xFFf43f5e).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: ok
                  ? const Color(0xFF10b981).withOpacity(0.4)
                  : const Color(0xFFf43f5e).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 13,
              color: ok ? const Color(0xFF10b981) : const Color(0xFFf43f5e),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: ok
                        ? const Color(0xFF10b981)
                        : const Color(0xFFf43f5e),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  String _formatTrips(int trips) {
    if (trips >= 1000) return '${(trips / 1000).toStringAsFixed(1)}K';
    return trips.toString();
  }
}
