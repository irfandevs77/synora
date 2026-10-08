import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controllers.dart';
import '../../models/chat_model.dart';
import '../../repositories/chat_repositories.dart';
import '../../services/chat_lock_service.dart';
import '../../widgets/chat_lock_dialogs.dart';
import '../chat/chat_screen.dart';
import '../groups/group_chat_screen.dart';

class HiddenChatsScreen extends StatefulWidget {
  final String userId;

  const HiddenChatsScreen({super.key, required this.userId});

  @override
  State<HiddenChatsScreen> createState() => _HiddenChatsScreenState();
}

class _HiddenChatsScreenState extends State<HiddenChatsScreen> {
  static const _background = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _primary = Color(0xFF17213D);
  static const _secondary = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);

  final ChatRepository _repository = ChatRepository();
  final ChatLockService _chatLockService = ChatLockService();
  int _selectedTab = 0;

  Future<void> _unhideChat(String chatId) async {
    try {
      await _repository.unhideChatForUser(
        chatId: chatId,
        userId: widget.userId,
      );
    } catch (error) {
      _showError('Could not unhide chat: $error');
    }
  }

  Future<void> _unhideGroup(String groupId) async {
    try {
      await _repository.unhideGroupForUser(
        groupId: groupId,
        userId: widget.userId,
      );
    } catch (error) {
      _showError('Could not unhide group: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openChat(ChatModel chat, String peerId) {
    if (peerId.isEmpty) {
      _showError(
        'Could not open this chat because its other participant is missing.',
      );
      return;
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController());
    }
    Get.to(
      () => ChatScreen(
        chatId: chat.id,
        receiverId: peerId,
        currentUserId: widget.userId,
      ),
    );
  }

  void _openGroup(String groupId, String groupName) {
    Get.to(
      () => GroupChatScreen(
        groupId: groupId,
        groupName: groupName,
        currentUserId: widget.userId,
      ),
    );
  }

  Future<void> _showHiddenActions({
    required String conversationId,
    required String name,
    required ChatLockKind kind,
    required VoidCallback onUnhide,
  }) async {
    bool isLocked;
    try {
      isLocked = await _chatLockService.isEnabled(
        userId: widget.userId,
        conversationId: conversationId,
        kind: kind,
      );
    } catch (error) {
      _showError('Could not check chat lock: $error');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined, color: _accent),
              title: Text(
                kind == ChatLockKind.group ? 'Unhide group' : 'Unhide chat',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onUnhide();
              },
            ),
            ListTile(
              leading: Icon(
                isLocked ? Icons.lock_reset_rounded : Icons.lock_outline,
                color: _accent,
              ),
              title: Text(
                isLocked ? 'Change chat lock PIN' : 'Enable chat lock',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _setChatLock(conversationId, name, kind);
              },
            ),
            if (isLocked)
              ListTile(
                leading: const Icon(
                  Icons.lock_open_rounded,
                  color: Colors.orange,
                ),
                title: const Text('Disable chat lock'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _disableChatLock(conversationId, kind);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setChatLock(
    String conversationId,
    String name,
    ChatLockKind kind,
  ) async {
    try {
      final isLocked = await _chatLockService.isEnabled(
        userId: widget.userId,
        conversationId: conversationId,
        kind: kind,
      );
      if (!mounted) return;
      if (isLocked) {
        final verified = await ChatLockDialogs.authenticate(
          context,
          service: _chatLockService,
          userId: widget.userId,
          conversationId: conversationId,
          kind: kind,
        );
        if (!mounted || !verified) return;
        final stillLocked = await _chatLockService.isEnabled(
          userId: widget.userId,
          conversationId: conversationId,
          kind: kind,
        );
        if (!mounted || !stillLocked) return;
      }
      if (!mounted) return;
      await ChatLockDialogs.setPin(
        context,
        service: _chatLockService,
        userId: widget.userId,
        conversationId: conversationId,
        kind: kind,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chat lock enabled for $name.')));
      }
    } catch (error) {
      _showError('Could not set chat lock: $error');
    }
  }

  Future<void> _disableChatLock(
    String conversationId,
    ChatLockKind kind,
  ) async {
    try {
      await ChatLockDialogs.disable(
        context,
        service: _chatLockService,
        userId: widget.userId,
        conversationId: conversationId,
        kind: kind,
      );
    } catch (error) {
      _showError('Could not disable chat lock: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text(
          'Hidden Chats',
          style: TextStyle(
            color: _primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Row(
                children: [_buildTab('Chats', 0), _buildTab('Groups', 1)],
              ),
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? _buildHiddenChats()
                : _buildHiddenGroups(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? _accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : _secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenChats() {
    return StreamBuilder<List<ChatModel>>(
      stream: _repository.streamHiddenChatRooms(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            'Could not load hidden chats.\n${snapshot.error}',
            icon: Icons.error_outline_rounded,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return _buildMessage(
            'Hidden chats will appear here.',
            icon: Icons.visibility_off_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final peerId = chat.participants.firstWhere(
              (id) => id != widget.userId,
              orElse: () => '',
            );
            if (peerId.isEmpty) {
              return _buildChatRow(chat, '', const {});
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(peerId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                final userData =
                    userSnapshot.data?.data() ?? const <String, dynamic>{};
                final name =
                    (userData['name'] ?? userData['username'] ?? 'Friend')
                        .toString();
                return _buildChatRow(chat, peerId, userData, name: name);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatRow(
    ChatModel chat,
    String peerId,
    Map<String, dynamic> userData, {
    String name = 'Friend',
  }) {
    final imageUrl = (userData['profileImage'] ?? '').toString();
    final unread = (chat.unreadCount[widget.userId] as num?)?.toInt() ?? 0;
    final preview = chat.lastMessage.trim().isEmpty
        ? (userData['username'] ?? 'No messages yet').toString()
        : chat.lastMessage;
    return _conversationCard(
      name: name,
      preview: preview,
      imageUrl: imageUrl,
      fallbackIcon: Icons.person_rounded,
      time: chat.lastMessageTime,
      unread: unread,
      onTap: () => _openChat(chat, peerId),
      onUnhide: () => _unhideChat(chat.id),
      onLongPress: () => _showHiddenActions(
        conversationId: chat.id,
        name: name,
        kind: ChatLockKind.direct,
        onUnhide: () => _unhideChat(chat.id),
      ),
    );
  }

  Widget _buildHiddenGroups() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _repository.streamGroups(widget.userId, hidden: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            'Could not load hidden groups.\n${snapshot.error}',
            icon: Icons.error_outline_rounded,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final groups = snapshot.data!;
        if (groups.isEmpty) {
          return _buildMessage(
            'Hidden groups will appear here.',
            icon: Icons.groups_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final data = group.data();
            final groupName = (data['name'] ?? 'Group').toString();
            final lastMessage = (data['lastMessage'] ?? '').toString();
            final time =
                (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return _conversationCard(
              name: groupName,
              preview: lastMessage.trim().isEmpty
                  ? 'No messages yet'
                  : lastMessage,
              imageUrl: (data['imageUrl'] ?? '').toString(),
              fallbackIcon: Icons.groups_rounded,
              time: time,
              onTap: () => _openGroup(group.id, groupName),
              onUnhide: () => _unhideGroup(group.id),
              onLongPress: () => _showHiddenActions(
                conversationId: group.id,
                name: groupName,
                kind: ChatLockKind.group,
                onUnhide: () => _unhideGroup(group.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _conversationCard({
    required String name,
    required String preview,
    required String imageUrl,
    required IconData fallbackIcon,
    required DateTime time,
    required VoidCallback onTap,
    required VoidCallback onUnhide,
    required VoidCallback onLongPress,
    int unread = 0,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Row(
          children: [
            _avatar(imageUrl, fallbackIcon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _secondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(time),
                  style: const TextStyle(color: _secondary, fontSize: 11),
                ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Move to Chats',
              onPressed: onUnhide,
              icon: const Icon(
                Icons.visibility_outlined,
                color: _accent,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String imageUrl, IconData fallbackIcon) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFDCEBFF), Color(0xFFE9E3FF)],
        ),
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Icon(fallbackIcon, color: _secondary, size: 24)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(fallbackIcon, color: _secondary, size: 24),
              ),
      ),
    );
  }

  Widget _buildMessage(String message, {required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _accent, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return '';
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${time.day}/${time.month}';
  }
}
