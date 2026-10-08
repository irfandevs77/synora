import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../models/notification_model.dart';
import '../services/notifications_service.dart';
import '../services/friends_service.dart';

/// A production-ready, enterprise-grade GetX controller for Managing Synora notifications.
class NotificationController extends GetxController {
  NotificationService _notificationService = NotificationService();
  final FriendsService _friendsService = FriendsService();

  static const int _documentLimit = 20;
  static const int _maxRetryAttempts = 3;

  // --- Reactive States ---
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isFetchingMore = false.obs;

  final RxBool hasMoreData = true.obs;
  bool get hasMore => hasMoreData.value;
  set hasMore(bool value) => hasMoreData.value = value;

  final RxnString errorMessage = RxnString();

  // Loader protection specifically mapping for individual notification action states
  final RxString isLoadingActionId = ''.obs;

  // --- Streams & Component Lifecycles ---
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  DocumentSnapshot? _lastDocument;
  String? _currentUserId;

  int _notificationRetryCount = 0;
  int _unreadRetryCount = 0;

  void initNotificationEngine(String userId) {
    if (userId.isEmpty) return;
    if (_currentUserId == userId) return;

    _currentUserId = userId;
    _notificationService = NotificationService(userId: userId);
    refreshNotifications();
  }

  Future<void> refreshNotifications() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = null;
    hasMoreData.value = true;
    _lastDocument = null;
    _notificationRetryCount = 0;
    _unreadRetryCount = 0;

