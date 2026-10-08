import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String type; // text, image, voice, document
  final String? mediaUrl;
  final String? fileName;
  final DateTime timestamp;
  final bool isSeen;
  final bool isUnsent;
  final List<String> deletedForUsers;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.type,
    this.mediaUrl,
    this.fileName,
    required this.timestamp,
    required this.isSeen,
    this.isUnsent = false,
    this.deletedForUsers = const [],
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      fileName: data['fileName'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSeen: data['isSeen'] ?? false,
      isUnsent: data['isUnsent'] ?? false,
      deletedForUsers: List<String>.from(data['deletedForUsers'] ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      'timestamp': Timestamp.fromDate(timestamp),
      'isSeen': isSeen,
      'isUnsent': isUnsent,
      'deletedForUsers': deletedForUsers,
    };
  }
}
