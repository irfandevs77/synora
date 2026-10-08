import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../repositories/chat_repositories.dart';

class ChatService {
  late final ChatRepository _repository = ChatRepository();

  Stream<List<ChatModel>> getChatRooms(String currentUserId) {
    return _repository.streamChatRooms(currentUserId);
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _repository.streamMessages(chatId);
  }

  void setActiveUser(String userId) => _repository.setActiveUser(userId);

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) => _repository.deleteMessageForMe(
        chatId: chatId,
        messageId: messageId,
        userId: userId,
      );

  Future<void> unsendMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String currentUserId,
  }) => _repository.unsendMessage(
        chatId: chatId,
        messageId: messageId,
        senderId: senderId,
        currentUserId: currentUserId,
      );

  Future<void> hideChatForUser({
    required String chatId,
    required String userId,
  }) => _repository.hideChatForUser(chatId: chatId, userId: userId);

  Future<void> sendMessage(
    String chatId,
    MessageModel message,
    ChatModel updatedChat,
  ) async {
    await _repository.saveMessage(chatId, message, updatedChat);
  }

  Future<void> markMessageAsSeen(String chatId, String messageId) async {
    await _repository.updateSeenStatus(chatId, messageId);
  }

  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _repository.streamUserProfile(userId);
  }

  Stream<QuerySnapshot> getAllUsersStream() {
    return _repository.searchUsers();
  }
}
