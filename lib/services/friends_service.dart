import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_service.dart';

class FriendServiceException implements Exception {
  final String message;
  final dynamic originalError;
  FriendServiceException(this.message, [this.originalError]);
  @override
  String toString() =>
      'FriendServiceException: $message ${originalError ?? ""}';
}

/// Synora app ki core dynamic data management logic target structure ke liye.
class FriendsService {
  final FirebaseFirestore _firestore;

  static const String _collectionFriends =
      'freinds'; // Strict legacy key mapping
  static const String _collectionUsers = 'users';
  static const String _fieldAdderId = 'adderId';
  static const String _fieldAddedId = 'addedId';
  static const String _fieldCreatedAt = 'createdAt';
  static const String _fieldFriendsCount = 'friendsCount';

  FriendsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static String getDeterministicDocId(String uidA, String uidB) {
    return uidA.compareTo(uidB) < 0 ? '${uidA}_$uidB' : '${uidB}_$uidA';
  }

  DocumentReference<Map<String, dynamic>> _friendRef(String uidA, String uidB) {
    return _firestore
        .collection(_collectionFriends)
        .doc(FriendsService.getDeterministicDocId(uidA, uidB));
  }

  Future<String> getStatus({
    required String currentUserId,
    required String profileUserId,
  }) async {
    if (currentUserId == profileUserId) return 'self';
    final snapshot = await _friendRef(currentUserId, profileUserId).get();
    if (!snapshot.exists) return 'none';
    final data = snapshot.data() ?? const <String, dynamic>{};
    if (data['status'] == 'accepted') return 'accepted';
    if (data['status'] == 'requested') {
      return data[_fieldAdderId] == currentUserId
          ? 'requested_by_me'
          : 'requested_by_them';
    }
    return 'none';
  }

