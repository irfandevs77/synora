import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/chat_controllers.dart';
import '../../models/message_model.dart';
import '../../services/chat_lock_service.dart';
import '../../widgets/chat_lock_gate.dart';
import 'chat_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatController _controller = Get.find<ChatController>();
  late FocusNode _focusNode;
  String _localNickname = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _loadLocalNickname();
  }

  void _startChatAfterUnlock() {
    _controller.setCurrentUser(widget.currentUserId);
    _controller.listenToMessages(widget.chatId);
    _controller.markAsRead(widget.chatId, widget.currentUserId);
  }

  Future<void> _loadLocalNickname() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _localNickname =
          prefs.getString('chat_nickname_${widget.chatId}') ?? '',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color defaultBackground = Color(0xFFF8FAFC);
    const Color surfaceColor = Colors.white;
    const Color accentColor = Color(0xFF5A4BFF);
    const Color textPrimary = Color(0xFF17213D);
    const Color textSecondary = Color(0xFF8495B2);

    return ChatLockGate(
      userId: widget.currentUserId,
      conversationId: widget.chatId,
      kind: ChatLockKind.direct,
      onUnlocked: _startChatAfterUnlock,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, themeSnapshot) {
          final themeData =
              themeSnapshot.data?.data() ?? const <String, dynamic>{};
          final themeImageUrl = themeData['chatThemeImageUrl']?.toString();
          final themeColorCode = themeData['chatThemeColor']?.toString();
          final chatSettings = Map<String, dynamic>.from(
            themeData['chatSettings'] ?? const <String, dynamic>{},
          );
          final currentSettings = Map<String, dynamic>.from(
            chatSettings[widget.currentUserId] ?? const <String, dynamic>{},
          );
          final readReceiptsEnabled = currentSettings['readReceipts'] != false;
          final backgroundColor =
              themeImageUrl != null && themeImageUrl.isNotEmpty
              ? defaultBackground
              : _hexToColor(themeColorCode ?? '#F8FAFC');

          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: backgroundColor,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: StreamBuilder<DocumentSnapshot>(
                stream:
                    _controller.fetchUserProfile(widget.receiverId)
                        as Stream<DocumentSnapshot>,
                builder: (context, snapshot) {
                  String username = 'User';
                  String profileImage = '';
                  bool isOnline = false;
                  String presenceText = 'Offline';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    username = _localNickname.isNotEmpty
                        ? _localNickname
                        : (userData?['username'] ?? 'User');
                    isOnline =
                        userData?['activeStatus'] != false &&
                        (userData?['isOnline'] ?? false);
                    profileImage = userData?['profileImage'] ?? '';

                    final lastSeen = userData?['lastSeen'];
                    if (isOnline) {
                      presenceText = 'Active now';
                    } else if (lastSeen is Timestamp) {
                      final diff = DateTime.now().difference(lastSeen.toDate());
                      if (diff.inMinutes < 1) {
                        presenceText = 'Active just now';
                      } else if (diff.inHours < 1) {
                        presenceText = 'Active ${diff.inMinutes} min ago';
                      } else if (diff.inDays < 1) {
                        presenceText = 'Active ${diff.inHours}h ago';
                      } else {
                        presenceText = 'Active ${diff.inDays}d ago';
                      }
                    } else {
                      presenceText = 'Offline';
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailsScreen(
                            chatId: widget.chatId,
                            receiverId: widget.receiverId,
                            currentUserId: widget.currentUserId,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDCEBFF), Color(0xFFE9E3FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: profileImage.isNotEmpty
                                ? Image.network(profileImage, fit: BoxFit.cover)
                                : const Icon(
                                    Icons.person,
                                    color: textSecondary,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                presenceText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOnline ? accentColor : textSecondary,
                                  fontWeight: isOnline
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audio call coming soon')),
                    );
                  },
                  icon: const Icon(Icons.call, color: textPrimary),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video call coming soon')),
                    );
                  },
                  icon: const Icon(Icons.videocam_rounded, color: textPrimary),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: textPrimary),
                  onSelected: (value) {
                    if (value == 'details') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailsScreen(
                            chatId: widget.chatId,
                            receiverId: widget.receiverId,
                            currentUserId: widget.currentUserId,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'details',
                      child: Text('Chat details'),
                    ),
                  ],
                ),
              ],
            ),
            body: Container(
              decoration: themeImageUrl != null && themeImageUrl.isNotEmpty
                  ? BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(themeImageUrl),
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
              child: Column(
                children: [
                  Expanded(
                    child: Obx(() {
                      return ListView.builder(
                        controller: _controller.scrollController,
                        reverse: true,
                        itemCount: _controller.messages.length,
                        itemBuilder: (context, index) {
                          final message = _controller.messages[index];
                          final isMe = message.senderId == widget.currentUserId;

                          if (!isMe && readReceiptsEnabled && !message.isSeen) {
                            _controller.updateMessageSeen(
                              widget.chatId,
                              message.id,
                            );
                          }

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    alignment: Alignment.topCenter,
                                    child: child,
                                  ),
                                ),
                            child: _buildMessageBubble(
                              key: ValueKey(
                                '${message.id}-${message.isUnsent}',
                              ),
                              message: message,
                              isMe: isMe,
                              backgroundColor: backgroundColor,
                              surfaceColor: surfaceColor,
                              accentColor: accentColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  // Input Field
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border(
                        top: BorderSide(color: surfaceColor, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _controller.pickAndSendPhoto(
                              chatId: widget.chatId,
                              senderId: widget.currentUserId,
                              receiverId: widget.receiverId,
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF0F3F9),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF5A4BFF),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F3F9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _controller.textController,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                color: Color(0xFF17213D),
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Aa',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8495B2),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {},
                                        child: const Icon(
                                          Icons.emoji_emotions_outlined,
                                          color: Color(0xFF8495B2),
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Obx(
                          () => IconButton(
                            tooltip: _controller.isRecording.value
                                ? 'Stop recording'
                                : 'Record voice message',
                            icon: Icon(
                              _controller.isRecording.value
                                  ? Icons.stop_circle_outlined
                                  : Icons.mic_none_rounded,
                              color: _controller.isRecording.value
                                  ? Colors.redAccent
                                  : const Color(0xFF17213D),
                            ),
                            onPressed: () {
                              if (_controller.isRecording.value) {
                                _controller.stopVoiceRecording(
                                  chatId: widget.chatId,
                                  senderId: widget.currentUserId,
                                  receiverId: widget.receiverId,
                                );
                              } else {
                                _controller.startVoiceRecording();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 2),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _controller.sendTextMessage(
                              chatId: widget.chatId,
                              senderId: widget.currentUserId,
                              receiverId: widget.receiverId,
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF5A4BFF),
                              ),
                              child: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceAll('#', '').trim();
    if (sanitized.length == 6) {
      return Color(int.parse('FF$sanitized', radix: 16));
    }
    return const Color(0xFFF8FAFC);
  }

  Widget _buildMessageBubble({
    Key? key,
    required MessageModel message,
    required bool isMe,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color accentColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return GestureDetector(
      key: key,
      onLongPress: () => _showMessageActions(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isMe ? accentColor : surfaceColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isUnsent)
                      Text(
                        'This message was unsent',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      )
                    else if (message.type == 'text')
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : textPrimary,
                          fontSize: 15,
                        ),
                      )
                    else if (message.type == 'image')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          message.mediaUrl ?? '',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (message.type == 'voice')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow,
                            color: isMe ? Colors.white : accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Voice note',
                            style: TextStyle(
                              color: isMe ? Colors.white : textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    else if (message.type == 'document')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file,
                            color: isMe ? Colors.white : accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message.fileName ?? 'Document',
                              style: TextStyle(
                                color: isMe ? Colors.white : textPrimary,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isSeen ? Icons.done_all : Icons.done,
                      size: 12,
                      color: message.isSeen ? accentColor : textSecondary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(MessageModel message) {
    final isMine = message.senderId == widget.currentUserId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFF5A4BFF),
              ),
              title: const Text(
                'Delete for me',
                style: TextStyle(color: Color(0xFF17213D)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _controller.deleteMessageForMe(
                  chatId: widget.chatId,
                  messageId: message.id,
                  userId: widget.currentUserId,
                );
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.undo, color: Color(0xFF5A4BFF)),
                title: const Text(
                  'Unsend for everyone',
                  style: TextStyle(color: Color(0xFF17213D)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _controller.unsendMessage(
                    chatId: widget.chatId,
                    messageId: message.id,
                    senderId: message.senderId,
                    currentUserId: widget.currentUserId,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF5A4BFF)),
              title: const Text(
                'Reply',
                style: TextStyle(color: Color(0xFF17213D)),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
