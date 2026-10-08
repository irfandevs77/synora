import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, dynamic>
  unreadCount; // User-specific unread counters ke liye updated
  final String lastMessageSenderId;
  final Map<String, dynamic>? typingStatus;
  final List<String> hiddenForUsers;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.lastMessageSenderId,
    this.typingStatus,
    this.hiddenForUsers = const [],
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, dynamic>.from(data['unreadCount'] ?? {}),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      typingStatus: data['typingStatus'] as Map<String, dynamic>?,
      hiddenForUsers: List<String>.from(data['hiddenForUsers'] ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'typingStatus': typingStatus ?? {},
      'hiddenForUsers': hiddenForUsers,
    };
  }
}
