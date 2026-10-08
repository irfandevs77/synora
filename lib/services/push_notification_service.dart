import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String messagesChannelId = 'synora_messages';
  static const String friendRequestsChannelId = 'synora_friend_requests';
  static const String callsChannelId = 'synora_calls';
  static const String generalChannelId = 'synora_general';

  static const String _allNotificationsKey = 'notifications_all';
  static const String _messagesKey = 'notifications_messages';
  static const String _friendRequestsKey = 'notifications_friend_requests';
  static const String _callsKey = 'notifications_calls';
  static const String _generalKey = 'notifications_general';

  static const Map<String, String> preferenceKeys = {
    'message': _messagesKey,
    'reply': _messagesKey,
    'mention': _messagesKey,
    'reaction': _messagesKey,
    'friend_request': _friendRequestsKey,
    'friend_accept': _friendRequestsKey,
    'call': _callsKey,
    'incoming_call': _callsKey,
  };

  static Future<Map<String, bool>> getNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'all': prefs.getBool(_allNotificationsKey) ?? true,
      'messages': prefs.getBool(_messagesKey) ?? true,
      'friendRequests': prefs.getBool(_friendRequestsKey) ?? true,
      'calls': prefs.getBool(_callsKey) ?? true,
      'general': prefs.getBool(_generalKey) ?? true,
    };
  }

  static Future<void> setNotificationPreferences({
    required bool all,
    required bool messages,
    required bool friendRequests,
    required bool calls,
    required bool general,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_allNotificationsKey, all),
      prefs.setBool(_messagesKey, messages),
      prefs.setBool(_friendRequestsKey, friendRequests),
      prefs.setBool(_callsKey, calls),
      prefs.setBool(_generalKey, general),
    ]);
  }

  static Future<bool> isNotificationEnabled(String type) async {
    final preferences = await getNotificationPreferences();
    if (!preferences['all']!) return false;
    final key = preferenceKeys[type];
    if (key == null) return preferences['general']!;
    if (key == _messagesKey) return preferences['messages']!;
    if (key == _friendRequestsKey) return preferences['friendRequests']!;
    if (key == _callsKey) return preferences['calls']!;
    return preferences['general']!;
  }

  static Future<void> initialize({
    void Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (kIsWeb || _initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        try {
          final decoded = jsonDecode(response.payload!);
          if (decoded is Map<String, dynamic>) onNotificationTap?.call(decoded);
        } catch (error) {
          debugPrint('Invalid notification payload: $error');
        }
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel(
      id: messagesChannelId,
      name: 'Messages',
      description: 'New direct messages and chat activity.',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(_channel(
      id: friendRequestsChannelId,
      name: 'Friend Requests',
      description: 'Friend requests and friendship updates.',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(_channel(
      id: callsChannelId,
      name: 'Calls',
      description: 'Incoming and missed calls.',
      importance: Importance.max,
    ));
    await android?.createNotificationChannel(_channel(
      id: generalChannelId,
      name: 'System and General',
      description: 'Security, account, and other Synora updates.',
      importance: Importance.defaultImportance,
    ));

    _initialized = true;
  }

  static AndroidNotificationChannel _channel({
    required String id,
    required String name,
    required String description,
    required Importance importance,
  }) {
    return AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
      playSound: true,
      enableVibration: true,
    );
  }

  static Future<AuthorizationStatus?> requestPermission() async {
    if (kIsWeb) return null;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted == null
        ? null
        : granted
            ? AuthorizationStatus.authorized
            : AuthorizationStatus.denied;
  }

  static String channelIdFor(String type) {
    switch (type) {
      case 'message':
      case 'reply':
      case 'mention':
      case 'reaction':
        return messagesChannelId;
      case 'friend_request':
      case 'friend_accept':
        return friendRequestsChannelId;
      case 'call':
      case 'incoming_call':
        return callsChannelId;
      default:
        return generalChannelId;
    }
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    await initialize();

    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null || body == null || title.isEmpty || body.isEmpty) return;

    final type = message.data['type'] ?? message.data['notificationType'] ?? 'system';
    if (!await isNotificationEnabled(type.toString())) return;
    final notificationId = message.messageId?.hashCode ??
        '${type}_${message.data['actionId'] ?? DateTime.now().millisecondsSinceEpoch}'.hashCode;

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdFor(type),
          _channelNameFor(type),
          channelDescription: 'Synora $type notifications.',
          icon: 'ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          category: type == 'call' ? AndroidNotificationCategory.call : null,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static String _channelNameFor(String type) {
    switch (channelIdFor(type)) {
      case messagesChannelId:
        return 'Messages';
      case friendRequestsChannelId:
        return 'Friend Requests';
      case callsChannelId:
        return 'Calls';
      default:
        return 'System and General';
    }
  }
}
