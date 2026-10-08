import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';

import 'services/chat_services.dart';
import 'services/push_notification_service.dart';
import 'repositories/chat_repositories.dart';
import 'controllers/chat_controllers.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/profile/user_profile_screen.dart';
import 'services/xp_service.dart';
import 'widgets/app_lock_gate.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // FCM displays notification payloads itself while the app is backgrounded.
  // Render only data-only messages here to avoid duplicate notifications.
  if (message.notification == null) {
    await PushNotificationService.showRemoteMessage(message);
  }
}

Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
  final type = data['type']?.toString() ?? data['notificationType']?.toString();
  final actionId = data['actionId']?.toString() ?? '';
  final prefs = await SharedPreferences.getInstance();
  final currentUserId = prefs.getString('userDocId') ?? '';
  if (currentUserId.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (type == 'message' && actionId.isNotEmpty) {
      Get.to(
        () => ChatScreen(
          chatId: actionId,
          receiverId: data['senderId']?.toString() ?? '',
          currentUserId: currentUserId,
        ),
      );
    } else if ((type == 'friend_request' || type == 'friend_accept') &&
        data['senderId'] != null) {
      Get.to(() => UserProfileScreen(userId: data['senderId'].toString()));
    }
  });
}

Future<void> _setupFCMToken() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final token = await messaging.getToken();

    debugPrint('FCM Token: $token');

    // Store FCM token in user profile
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      final userId =
          FirebaseAuth.instance.currentUser?.uid ??
          prefs.getString('userDocId');

      if (userId != null && userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // Listen to token refresh
    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _updateFCMToken(newToken);
    });
  } catch (e) {
    debugPrint('Error setting up FCM token: $e');
  }
}

Future<void> _updateFCMToken(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? prefs.getString('userDocId');

    if (userId != null && userId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    debugPrint('Error updating FCM token: $e');
  }
}

Future<void> _storeReferralLink(Uri uri) async {
  final referralId = uri.queryParameters['ref']?.trim();
  if (referralId != null && referralId.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pendingReferralId', referralId);
  }
}

Future<void> _setupReferralLinks() async {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen(_storeReferralLink);
  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) await _storeReferralLink(initialUri);
  } catch (e) {
    debugPrint('Referral link setup failed: $e');
  }
}

Future<void> _setUserPresence(bool isOnline) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? prefs.getString('userDocId');

    if (userId == null || userId.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('Error updating user presence: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _setupReferralLinks();

  final messaging = FirebaseMessaging.instance;

  // Channel creation is safe at startup; the runtime permission is requested
  // later from the user-facing notification settings action.
  await PushNotificationService.initialize(
    onNotificationTap: _handleNotificationTap,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    PushNotificationService.showRemoteMessage(message).catchError((error) {
      debugPrint('Foreground notification error: $error');
    });
  });

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      await _setUserPresence(true);
      _setupFCMToken();
    }
  });

  final presenceObserver = _PresenceLifecycleObserver();
  WidgetsBinding.instance.addObserver(presenceObserver);
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    presenceObserver.startUsageTimer();
  }

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(message.data);
  });

  // Setup FCM token after a delay to ensure user is logged in
  Future.delayed(const Duration(seconds: 2), () {
    _setupFCMToken();
  });

  Get.put(ChatService(), permanent: true);
  Get.put(ChatRepository(), permanent: true);
  Get.put(ChatController(), permanent: true);

  runApp(const SynoraApp());

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationTap(initialMessage.data);
  }
}

class _PresenceLifecycleObserver extends WidgetsBindingObserver {
  Timer? _usageTimer;
  final XpService _xpService = XpService();

  void startUsageTimer() {
    _usageTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      _xpService.recordUsage(60).catchError((_) => <String, dynamic>{});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserPresence(true);
      startUsageTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _setUserPresence(false);
      _usageTimer?.cancel();
      _usageTimer = null;
    }
  }
}

class SynoraApp extends StatelessWidget {
  const SynoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Synora',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF5A4BFF),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF17213D),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F3F9),
          hintStyle: const TextStyle(color: Color(0xFF8495B2)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide.none,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5A4BFF),
          brightness: Brightness.light,
        ),
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),

      home: const SplashScreen(),
    );
  }
}
