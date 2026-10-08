import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Exceptions specific to the Synora Notification Service.
class NotificationServiceException implements Exception {
  final String message;
  final dynamic details;

  const NotificationServiceException(this.message, [this.details]);

  @override
  String toString() =>
      'NotificationServiceException: $message (${details ?? ""})';
}

/// A production-ready Notification Service for Synora using Clean Architecture principles.
/// Optimized for high scalability, strong typing, and zero code duplication.
class NotificationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String? _configuredUserId;

  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? userId,
  })
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _configuredUserId = userId;

  // --- Collection Constants ---
  static const String _collectionNotifications = 'notifications';

  // --- Fields Constants ---
  static const String _fieldReceiverId = 'receiverId';
  static const String _fieldSenderId = 'senderId';
  static const String _fieldSenderName = 'senderName';
  static const String _fieldSenderUsername = 'senderUsername';
  static const String _fieldSenderPhoto = 'senderPhoto';
  static const String _fieldTitle = 'title';
  static const String _fieldBody = 'body';
  static const String _fieldType = 'type';
  static const String _fieldActionId = 'actionId';
  static const String _fieldImageUrl = 'imageUrl';
  static const String _fieldIsRead = 'isRead';
  static const String _fieldPriority = 'priority';
  static const String _fieldCreatedAt = 'createdAt';
  static const String _fieldExpiresAt = 'expiresAt';
  static const String _fieldDeletedForUser = 'deletedForUser';
  static const String _fieldMetadata = 'metadata';

  // --- Notification Types Constants ---
  static const String typeMessage = 'message';
  static const String typeFriendRequest = 'friend_request';
  static const String typeFriendAccept = 'friend_accept';
  static const String typeStory = 'story';
  static const String typeMention = 'mention';
  static const String typeReply = 'reply';
  static const String typeReaction = 'reaction';
  static const String typeSystem = 'system';
  static const String typeAchievement = 'achievement';
  static const String typeSpark = 'spark';
  static const String typeSecurity = 'security';
  static const String typeUpdate = 'update';

  // --- Priority Constants ---
  static const String priorityLow = 'low';
  static const String priorityNormal = 'normal';
  static const String priorityHigh = 'high';

  // --- Current User Helper ---
  String get _currentUserId {
    final uid = _configuredUserId ?? _auth.currentUser?.uid;
    if (uid == null) {
      throw const NotificationServiceException(
        'User must be authenticated to perform this operation.',
      );
    }
    return uid;
  }

  // --- Base Send Notification Method ---
  Future<void> _createNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String title,
    required String body,
    required String type,
    required String? actionId,
    required String? imageUrl,
    required String priority,
    required DateTime? expiresAt,
    required Map<String, dynamic> metadata,
  }) async {
    if (receiverId == senderId) {
      return;
    }

    try {
      final docRef = _firestore.collection(_collectionNotifications).doc();
      final data = {
        _fieldReceiverId: receiverId,
        _fieldSenderId: senderId,
        _fieldSenderName: senderName,
        _fieldSenderUsername: senderUsername,
        _fieldSenderPhoto: senderPhoto,
        _fieldTitle: title,
        _fieldBody: body,
        _fieldType: type,
        _fieldActionId: actionId,
        _fieldImageUrl: imageUrl,
        _fieldIsRead: false,
        _fieldPriority: priority,
        _fieldCreatedAt: FieldValue.serverTimestamp(),
        _fieldExpiresAt: expiresAt != null
            ? Timestamp.fromDate(expiresAt)
            : null,
        _fieldDeletedForUser: false,
        _fieldMetadata: metadata,
      };

      await docRef.set(data);
    } catch (e) {
      throw NotificationServiceException(
        'Failed to create notification of type $type',
        e,
      );
    }
  }

  // --- Public Send Notification Methods ---

  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String body,
    required String roomId,
    String? imageUrl,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: senderName,
      body: body,
      type: typeMessage,
      actionId: roomId,
      imageUrl: imageUrl,
      priority: priorityHigh,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendFriendRequestNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'Friend Request',
      body: '$senderName sent you a friend request.',
      type: typeFriendRequest,
      actionId: senderId,
      imageUrl: null,
      priority: priorityNormal,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendFriendAcceptedNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'Friend Request Accepted',
      body: '$senderName accepted your friend request.',
      type: typeFriendAccept,
      actionId: senderId,
      imageUrl: null,
      priority: priorityNormal,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendStoryNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String storyId,
    String? imageUrl,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'New Story',
      body: '$senderName posted a new story.',
      type: typeStory,
      actionId: storyId,
      imageUrl: imageUrl,
      priority: priorityLow,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      metadata: metadata,
    );
  }

  Future<void> sendSparkNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String sparkId,
    required String body,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'New Spark',
      body: body,
      type: typeSpark,
      actionId: sparkId,
      imageUrl: null,
      priority: priorityNormal,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendAchievementNotification({
    required String receiverId,
    required String achievementId,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: 'synora_system',
      senderName: 'Synora',
      senderUsername: 'synora',
      senderPhoto: null,
      title: title,
      body: body,
      type: typeAchievement,
      actionId: achievementId,
      imageUrl: imageUrl,
      priority: priorityNormal,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendSystemNotification({
    required String receiverId,
    required String title,
    required String body,
    String? actionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: 'synora_system',
      senderName: 'Synora',
      senderUsername: 'synora',
      senderPhoto: null,
      title: title,
      body: body,
      type: typeSystem,
      actionId: actionId,
      imageUrl: null,
      priority: priorityNormal,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendReactionNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String postId,
    required String reactionType,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'New Reaction',
      body: '$senderName reacted $reactionType to your post.',
      type: typeReaction,
      actionId: postId,
      imageUrl: null,
      priority: priorityLow,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendMentionNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String postId,
    required String contextSnippet,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'Mentioned You',
      body: '$senderName mentioned you: "$contextSnippet"',
      type: typeMention,
      actionId: postId,
      imageUrl: null,
      priority: priorityHigh,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendReplyNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String? senderPhoto,
    required String postId,
    required String replyBody,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: 'New Reply',
      body: '$senderName replied: "$replyBody"',
      type: typeReply,
      actionId: postId,
      imageUrl: null,
      priority: priorityHigh,
      expiresAt: null,
      metadata: metadata,
    );
  }

  Future<void> sendSecurityNotification({
    required String receiverId,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _createNotification(
      receiverId: receiverId,
      senderId: 'synora_security',
      senderName: 'Synora Security',
      senderUsername: 'security',
      senderPhoto: null,
      title: title,
      body: body,
      type: typeSecurity,
      actionId: null,
      imageUrl: null,
      priority: priorityHigh,
      expiresAt: null,
      metadata: metadata,
    );
  }

  // --- Write Operations (Modifications & Deletions) ---

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_collectionNotifications)
          .doc(notificationId)
          .update({_fieldIsRead: true});
    } catch (e) {
      throw NotificationServiceException(
        'Failed to mark notification $notificationId as read',
        e,
      );
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    try {
      final snapshot = await _firestore
          .collection(_collectionNotifications)
          .where(_fieldReceiverId, isEqualTo: userId)
          .where(_fieldIsRead, isEqualTo: false)
          .where(_fieldDeletedForUser, isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {_fieldIsRead: true});
      }
      await batch.commit();
    } catch (e) {
      throw NotificationServiceException(
        'Failed to mark all notifications as read for user $userId',
        e,
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(_collectionNotifications)
          .doc(notificationId)
          .update({_fieldDeletedForUser: true});
    } catch (e) {
      throw NotificationServiceException(
        'Failed to delete notification $notificationId',
        e,
      );
    }
  }

  Future<void> clearAllNotifications() async {
    final userId = _currentUserId;
    try {
      final snapshot = await _firestore
          .collection(_collectionNotifications)
          .where(_fieldReceiverId, isEqualTo: userId)
          .where(_fieldDeletedForUser, isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {_fieldDeletedForUser: true});
      }
      await batch.commit();
    } catch (e) {
      throw NotificationServiceException(
        'Failed to clear notifications for user $userId',
        e,
      );
    }
  }

  // --- Read Operations (Streams & Counts) ---

  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    try {
      final snapshot = await _firestore
          .collection(_collectionNotifications)
          .where(_fieldReceiverId, isEqualTo: userId)
          .where(_fieldIsRead, isEqualTo: false)
          .where(_fieldDeletedForUser, isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw NotificationServiceException(
        'Failed to fetch unread notifications count for user $userId',
        e,
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotifications({
    int limit = 50,
  }) {
    final userId = _currentUserId;
    try {
      return _firestore
          .collection(_collectionNotifications)
          .where(_fieldReceiverId, isEqualTo: userId)
          .where(_fieldDeletedForUser, isEqualTo: false)
          .orderBy(_fieldCreatedAt, descending: true)
          .limit(limit)
          .snapshots();
    } catch (e) {
      throw NotificationServiceException(
        'Failed to establish notification stream for user $userId',
        e,
      );
    }
  }

  Stream<int> streamUnreadCount() {
    final userId = _currentUserId;
    try {
      return _firestore
          .collection(_collectionNotifications)
          .where(_fieldReceiverId, isEqualTo: userId)
          .where(_fieldIsRead, isEqualTo: false)
          .where(_fieldDeletedForUser, isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      throw NotificationServiceException(
        'Failed to establish unread count stream for user $userId',
        e,
      );
    }
  }

  // --- FCM Push Notification Sending ---
  /// Sends an FCM push notification to a user
  /// This requires Cloud Functions to handle the actual FCM sending
  Future<void> sendPushNotification({
    required String receiverId,
    required String title,
    required String body,
    required String notificationType,
    String? actionId,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      // Get receiver's FCM token
      final receiverDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();

      if (!receiverDoc.exists) {
        throw NotificationServiceException(
          'Receiver user not found: $receiverId',
        );
      }

      final fcmToken = receiverDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        // User hasn't set up FCM yet, just store in-app notification
        debugPrint('FCM token not available for user $receiverId');
        return;
      }

      // Store push notification request for Cloud Function to process
      final notificationRequest = {
        'targetUserId': receiverId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'notificationType': notificationType,
        'actionId': actionId,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Cloud Function will mark as 'sent'
      };

      await _firestore
          .collection('notification_queue')
          .doc()
          .set(notificationRequest);

      debugPrint('Push notification queued for $receiverId');
    } catch (e) {
      debugPrint('Error queuing push notification: $e');
      // Don't throw, just log - notifications are best effort
    }
  }

  /// Send push notification for message
  Future<void> sendMessagePushNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String messagePreview,
    required String chatId,
  }) async {
    await sendPushNotification(
      receiverId: receiverId,
      title: senderName,
      body: messagePreview,
      notificationType: typeMessage,
      actionId: chatId,
      data: {
        'chatId': chatId,
        'senderId': senderId,
        'type': 'message',
      },
    );
  }

  /// Send push notification for friend request
  Future<void> sendFriendRequestPushNotification({
    required String receiverId,
    required String senderName,
    required String senderId,
  }) async {
    await sendPushNotification(
      receiverId: receiverId,
      title: 'Friend Request',
      body: '$senderName sent you a friend request.',
      notificationType: typeFriendRequest,
      actionId: senderId,
      data: {
        'senderId': senderId,
        'type': 'friend_request',
      },
    );
  }
}
