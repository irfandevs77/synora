import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synora/models/chat_model.dart';
import 'package:synora/models/message_model.dart';
import '../services/chat_services.dart';
import '../services/media_permissions_service.dart';
import '../services/notifications_service.dart';

class ChatController extends GetxController {
  final ChatService _chatService = ChatService();

  final chatRooms = <ChatModel>[].obs;
  final messages = <MessageModel>[].obs;
  final searchResults = <QueryDocumentSnapshot>[].obs;
  final searchController = TextEditingController();
  final isLoading = false.obs;
  final currentUsername = ''.obs;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  AudioRecorder? _audioRecorder;
  final isRecording = false.obs;

  AudioRecorder get _recorder => _audioRecorder ??= AudioRecorder();

  @override
  void onInit() {
    super.onInit();
    _fetchCurrentUsername();
  }

  // Current logged in user ka profile username list header ke liye fetch karna
  Future<void> _fetchCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid =
        prefs.getString('userDocId') ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isNotEmpty) {
      _chatService.getUserProfileStream(currentUid).listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          currentUsername.value = data?['username'] ?? '';
        }
      });
    }
  }

  void listenToChatRooms(String currentUserId) {
    debugPrint('listenToChatRooms called with userId: $currentUserId');
    chatRooms.bindStream(_chatService.getChatRooms(currentUserId));
  }

  void listenToMessages(String chatId) {
    debugPrint('listenToMessages called with chatId: $chatId, userId: $_currentUserForMessages');
    _chatService.setActiveUser(_currentUserForMessages);
    messages.bindStream(_chatService.getMessages(chatId));
  }

  String _currentUserForMessages = '';

  void setCurrentUser(String userId) {
    _currentUserForMessages = userId;
    _chatService.setActiveUser(userId);
  }

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) => _chatService.deleteMessageForMe(
        chatId: chatId,
        messageId: messageId,
        userId: userId,
      );

  Future<void> unsendMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String currentUserId,
  }) => _chatService.unsendMessage(
        chatId: chatId,
        messageId: messageId,
        senderId: senderId,
        currentUserId: currentUserId,
      );

  Future<void> deleteChatForMe({
    required String chatId,
    required String userId,
  }) => _chatService.hideChatForUser(chatId: chatId, userId: userId);

  // Core Functionality: Chat room exist karta hai ya nahi check karna aur auto-create karna
  Future<String> getOrCreateChatRoom(
    String currentUserId,
    String targetUserId,
  ) async {
    isLoading.value = true;
    debugPrint('getOrCreateChatRoom() called');

    List<String> ids = [currentUserId, targetUserId];
    ids.sort();
    String combinedChatId = ids.join('_');

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(combinedChatId)
          .get();

      if (!docSnapshot.exists) {
        final newRoom = ChatModel(
          id: combinedChatId,
          participants: [currentUserId, targetUserId],
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCount: {currentUserId: 0, targetUserId: 0},
          lastMessageSenderId: '',
        );

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(combinedChatId)
            .set(newRoom.toFirestore());
      }
      return combinedChatId;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
  }) async {
    final body = textController.text.trim();
    if (body.isEmpty) return;

    textController.clear();

    final newMessage = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: body,
      type: 'text',
      timestamp: DateTime.now(),
      isSeen: false,
    );

    // Fetch existing room context safely map changes adjust karne ke liye
    int currentTargetUnread = 0;
    String senderName = '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final unreadMap = data?['unreadCount'] as Map<String, dynamic>?;
        currentTargetUnread = unreadMap?[receiverId] ?? 0;
      }

      // Get sender's name for notification
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      if (senderDoc.exists) {
        senderName = senderDoc.data()?['username'] ?? senderDoc.data()?['name'] ?? 'User';
      }
    } catch (_) {}

    final updatedChat = ChatModel(
      id: chatId,
      participants: [senderId, receiverId],
      lastMessage: body,
      lastMessageSenderId: senderId,
      lastMessageTime: DateTime.now(),
      unreadCount: {
        senderId: 0, // Sender ka count clean rahega
        receiverId:
            currentTargetUnread + 1, // Receiver ka counter increment hoga
      },
    );

    await _chatService.sendMessage(chatId, newMessage, updatedChat);
    
    // Send push notification to receiver
    try {
      final notificationService = NotificationService();
      await notificationService.sendMessagePushNotification(
        receiverId: receiverId,
        senderId: senderId,
        senderName: senderName.isNotEmpty ? senderName : 'User',
        messagePreview: body.length > 50 ? '${body.substring(0, 50)}...' : body,
        chatId: chatId,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
    
    animateToBottom();
  }

  String attachmentLabelForType(String type) {
    if (type.contains('image')) return 'sent a photo';
    if (type.contains('video')) return 'sent a video';
    if (type.contains('audio')) return 'sent an audio message';
    return 'sent a file';
  }

  Future<void> sendAttachmentMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String type,
    required String url,
    String? filename,
  }) async {
    final newMessage = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: 'Sent an attachment',
      type: type,
      mediaUrl: url,
      fileName: filename,
      timestamp: DateTime.now(),
      isSeen: false,
    );

    int currentTargetUnread = 0;
    String senderName = '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final unreadMap = data?['unreadCount'] as Map<String, dynamic>?;
        currentTargetUnread = unreadMap?[receiverId] ?? 0;
      }

      // Get sender's name for notification
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      if (senderDoc.exists) {
        senderName = senderDoc.data()?['username'] ?? senderDoc.data()?['name'] ?? 'User';
      }
    } catch (_) {}

    final updatedChat = ChatModel(
      id: chatId,
      participants: [senderId, receiverId],
      lastMessage: 'Attachment ($type)',
      lastMessageSenderId: senderId,
      lastMessageTime: DateTime.now(),
      unreadCount: {senderId: 0, receiverId: currentTargetUnread + 1},
    );
    await _chatService.sendMessage(chatId, newMessage, updatedChat);
    
    // Send push notification to receiver
    try {
      final notificationService = NotificationService();
      await notificationService.sendMessagePushNotification(
        receiverId: receiverId,
        senderId: senderId,
        senderName: senderName.isNotEmpty ? senderName : 'User',
        messagePreview: attachmentLabelForType(type),
        chatId: chatId,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
    
    animateToBottom();
  }

  Future<void> pickAndSendPhoto({
    required String chatId,
    required String senderId,
    required String receiverId,
  }) async {
    if (!await MediaPermissionsService.requestGallery()) return;
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final fileName = pickedFile.name.isNotEmpty ? pickedFile.name : 'image.jpg';
    final storageRef = FirebaseStorage.instance
        .ref()
        .child(
          'chat_media/$chatId/${senderId}_${DateTime.now().millisecondsSinceEpoch}_$fileName',
        );

    final uploadTask = await storageRef.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    await sendAttachmentMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      type: 'image',
      url: downloadUrl,
      filename: fileName,
    );
  }

  Future<void> startVoiceRecording() async {
    if (isRecording.value) return;
    if (!await MediaPermissionsService.requestMicrophone()) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    isRecording.value = true;
  }

  Future<void> stopVoiceRecording({
    required String chatId,
    required String senderId,
    required String receiverId,
  }) async {
    if (!isRecording.value) return;
    final path = await _recorder.stop();
    isRecording.value = false;
    if (path == null || path.isEmpty) return;

    final file = File(path);
    final storageRef = FirebaseStorage.instance.ref().child(
      'chat_media/$chatId/${senderId}_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    final uploadTask = await storageRef.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    await sendAttachmentMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      type: 'voice',
      url: downloadUrl,
      filename: 'voice message',
    );
    await file.delete();
  }

  // Clear unread counter when opening specific room logs
  Future<void> markAsRead(String chatId, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCount.$currentUserId': 0,
      });
    } catch (e) {
      debugPrint("Error updating unread states: $e");
    }
  }

  void updateMessageSeen(String chatId, String messageId) {
    _chatService.markMessageAsSeen(chatId, messageId);
  }

  Stream<dynamic> fetchUserProfile(String userId) {
    return _chatService.getUserProfileStream(userId);
  }

  Stream<dynamic> fetchAvailableContacts() {
    return _chatService.getAllUsersStream();
  }

  Future<void> searchContacts(String keyword) async {
    if (keyword.trim().isEmpty) {
      searchResults.clear();
      return;
    }

    final snapshot = await fetchAvailableContacts().first;

    searchResults.value = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final username = (data['username'] ?? '').toString().toLowerCase();
      final name = (data['name'] ?? '').toString().toLowerCase();

      return username.contains(keyword.toLowerCase()) ||
          name.contains(keyword.toLowerCase());
    }).toList();
  }

  void animateToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void onClose() {
    _audioRecorder?.dispose();
    textController.dispose();
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
