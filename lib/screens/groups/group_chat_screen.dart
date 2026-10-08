import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/media_permissions_service.dart';
import '../../services/notifications_service.dart';
import '../../services/chat_lock_service.dart';
import '../../widgets/chat_lock_gate.dart';
import 'group_details_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendGroupMessage({
    String? mediaUrl,
    String? fileName,
    String type = 'text',
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;

    setState(() => _isSending = true);

    try {
      final payload = {
        'senderId': widget.currentUserId,
        'text': mediaUrl != null ? 'Sent a photo' : text,
        'type': mediaUrl != null ? 'image' : type,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add(payload);

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .set({
            'lastMessage': mediaUrl != null ? 'Sent a photo' : text,
            'lastMessageTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      final members = List<String>.from(
        groupSnapshot.data()?['members'] ?? const <String>[],
      ).where((memberId) => memberId != widget.currentUserId).toList();
      final senderSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      final senderData = senderSnapshot.data() ?? const <String, dynamic>{};
      final senderName =
          (senderData['username'] ?? senderData['name'] ?? 'User').toString();
      final preview = mediaUrl != null ? 'Sent a photo' : text;
      final notificationService = NotificationService();
      await Future.wait(
        members.map(
          (memberId) => notificationService.sendMessagePushNotification(
            receiverId: memberId,
            senderId: widget.currentUserId,
            senderName: senderName,
            messagePreview: preview.length > 50
                ? '${preview.substring(0, 50)}...'
                : preview,
            chatId: widget.groupId,
          ),
        ),
      );

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendPhoto() async {
    if (!await MediaPermissionsService.requestGallery()) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    final file = File(picked.path);
    final fileName = picked.name.isNotEmpty ? picked.name : 'group_photo.jpg';
    final storageRef = FirebaseStorage.instance.ref().child(
      'group_media/${widget.groupId}/${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );

    try {
      final result = await storageRef.putFile(file);
      final url = await result.ref.getDownloadURL();
      await _sendGroupMessage(mediaUrl: url, fileName: fileName, type: 'image');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5A4BFF);

    return ChatLockGate(
      userId: widget.currentUserId,
      conversationId: widget.groupId,
      kind: ChatLockKind.group,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final name = (data['name'] ?? widget.groupName).toString();
              final imageUrl = (data['imageUrl'] ?? '').toString();
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailsScreen(
                      groupId: widget.groupId,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFE9EDFF),
                      backgroundImage: imageUrl.isEmpty
                          ? null
                          : NetworkImage(imageUrl),
                      child: imageUrl.isEmpty
                          ? const Icon(
                              Icons.groups_rounded,
                              color: Color(0xFF5A4BFF),
                              size: 20,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF17213D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8495B2),
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .snapshots(),
          builder: (context, groupSnapshot) {
            final groupData =
                groupSnapshot.data?.data() ?? const <String, dynamic>{};
            final themeColor = _hexToColor(
              (groupData['themeColor'] ?? '#F8FAFC').toString(),
            );
            return Container(
              color: themeColor,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('groups')
                          .doc(widget.groupId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: accent),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Chat error: ${snapshot.error}'),
                          );
                        }

                        final messages =
                            snapshot.data?.docs ??
                            const <
                              QueryDocumentSnapshot<Map<String, dynamic>>
                            >[];
                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'No messages yet. Start the group chat!',
                            ),
                          );
                        }

                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index].data();
                            final isMe =
                                message['senderId'] == widget.currentUserId;
                            final timestamp =
                                (message['timestamp'] as Timestamp?)?.toDate();
                            final type = (message['type'] ?? 'text').toString();
                            final text = (message['text'] ?? '').toString();

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.74,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? accent : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (type == 'image' &&
                                        message['mediaUrl'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          message['mediaUrl'],
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else if (type == 'text')
                                      Text(
                                        text,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : const Color(0xFF17213D),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timestamp != null
                                          ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                                          : '',
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white70
                                            : const Color(0xFF8495B2),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    color: Colors.white,
                    child: SafeArea(
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _isSending ? null : _pickAndSendPhoto,
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.add_photo_alternate,
                                  color: Color(0xFF5A4BFF),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Write a message...',
                                filled: true,
                                fillColor: const Color(0xFFF3F5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isSending
                                ? null
                                : () => _sendGroupMessage(),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: _isSending
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final value = hex.replaceAll('#', '');
    if (value.length != 6) return const Color(0xFFF8FAFC);
    return Color(int.parse('FF$value', radix: 16));
  }
}