  Stream<String> watchFriendStatus({
    required String currentUserId,
    required String profileUserId,
  }) {
    if (currentUserId == profileUserId) {
      return Stream<String>.value('self');
    }
    return _friendRef(currentUserId, profileUserId).snapshots().map((snapshot) {
      if (!snapshot.exists) return 'none';
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] == 'accepted') return 'accepted';
      if (data['status'] == 'requested') {
        return data[_fieldAdderId] == currentUserId
            ? 'requested_by_me'
            : 'requested_by_them';
      }
      return 'none';
    });
  }

  Future<void> sendFriendRequest({
    required String currentUserId,
    required String profileUserId,
  }) async {
    if (currentUserId == profileUserId) {
      throw FriendServiceException('You cannot send a request to yourself.');
    }
    final friendRef = _friendRef(currentUserId, profileUserId);
    if ((await friendRef.get()).exists) {
      throw FriendServiceException('A friendship or request already exists.');
    }

    final senderSnapshot = await _firestore
        .collection(_collectionUsers)
        .doc(currentUserId)
        .get();
    final sender = senderSnapshot.data() ?? const <String, dynamic>{};
    final notificationRef = _firestore.collection('notifications').doc();
    final requestId = FriendsService.getDeterministicDocId(
      currentUserId,
      profileUserId,
    );
    final batch = _firestore.batch();
    batch.set(friendRef, {
      _fieldAdderId: currentUserId,
      _fieldAddedId: profileUserId,
      'status': 'requested',
      _fieldCreatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(notificationRef, {
      'receiverId': profileUserId,
      'senderId': currentUserId,
      'senderName': sender['name'] ?? '',
      'senderUsername': sender['username'] ?? '',
      'senderPhoto': sender['profileImage'],
      'title': 'Friend Request',
      'body':
          '${sender['name'] ?? sender['username'] ?? 'Someone'} sent you a friend request.',
      'type': 'friend_request',
      'actionId': requestId,
      'imageUrl': null,
      'isRead': false,
      'priority': 'normal',
      'isMuted': false,
      'isSilent': false,
      'metadata': <String, dynamic>{'requestId': requestId},
      'createdAt': FieldValue.serverTimestamp(),
      'deletedForUser': false,
    });
    try {
      await batch.commit();

      // Send push notification to receiver
      try {
        final notificationService = NotificationService();
        final senderName = sender['username'] ?? sender['name'] ?? 'User';
        await notificationService.sendFriendRequestPushNotification(
          receiverId: profileUserId,
          senderName: senderName,
          senderId: currentUserId,
        );
      } catch (e) {
        developer.log(
          'Error sending friend request push notification: $e',
          name: 'Synora.FriendsService',
        );
      }
    } catch (e) {
      throw FriendServiceException('Failed to send friend request.', e);
    }
  }

  Future<void> cancelFriendRequest({
    required String currentUserId,
    required String profileUserId,
  }) async {
    final friendRef = _friendRef(currentUserId, profileUserId);
    final snapshot = await friendRef.get();
    final data = snapshot.data();
    if (!snapshot.exists ||
        data?['status'] != 'requested' ||
        data?[_fieldAdderId] != currentUserId) {
      return;
    }
    await friendRef.delete();
  }

  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String senderId,
  }) async {
    if (currentUserId == senderId) {
      throw FriendServiceException('Invalid friend request.');
    }
    final friendRef = _friendRef(currentUserId, senderId);
    final currentUserRef = _firestore
        .collection(_collectionUsers)
        .doc(currentUserId);
    final senderRef = _firestore.collection(_collectionUsers).doc(senderId);
    try {
      await _firestore.runTransaction((transaction) async {
        final friendSnapshot = await transaction.get(friendRef);
        if (!friendSnapshot.exists) {
          throw FriendServiceException(
            'This friend request is no longer pending.',
          );
        }
        final data = friendSnapshot.data() ?? const <String, dynamic>{};
        if (data['status'] == 'accepted') {
          return;
        }
        if (data['status'] != 'requested' ||
            data[_fieldAdderId] != senderId ||
            data[_fieldAddedId] != currentUserId) {
          throw FriendServiceException('This friend request is invalid.');
        }
        transaction.update(friendRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(currentUserRef, {
          _fieldFriendsCount: FieldValue.increment(1),
        });
        transaction.update(senderRef, {
          _fieldFriendsCount: FieldValue.increment(1),
        });
      });
    } catch (e) {
      if (e is FriendServiceException) rethrow;
      throw FriendServiceException('Failed to accept friend request.', e);
    }
  }

  Future<void> rejectFriendRequest({
    required String currentUserId,
    required String senderId,
  }) async {
    final friendRef = _friendRef(currentUserId, senderId);
    final snapshot = await friendRef.get();
    final data = snapshot.data();
    if (!snapshot.exists) return;
    if (data?['status'] != 'requested' ||
        data?[_fieldAdderId] != senderId ||
        data?[_fieldAddedId] != currentUserId) {
      throw FriendServiceException('This friend request is invalid.');
    }
    await friendRef.delete();
  }

  Stream<bool> watchFriendshipStatus(String friendDocId) {
    return _firestore
        .collection(_collectionFriends)
        .doc(friendDocId)
        .snapshots()
        .map((snapshot) => snapshot.exists)
        .distinct()
        .handleError((e) {
          developer.log(
            'Stream sync anomaly',
            error: e,
            name: 'Synora.FriendsService',
          );
        });
  }

  Future<bool> fetchFriendshipExists(String friendDocId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_collectionFriends)
          .doc(friendDocId)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      throw FriendServiceException('Failed to look up validation path.', e);
    }
  }

  Future<void> executeAddFriendBatch({
    required String currentUserId,
    required String profileUserId,
    required String friendDocId,
  }) async {
    if (currentUserId == profileUserId) {
      throw FriendServiceException('Self-Friend protection constraint active.');
    }
    if (await fetchFriendshipExists(friendDocId)) return;

    final friendDocRef = _firestore
        .collection(_collectionFriends)
        .doc(friendDocId);
    final profileUserRef = _firestore
        .collection(_collectionUsers)
        .doc(profileUserId);

    final batch = _firestore.batch();
    batch.set(friendDocRef, {
      _fieldAdderId: currentUserId,
      _fieldAddedId: profileUserId,
      _fieldCreatedAt: FieldValue.serverTimestamp(),
    });
    batch.update(profileUserRef, {_fieldFriendsCount: FieldValue.increment(1)});

    try {
      await batch.commit();
    } catch (e) {
      throw FriendServiceException('Batch persistence breakdown.', e);
    }
  }

  Future<void> executeRemoveFriendBatch({
    required String currentUserId,
    required String profileUserId,
    required String friendDocId,
  }) async {
    if (currentUserId == profileUserId) {
      throw FriendServiceException('Self-Friend protection constraint active.');
    }

    final friendDocRef = _firestore
        .collection(_collectionFriends)
        .doc(friendDocId);
    try {
      await _firestore.runTransaction((transaction) async {
        final friendSnapshot = await transaction.get(friendDocRef);
        if (!friendSnapshot.exists) return;

        final profileUserRef = _firestore
            .collection(_collectionUsers)
            .doc(profileUserId);
        final currentUserRef = _firestore
            .collection(_collectionUsers)
            .doc(currentUserId);
        final profileSnapshot = await transaction.get(profileUserRef);
        final currentSnapshot = await transaction.get(currentUserRef);
        final profileCount =
            ((profileSnapshot.data()?[_fieldFriendsCount]) as num?)?.toInt() ??
            0;
        final currentCount =
            ((currentSnapshot.data()?[_fieldFriendsCount]) as num?)?.toInt() ??
            0;

        transaction.delete(friendDocRef);
        transaction.update(profileUserRef, {
          _fieldFriendsCount: profileCount > 0 ? profileCount - 1 : 0,
        });
        transaction.update(currentUserRef, {
          _fieldFriendsCount: currentCount > 0 ? currentCount - 1 : 0,
        });
      });
    } catch (e) {
      throw FriendServiceException('Batch atomic tear-down error.', e);
    }
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getAcceptedFriends(
    String currentUserId,
  ) async {
    final friendIds = await getAcceptedFriendIds(currentUserId);
    if (friendIds.isEmpty) return [];

    final userSnapshots = await Future.wait(
      friendIds.map(
        (id) => _firestore.collection(_collectionUsers).doc(id).get(),
      ),
    );
    return userSnapshots.where((snapshot) => snapshot.exists).toList();
  }

  Future<Set<String>> getAcceptedFriendIds(String currentUserId) async {
    final results = await Future.wait([
      _firestore
          .collection(_collectionFriends)
          .where(_fieldAdderId, isEqualTo: currentUserId)
          .get(),
      _firestore
          .collection(_collectionFriends)
          .where(_fieldAddedId, isEqualTo: currentUserId)
          .get(),
    ]);

    final friendIds = <String>{};
    for (final snapshot in results) {
      for (final friendship in snapshot.docs) {
        final data = friendship.data();
        if (data['status'] != 'accepted') continue;
        final friendId = data[_fieldAdderId] == currentUserId
            ? data[_fieldAddedId]
            : data[_fieldAdderId];
        if (friendId is String && friendId.isNotEmpty) friendIds.add(friendId);
      }
    }
    return friendIds;
  }

  Future<int> getAcceptedFriendCount(String userId) async {
    final results = await Future.wait([
      _firestore
          .collection(_collectionFriends)
          .where(_fieldAdderId, isEqualTo: userId)
          .get(),
      _firestore
          .collection(_collectionFriends)
          .where(_fieldAddedId, isEqualTo: userId)
          .get(),
    ]);
    return results
        .expand((snapshot) => snapshot.docs)
        .where((friendship) => friendship.data()['status'] == 'accepted')
        .length;
  }

  Future<void> removeFriend({
    required String currentUserId,
    required String profileUserId,
  }) async {
    await executeRemoveFriendBatch(
      currentUserId: currentUserId,
      profileUserId: profileUserId,
      friendDocId: FriendsService.getDeterministicDocId(
        currentUserId,
        profileUserId,
      ),
    );
  }

  Future<void> blockUser({
    required String currentUserId,
    required String profileUserId,
  }) async {
    await _firestore
        .collection('blockedUsers')
        .doc('${currentUserId}_$profileUserId')
        .set({
          'blockerId': currentUserId,
          'blockedUserId': profileUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
