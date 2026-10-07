import 'package:flutter/material.dart';

// goouts_drapp's existing, live features/referral/referral_link_screen.dart
// is already role-aware (it reads the signed-in user's own referral code
// from whichever collection applies, including 'lead_partners' — see its
// own Firestore reads). driver_app's BusinessReferralLinkScreen was itself
// just a thin passthrough to the equivalent generic screen in its own tree,
// so this mirrors that shape while pointing at goouts_drapp's shared screen
// instead of duplicating it.
import '../../referral/referral_link_screen.dart';

class BusinessReferralLinkScreen extends StatelessWidget {
  const BusinessReferralLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReferralLinkScreen();
  }
}
