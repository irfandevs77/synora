import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:synora/models/chat_model.dart';
import 'package:synora/models/message_model.dart';

class ChatRepository {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ChatModel>> streamChatRooms(String currentUserId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs
              .where((doc) {
                final hiddenFor = List<String>.from(
                  doc.data()['hiddenForUsers'] ?? const [],
                );
                return !hiddenFor.contains(currentUserId);
              })
              .map((doc) => ChatModel.fromFirestore(doc))
              .toList();
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return chats;
        });
  }

  Stream<List<ChatModel>> streamHiddenChatRooms(String currentUserId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs
              .where((doc) {
                final hiddenFor = List<String>.from(
                  doc.data()['hiddenForUsers'] ?? const [],
                );
                return hiddenFor.contains(currentUserId);
              })
              .map((doc) => ChatModel.fromFirestore(doc))
              .toList();
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return chats;
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamGroups(
    String currentUserId, {
    bool hidden = false,
  }) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs.where((doc) {
            final hiddenFor = List<String>.from(
              doc.data()['hiddenForUsers'] ?? const [],
            );
            return hiddenFor.contains(currentUserId) == hidden;
          }).toList();
          groups.sort((a, b) {
            final aTime =
                (a.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                (b.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return groups;
        });
  }

  Stream<List<MessageModel>> streamMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                final hiddenFor = List<String>.from(
                  doc.data()['deletedForUsers'] ?? const [],
                );
                return !hiddenFor.contains(_activeUserId);
              })
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
        });
  }

  String _activeUserId = '';

  void setActiveUser(String userId) {
    _activeUserId = userId;
  }

  Future<void> saveMessage(
    String chatId,
    MessageModel message,
    ChatModel updatedChat,
  ) async {
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final messageDocRef = chatDocRef.collection('messages').doc();
    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatDocRef);
      final data = chatSnapshot.data() ?? <String, dynamic>{};
      final unreadCount = Map<String, dynamic>.from(
        (data['unreadCount'] as Map?) ?? const <String, dynamic>{},
      );
      final currentUnread =
          (unreadCount[message.receiverId] as num?)?.toInt() ?? 0;
      unreadCount[message.receiverId] = currentUnread + 1;
      unreadCount[message.senderId] ??= 0;

      final chatData = updatedChat.toFirestore();
      chatData['unreadCount'] = unreadCount;
      chatData['hiddenForUsers'] = List<String>.from(
        data['hiddenForUsers'] ?? updatedChat.hiddenForUsers,
      );
      transaction.set(messageDocRef, message.toFirestore());
      transaction.set(chatDocRef, chatData, SetOptions(merge: true));
    });
  }

  Future<void> updateSeenStatus(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isSeen': true});
  }

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final ref = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await ref.update({
      'deletedForUsers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unsendMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String currentUserId,
  }) async {
    if (senderId != currentUserId) return;
    final ref = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await ref.update({
      'isUnsent': true,
      'text': 'Message unsent',
      'type': 'text',
      'mediaUrl': FieldValue.delete(),
      'fileName': FieldValue.delete(),
    });
  }

  Future<void> hideChatForUser({
    required String chatId,
    required String userId,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'hiddenForUsers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unhideChatForUser({
    required String chatId,
    required String userId,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'hiddenForUsers': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> hideGroupForUser({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'hiddenForUsers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unhideGroupForUser({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'hiddenForUsers': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<DocumentSnapshot> streamUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Stream<QuerySnapshot> searchUsers() {
    return _firestore.collection('users').snapshots();
  }
}