    try {
      _initUnreadCounterListener();
      _initNotificationsStreamListener();
    } catch (e) {
      _handleException(
        'Failed to complete initialization of notifications.',
        e,
      );
      isLoading.value = false;
    }
  }

  void _initNotificationsStreamListener() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _notificationService
        .streamNotifications(limit: _documentLimit)
        .listen(
          (snapshot) {
            _notificationRetryCount = 0;
            if (snapshot.docs.isNotEmpty) {
              _lastDocument = snapshot.docs.last;
              notifications.value = snapshot.docs
                  .map((doc) => _notificationFromSnapshot(doc))
                  .toList();
              hasMoreData.value = snapshot.docs.length == _documentLimit;
            } else {
              notifications.clear();
              hasMoreData.value = false;
            }
            isLoading.value = false;
          },
          onError: (err) async {
            debugPrint(
              '[NotificationController] Notifications Stream Error: $err',
            );
            if (_notificationRetryCount < _maxRetryAttempts) {
              _notificationRetryCount++;
              await Future.delayed(
                Duration(seconds: _notificationRetryCount * 2),
              );
              _initNotificationsStreamListener();
            } else {
              _handleException('Notification system feed sync failure.', err);
              isLoading.value = false;
            }
          },
        );
  }

  void _initUnreadCounterListener() {
    _unreadCountSubscription?.cancel();
    _unreadCountSubscription = _notificationService.streamUnreadCount().listen(
      (unreadTotal) {
        _unreadRetryCount = 0;
        unreadCount.value = unreadTotal;
      },
      onError: (err) async {
        debugPrint('[NotificationController] Unread Count Stream Error: $err');
        if (_unreadRetryCount < _maxRetryAttempts) {
          _unreadRetryCount++;
          await Future.delayed(Duration(seconds: _unreadRetryCount * 2));
          _initUnreadCounterListener();
        } else {
          debugPrint(
            '[NotificationController] Unread Counter Stream Terminated permanently.',
          );
        }
      },
    );
  }

  Future<void> loadMoreNotifications() async {
    if (isFetchingMore.value ||
        !hasMoreData.value ||
        _currentUserId == null ||
        _lastDocument == null) {
      return;
    }

    isFetchingMore.value = true;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('deletedForUser', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_documentLimit)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        final newItems = querySnapshot.docs
            .map((doc) => _notificationFromSnapshot(doc))
            .toList();

        for (var item in newItems) {
          if (!notifications.any((element) => element.id == item.id)) {
            notifications.add(item);
          }
        }
        hasMoreData.value = querySnapshot.docs.length == _documentLimit;
      } else {
        hasMoreData.value = false;
      }
    } catch (e) {
      _handleException(
        'Failed to load older notifications historical records.',
        e,
      );
    } finally {
      isFetchingMore.value = false;
    }
  }

  // ==========================================
  // FRIEND REQUEST TRANSACTION ENGINE (UPDATED)
  // ==========================================

  /// Accepts a pending friend request, updates core 'freinds' root collection map to 'accepted',
  /// increments parent user counts concurrently, and purges tracking notification logs.
  Future<void> acceptFriendRequest({
    required String notificationId,
    required String senderId, // User 1
  }) async {
    if (_currentUserId == null || isLoadingActionId.value.isNotEmpty) return;
    isLoadingActionId(notificationId);

    try {
      await _friendsService.acceptFriendRequest(
        currentUserId: _currentUserId!,
        senderId: senderId,
      );

      final currentUserSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      final currentUser = currentUserSnapshot.data() ?? const <String, dynamic>{};
      await _notificationService.sendFriendAcceptedNotification(
        receiverId: senderId,
        senderId: _currentUserId!,
        senderName: currentUser['name'] ?? '',
        senderUsername: currentUser['username'] ?? '',
        senderPhoto: currentUser['profileImage'] as String?,
        metadata: {
          'requestId': FriendsService.getDeterministicDocId(
            _currentUserId!,
            senderId,
          ),
        },
      );

      await deleteNotification(notificationId);

      Get.snackbar(
        'Success',
        'Friend request accepted!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _handleException(
        'Failed to complete friend request acceptance transaction.',
        e,
      );
    } finally {
      isLoadingActionId('');
    }
  }

  /// Rejects/Declines a friend request, completely deletes root 'freinds' doc mapping,
  /// resetting target client view structures back to 'Add Friend' states automatically.
  Future<void> rejectFriendRequest({
    required String notificationId,
    required String senderId,
  }) async {
    if (_currentUserId == null || isLoadingActionId.value.isNotEmpty) return;
    isLoadingActionId(notificationId);

    try {
      await _friendsService.rejectFriendRequest(
        currentUserId: _currentUserId!,
        senderId: senderId,
      );

      await deleteNotification(notificationId);

      Get.snackbar(
        'Declined',
        'Friend request declined.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _handleException('Failed to clear pending friend request map.', e);
    } finally {
      isLoadingActionId('');
    }
  }

  // --- Mutation Processing Engines ---

  Future<void> markAsRead(String id) async {
    try {
      await _notificationService.markAsRead(id);
      final index = notifications.indexWhere((element) => element.id == id);
      if (index != -1) {
        final wasUnread = !notifications[index].isRead;
        notifications[index] = notifications[index].copyWith(isRead: true);
        if (wasUnread && unreadCount.value > 0) {
          unreadCount.value--;
        }
      }
    } catch (e) {
      _handleException('Failed to mark transaction item state as read.', e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final localUnreadCount = notifications.where((n) => !n.isRead).length;
      if (localUnreadCount == 0 && unreadCount.value == 0) return;

      await _notificationService.markAllAsRead();

      notifications.value = notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      unreadCount.value = 0;
    } catch (e) {
      _handleException(
        'Failed to transition batch nodes into read collection maps.',
        e,
      );
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _notificationService.deleteNotification(id);
      notifications.removeWhere((element) => element.id == id);
    } catch (e) {
      _handleException('Failed to execute item verification removal state.', e);
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _notificationService.clearAllNotifications();
      notifications.clear();
      unreadCount.value = 0;
    } catch (e) {
      _handleException(
        'Failed to execute complete cloud notification cache clear updates.',
        e,
      );
    }
  }

  void _handleException(String clientMessage, dynamic error) {
    if (error is NotificationServiceException) {
      errorMessage.value = error.message;
      debugPrint(
        '[NotificationController ServiceException]: ${error.toString()}',
      );
    } else {
      errorMessage.value = clientMessage;
      debugPrint('[NotificationController GenericException]: $error');
    }
  }

  @override
  void onClose() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.onClose();
  }
}

NotificationModel _notificationFromSnapshot(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  return NotificationModel.fromMap(doc.data(), doc.id);
}
