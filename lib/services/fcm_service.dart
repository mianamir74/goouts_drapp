import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('FCM background message received: ${message.messageId}');
  debugPrint('FCM background data: ${message.data}');
}

class DriverFcmService {
  DriverFcmService._();

  static final DriverFcmService instance = DriverFcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final StreamController<RemoteMessage> _foregroundMessagesController =
      StreamController<RemoteMessage>.broadcast();

  final StreamController<RemoteMessage> _openedMessagesController =
      StreamController<RemoteMessage>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _initialized = false;
  RemoteMessage? _initialOpenedMessage;

  Stream<RemoteMessage> get foregroundMessages =>
      _foregroundMessagesController.stream;

  Stream<RemoteMessage> get openedMessages =>
      _openedMessagesController.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await _messaging.setAutoInitEnabled(true);

    final NotificationSettings settings = await _requestPermission();
    await _syncTokenForCurrentUser(
      notificationsEnabled: _isNotificationsEnabled(settings),
    );

    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    _initialOpenedMessage = await _messaging.getInitialMessage();

    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen((String newToken) async {
      await _saveTokenForCurrentUser(
        token: newToken,
        notificationsEnabled: await _areNotificationsEnabledNow(),
      );
    });

    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        debugPrint('FCM auth listener: user signed out.');
        return;
      }

      await _syncTokenForCurrentUser();
    });
  }

  RemoteMessage? consumeInitialOpenedMessage() {
    final RemoteMessage? message = _initialOpenedMessage;
    _initialOpenedMessage = null;
    return message;
  }

  Future<NotificationSettings> requestPermissionAgain() async {
    final NotificationSettings settings = await _requestPermission();

    await _syncTokenForCurrentUser(
      notificationsEnabled: _isNotificationsEnabled(settings),
    );

    return settings;
  }

  Future<void> syncTokenForCurrentUser() async {
    await _syncTokenForCurrentUser();
  }

  Future<String?> getCurrentToken() async {
    return _messaging.getToken();
  }

  Future<bool> areNotificationsEnabled() async {
    return _areNotificationsEnabledNow();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message received: ${message.messageId}');
    debugPrint('FCM foreground data: ${message.data}');

    if (message.notification != null) {
      debugPrint(
        'FCM foreground notification title: ${message.notification?.title}',
      );
      debugPrint(
        'FCM foreground notification body: ${message.notification?.body}',
      );
    }

    _foregroundMessagesController.add(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('FCM notification opened: ${message.messageId}');
    debugPrint('FCM opened data: ${message.data}');

    _openedMessagesController.add(message);
  }

  Future<NotificationSettings> _requestPermission() async {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _syncTokenForCurrentUser({
    bool? notificationsEnabled,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      debugPrint('FCM token sync skipped: no logged-in user.');
      return;
    }

    final String? token = await _messaging.getToken();

    if (token == null || token.isEmpty) {
      debugPrint('FCM token sync skipped: token is null or empty.');
      return;
    }

    await _saveTokenForCurrentUser(
      token: token,
      notificationsEnabled:
          notificationsEnabled ?? await _areNotificationsEnabledNow(),
    );
  }

  Future<void> _saveTokenForCurrentUser({
  required String token,
  required bool notificationsEnabled,
}) async {
  final User? user = _auth.currentUser;

  if (user == null) {
    debugPrint('FCM token save skipped: no logged-in user.');
    return;
  }

  final DocumentSnapshot<Map<String, dynamic>> businessDoc =
      await _firestore.collection('businesses').doc(user.uid).get();

  final DocumentSnapshot<Map<String, dynamic>> driverDoc =
      await _firestore.collection('drivers').doc(user.uid).get();

  final DocumentSnapshot<Map<String, dynamic>> cabDriverDoc =
      await _firestore.collection('cab_drivers').doc(user.uid).get();

  String targetCollection;

  if (businessDoc.exists) {
    targetCollection = 'businesses';
  } else if (driverDoc.exists) {
    targetCollection = 'drivers';
  } else if (cabDriverDoc.exists) {
    targetCollection = 'cab_drivers';
  } else {
    debugPrint(
      'FCM token save skipped: no business, driver, or cab_driver profile exists for ${user.uid}.',
    );
    return;
  }

  await _firestore.collection(targetCollection).doc(user.uid).set(
    {
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': notificationsEnabled,
    },
    SetOptions(merge: true),
  );

  debugPrint('FCM token saved under $targetCollection/${user.uid}');
}

  Future<bool> _areNotificationsEnabledNow() async {
    final NotificationSettings settings =
        await _messaging.getNotificationSettings();

    return _isNotificationsEnabled(settings);
  }

  bool _isNotificationsEnabled(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundMessagesController.close();
    await _openedMessagesController.close();
  }
}