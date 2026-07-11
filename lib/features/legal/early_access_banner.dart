import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

/// Reusable Early Access banner.
/// Shown on the role selection screen and referenced in Terms & Conditions.
class EarlyAccessBanner extends StatelessWidget {
  const EarlyAccessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.campaign_rounded,
                color: Color(0xFF0392CA),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Early Access — Lead Generation App',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0392CA),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          AutoSizeText(
            'GoOuts is currently in pre-launch phase. This app is not yet a live '
            'platform and no business activity take place here.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          SizedBox(height: 6),
          AutoSizeText(
            'Register now to secure your place, invite friends using your '
            'referral code, track your invitees, and be first to know '
            'when GoOuts goes live in your area.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
