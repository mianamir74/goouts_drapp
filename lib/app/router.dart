import 'package:go_router/go_router.dart';

import '../features/auth/otp_screen.dart';
import '../features/auth/phone_login_screen.dart';
import '../features/common/placeholder_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const PhoneLoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final verificationId = state.extra as String? ?? '';

        return OtpScreen(verificationId: verificationId);
      },
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/referral-link',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Referral Link',
        message:
            'This is where the driver will see and share a personal referral link.',
      ),
    ),
    GoRoute(
      path: '/referrals',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Referrals',
        message: 'This screen will later show joined and pending referrals.',
      ),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Messages',
        message:
            'This screen will later show the driver inbox and message details.',
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Profile',
        message:
            'This screen will later show profile details and Terms & Conditions.',
      ),
    ),
  ],
);