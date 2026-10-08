import 'package:flutter/foundation.dart';

/// Supported notification categories within the Synora ecosystem.
enum SynoraNotificationType {
  friendRequest,
  friendAccept,
  message,
  story,
  mention,
  reply,
  reaction,
  system,
  achievement,
  spark,
  security,
  update,
  unknown,
}

/// Extension mapping notification types to their database representation strings.
extension SynoraNotificationTypeExtension on SynoraNotificationType {
  String get value {
    switch (this) {
      case SynoraNotificationType.friendRequest:
        return 'friend_request';
      case SynoraNotificationType.friendAccept:
        return 'friend_accept';
      case SynoraNotificationType.message:
        return 'message';
      case SynoraNotificationType.story:
        return 'story';
      case SynoraNotificationType.mention:
        return 'mention';
      case SynoraNotificationType.reply:
        return 'reply';
      case SynoraNotificationType.reaction:
        return 'reaction';
      case SynoraNotificationType.system:
        return 'system';
      case SynoraNotificationType.achievement:
        return 'achievement';
      case SynoraNotificationType.spark:
        return 'spark';
      case SynoraNotificationType.security:
        return 'security';
      case SynoraNotificationType.update:
        return 'update';
      case SynoraNotificationType.unknown:
        return 'unknown';
    }
  }

  static SynoraNotificationType fromString(String typeStr) {
    return SynoraNotificationType.values.firstWhere(
      (element) => element.value == typeStr,
      orElse: () => SynoraNotificationType.unknown,
    );
  }
}

/// Supported notification priorities.
enum SynoraNotificationPriority { low, normal, high }

/// Extension mapping priority types to their database strings.
extension SynoraNotificationPriorityExtension on SynoraNotificationPriority {
  String get value {
    switch (this) {
      case SynoraNotificationPriority.low:
        return 'low';
      case SynoraNotificationPriority.normal:
        return 'normal';
      case SynoraNotificationPriority.high:
        return 'high';
    }
  }

  static SynoraNotificationPriority fromString(String priorityStr) {
    return SynoraNotificationPriority.values.firstWhere(
      (element) => element.value == priorityStr,
      orElse: () => SynoraNotificationPriority.normal,
    );
  }
}

/// A highly immutable, production-ready enterprise data model representing a notification entity.
@immutable
class NotificationModel {
  final String id;
  final String receiverId;
  final String senderId;
  final String senderName;
  final String senderUsername;
  final String? senderPhoto;
  final String title;
  final String body;
  final SynoraNotificationType type;
  final String? actionId;
  final String? imageUrl;
  final bool isRead;
  final SynoraNotificationPriority priority;
  final bool isMuted;
  final DateTime? muteUntil;
  final bool isSilent;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? expiresAt;
  final DateTime? scheduledFor;
  final bool deletedForUser;

  const NotificationModel({
    required this.id,
    required this.receiverId,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    this.senderPhoto,
    required this.title,
    required this.body,
    required this.type,
    this.actionId,
    this.imageUrl,
    required this.isRead,
    required this.priority,
    required this.isMuted,
    this.muteUntil,
    required this.isSilent,
    required this.metadata,
    this.createdAt,
    this.deliveredAt,
    this.openedAt,
    this.expiresAt,
    this.scheduledFor,
    required this.deletedForUser,
  });

  // --- Helper Getters ---
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isScheduled =>
      scheduledFor != null && DateTime.now().isBefore(scheduledFor!);
  bool get isSystem =>
      type == SynoraNotificationType.system ||
      type == SynoraNotificationType.achievement ||
      type == SynoraNotificationType.security;
  bool get isMessage => type == SynoraNotificationType.message;
  bool get isFriendRequest => type == SynoraNotificationType.friendRequest;
  bool get isStory => type == SynoraNotificationType.story;
  bool get isSpark => type == SynoraNotificationType.spark;
  factory NotificationModel.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationModel.fromMap(data, doc.id);
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      receiverId: map['receiverId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderUsername: map['senderUsername'] ?? '',
      senderPhoto: map['senderPhoto'],
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: SynoraNotificationTypeExtension.fromString(
        map['type'] ?? 'unknown',
      ),
      actionId: map['actionId'],
      imageUrl: map['imageUrl'],
      isRead: map['isRead'] ?? false,
      priority: SynoraNotificationPriorityExtension.fromString(
        map['priority'] ?? 'normal',
      ),
      isMuted: map['isMuted'] ?? false,
      muteUntil: map['muteUntil']?.toDate(),
      isSilent: map['isSilent'] ?? false,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: map['createdAt']?.toDate(),
      deliveredAt: map['deliveredAt']?.toDate(),
      openedAt: map['openedAt']?.toDate(),
      expiresAt: map['expiresAt']?.toDate(),
      scheduledFor: map['scheduledFor']?.toDate(),
      deletedForUser: map['deletedForUser'] ?? false,
    );
  }

  NotificationModel copyWith({
    bool? isRead,
    DateTime? openedAt,
    bool? deletedForUser,
  }) {
    return NotificationModel(
      id: id,
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderPhoto: senderPhoto,
      title: title,
      body: body,
      type: type,
      actionId: actionId,
      imageUrl: imageUrl,
      isRead: isRead ?? this.isRead,
      priority: priority,
      isMuted: isMuted,
      muteUntil: muteUntil,
      isSilent: isSilent,
      metadata: metadata,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      expiresAt: expiresAt,
      scheduledFor: scheduledFor,
      deletedForUser: deletedForUser ?? this.deletedForUser,
    );
  }
}
