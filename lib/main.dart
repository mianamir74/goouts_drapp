import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/delivery/screens/dapp_onboarding_screen.dart';
import 'features/delivery/screens/dapp_login_screen.dart';
import 'features/delivery/screens/main_delivery_scaffold.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/theme_provider.dart';
import 'features/auth/fresh_install_guard.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics ─────────────────────────────────────────────────────────────
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  await DriverFcmService.instance.initialize();
  await ThemeProvider.instance.load();

  // ── THE FRESH-INSTALL GUARD MOVED OUT OF HERE ──────────────────────────
  //
  // 14 August 2026. It used to be awaited on this line, before runApp.
  //
  // Until runApp is called Flutter has painted nothing — iOS shows the static
  // launch image and nothing else. The guard was changed earlier the same day
  // to await the first authStateChanges event, allowed up to five seconds, so
  // a slow cold start meant up to five seconds of frozen picture.
  //
  // That is the exact failure this file already documents for FCM: "a
  // guaranteed ~10s blank screen then crash on every launch". Same mistake,
  // different await.
  //
  // It now runs in _Bootstrap below, behind the loading screen.

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
      home: const _Bootstrap(),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Runs the fresh-install guard WHILE the loading screen is on screen.
//
//  The guard clears a session that survived an app deletion. On iOS the
//  Keychain is not wiped when an app is removed, so without this a reinstalled
//  app opens straight into the PREVIOUS OWNER's account — nobody typed a PIN
//  and nobody received a code.
//
//  ⚠ IT IS AWAITED BEFORE THE REAL GATE IS BUILT, ON PURPOSE. Building the
//  gate first would render that previous owner's screen for a moment before
//  the sign-out landed. A moment is long enough to read a name and a status.
// ─────────────────────────────────────────────────────────────────────────────
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await enforceFreshInstallSignOut();
    } catch (e) {
      // Fail open. The guard already defaults to the safe option internally;
      // a storage error must not leave anyone stuck on a loading screen.
      debugPrint('bootstrap: continuing after error — $e');
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0392ca)),
        ),
      );
    return const _AppGate();
  }
}
