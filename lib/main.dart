import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/delivery/screens/dapp_onboarding_screen.dart';
import 'features/delivery/screens/dapp_login_screen.dart';
import 'features/delivery/screens/main_delivery_scaffold.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/theme_provider.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await DriverFcmService.instance.initialize();
  await ThemeProvider.instance.load();

  runApp(
    ChangeNotifierProvider.value(
      value: ThemeProvider.instance,
      child: const GoOutsDriverApp(),
    ),
  );
}

class GoOutsDriverApp extends StatelessWidget {
  const GoOutsDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'GoOuts Driver',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: rootNavigatorKey,
      themeMode: themeProvider.themeMode,
      theme: ThemeProvider.light,
      darkTheme: ThemeProvider.dark,
      home: const _AppGate(),
    );
  }
}

/// Decides whether to show onboarding, login, or main app.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _checkingAuth = true;
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Brief delay so Firebase auth state settles
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _checkingAuth = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF031134),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0392ca)),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF031134),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0392ca)),
            ),
          );
        }

        final user = snap.data;

        if (user != null) {
          // Already logged in → go straight to main app
          return const MainDeliveryScaffold();
        }

        if (!_onboardingDone) {
          return DappOnboardingScreen();
        }

        return const DappLoginScreen();
      },
    );
  }
}
