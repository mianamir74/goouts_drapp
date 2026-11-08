import 'package:flutter/material.dart';

/// GoOuts brand badge: the official blue G app icon, rounded.
class GoOutsLogo extends StatelessWidget {
  final double size;
  const GoOutsLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0392CA).withValues(alpha: 0.28),
              blurRadius: size * 0.2,
              offset: Offset(0, size * 0.07)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset('assets/logo/goouts_g_badge.png',
            width: size, height: size, fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            cacheWidth: (size * 3).round()),
      ),
    );
  }
}
