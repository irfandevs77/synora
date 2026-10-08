import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/chat_controllers.dart';
import '../../models/chat_model.dart';
import '../../repositories/chat_repositories.dart';
import '../../services/chat_lock_service.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../services/friends_service.dart';
import '../../widgets/chat_lock_dialogs.dart';
import 'friend_chat_search_screen.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_chat_screen.dart';
import 'hidden_chats_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String userId;

  const ChatListScreen({super.key, required this.userId});

  @override
  State<ChatListScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<ChatListScreen> {
  final FriendsService _friendsService = FriendsService();
  final ChatRepository _chatRepository = ChatRepository();
  final ChatLockService _chatLockService = ChatLockService();
  final TextEditingController _searchController = TextEditingController();
  List<String> _pinnedItems = [];
  String _selectedFilter = 'All';
  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _pointerStartPositions = {};
  bool _openingHiddenChats = false;

  static const backgroundColor = Color(0xFFF8FAFC);
  static const surfaceColor = Colors.white;
  static const textPrimary = Color(0xFF17213D);
  static const textSecondary = Color(0xFF8495B2);
  static const accentColor = Color(0xFF5A4BFF);

  @override
  void initState() {
    super.initState();
    _chatRepository.setActiveUser(widget.userId);
    _loadPinnedItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPinnedItems() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _pinnedItems =
          prefs.getStringList('pinned_chats_${widget.userId}') ?? [],
    );
  }

  Future<void> _togglePinnedItem(String id) async {
    final nextItems = [..._pinnedItems];
    if (nextItems.contains(id)) {
      nextItems.remove(id);
    } else {
      nextItems.add(id);
    }
    setState(() => _pinnedItems = nextItems);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_chats_${widget.userId}', nextItems);
  }

  void _showNewChatMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DCE8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: accentColor,
                ),
                title: const Text(
                  'New 1-to-1 Chat',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Choose a friend to message',
                  style: TextStyle(color: textSecondary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openFriendSearch();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.group_add_rounded,
                  color: accentColor,
                ),
                title: const Text(
                  'Create Group',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Start a conversation with friends',
                  style: TextStyle(color: textSecondary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateGroupScreen(userId: widget.userId),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(String friendId) async {
    final controller = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController());
    final chatId = await controller.getOrCreateChatRoom(
      widget.userId,
      friendId,
    );
    if (!mounted) return;
    Get.to(
      () => ChatScreen(
        chatId: chatId,
        receiverId: friendId,
        currentUserId: widget.userId,
      ),
    );
  }

  void _openGroupChat(String groupId, String groupName) {
    Get.to(
      () => GroupChatScreen(
        groupId: groupId,
        groupName: groupName,
        currentUserId: widget.userId,
      ),
    );
  }

  void _openFriendSearch() {
    Get.to(() => FriendChatSearchScreen(userId: widget.userId));
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    _pointerStartPositions[event.pointer] = event.position;
    if (_activePointers.length > 2) {
      _activePointers.clear();
      _pointerStartPositions.clear();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;
    if (_openingHiddenChats ||
        _activePointers.length != 2 ||
        _pointerStartPositions.length != 2) {
      return;
    }

    final pointerIds = _activePointers.keys.toList();
    final firstDelta =
        _activePointers[pointerIds[0]]! -
        _pointerStartPositions[pointerIds[0]]!;
    final secondDelta =
        _activePointers[pointerIds[1]]! -
        _pointerStartPositions[pointerIds[1]]!;
    final oppositeHorizontalSwipe =
        firstDelta.dx.abs() >= 60 &&
        secondDelta.dx.abs() >= 60 &&
        firstDelta.dx * secondDelta.dx < 0 &&
        firstDelta.dx.abs() > firstDelta.dy.abs() * 1.3 &&
        secondDelta.dx.abs() > secondDelta.dy.abs() * 1.3;

    if (oppositeHorizontalSwipe) {
      _openingHiddenChats = true;
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => HiddenChatsScreen(userId: widget.userId),
            ),
          )
          .whenComplete(() {
            _openingHiddenChats = false;
            _activePointers.clear();
            _pointerStartPositions.clear();
          });
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _pointerStartPositions.remove(event.pointer);
  }

  Future<void> _hideGroupForUser(String groupId) async {
    try {
      await _chatRepository.hideGroupForUser(
        groupId: groupId,
        userId: widget.userId,
      );
    } catch (error) {
      _showGroupActionError(error);
    }
  }

  Future<void> _showFriendActions(
    String friendId,
    String friendName,
    String chatId,
  ) async {
    var isLocked = false;
    if (chatId.isNotEmpty) {
      try {
        isLocked = await _chatLockService.isEnabled(
          userId: widget.userId,
          conversationId: chatId,
          kind: ChatLockKind.direct,
        );
      } catch (error) {
        _showChatLockError(error);
        return;
      }
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A4350),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                friendName,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: accentColor,
                ),
                title: const Text(
                  'Message',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openChat(friendId);
                },
              ),
              if (chatId.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _pinnedItems.contains('chat:$chatId')
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    _pinnedItems.contains('chat:$chatId')
                        ? 'Unpin chat'
                        : 'Pin chat',
                    style: const TextStyle(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePinnedItem('chat:$chatId');
                  },
                ),
              if (chatId.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isLocked
                        ? Icons.lock_reset_rounded
                        : Icons.lock_outline_rounded,
                    color: accentColor,
                  ),
                  title: Text(
                    isLocked ? 'Change chat lock PIN' : 'Enable chat lock',
                    style: const TextStyle(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _setChatLock(chatId, ChatLockKind.direct, friendName);
                  },
                ),
              if (chatId.isNotEmpty && isLocked)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    'Disable chat lock',
                    style: TextStyle(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _disableChatLock(chatId, ChatLockKind.direct);
                  },
                ),
              const Divider(color: Color(0xFFE8EDF5)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Remove Friend',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRemove(friendId, friendName);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.block_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Block',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock(friendId, friendName);
                },
              ),
              if (chatId.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.visibility_off_outlined,
                    color: accentColor,
                  ),
                  title: const Text(
                    'Hide this chat',
                    style: TextStyle(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmHideChat(chatId, friendName);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setChatLock(
    String conversationId,
    ChatLockKind kind,
    String conversationName,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat lock enabled for $conversationName.')),
        );
      }
    } catch (error) {
      _showChatLockError(error);
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
      _showChatLockError(error);
    }
  }

  void _showChatLockError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Chat lock action failed: $error')));
  }

  Future<void> _confirmHideChat(String chatId, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Hide chat with $friendName?',
          style: const TextStyle(color: textPrimary, fontSize: 19),
        ),
        content: const Text(
          'This chat will move to Hidden Chats. Only you can see it there.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _chatRepository.hideChatForUser(
        chatId: chatId,
        userId: widget.userId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not hide chat: $error')));
    }
  }

  Future<void> _confirmRemove(String friendId, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Remove $friendName from your friends?',
          style: const TextStyle(color: textPrimary, fontSize: 19),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _friendsService.removeFriend(
      currentUserId: widget.userId,
      profileUserId: friendId,
    );
    if (!mounted) return;
  }

  Future<void> _confirmBlock(String friendId, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Block $friendName?',
          style: const TextStyle(color: textPrimary, fontSize: 19),
        ),
        content: const Text(
          "They won't be able to message or interact with you.",
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Block',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _friendsService.blockUser(
      currentUserId: widget.userId,
      profileUserId: friendId,
    );
    await _friendsService.removeFriend(
      currentUserId: widget.userId,
      profileUserId: friendId,
    );
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chats',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Opposite two-finger swipe for hidden chats',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined, color: textPrimary),
              onPressed: _showNewChatMenu,
            ),
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              icon: const Icon(Icons.more_vert_rounded, color: textPrimary),
              onSelected: (value) {
                if (value == 'friends') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                } else if (value == 'search') {
                  _openFriendSearch();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'search', child: Text('Find a chat')),
                PopupMenuItem(value: 'friends', child: Text('Find friends')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: textSecondary,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE8EDF5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: accentColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                future: _friendsService.getAcceptedFriends(widget.userId),
                builder: (context, friendsSnapshot) {
                  if (friendsSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load friends.\n${friendsSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textSecondary),
                      ),
                    );
                  }
                  if (friendsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  }
                  final friends = friendsSnapshot.data ?? const [];

                  return StreamBuilder<List<ChatModel>>(
                    stream: _chatRepository.streamChatRooms(widget.userId),
                    builder: (context, chatSnapshot) {
                      if (chatSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load chats.\n${chatSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: textSecondary),
                          ),
                        );
                      }
                      final chats = chatSnapshot.data ?? const <ChatModel>[];
                      final chatByFriend = <String, ChatModel>{};
                      for (final chat in chats) {
                        final friendId = chat.participants.firstWhere(
                          (id) => id != widget.userId,
                          orElse: () => '',
                        );
                        if (friendId.isNotEmpty) chatByFriend[friendId] = chat;
                      }
                      return StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      >(
                        stream: _chatRepository.streamGroups(widget.userId),
                        builder: (context, groupSnapshot) {
                          if (groupSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Could not load groups.\n${groupSnapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: textSecondary),
                              ),
                            );
                          }
                          final groupDocs =
                              groupSnapshot.data ??
                              const <
                                QueryDocumentSnapshot<Map<String, dynamic>>
                              >[];
                          final pinnedRows = <MapEntry<DateTime, Widget>>[];
                          final recentRows = <MapEntry<DateTime, Widget>>[];
                          final query = _searchController.text
                              .trim()
                              .toLowerCase();
                          for (final friend in friends) {
                            final chat = chatByFriend[friend.id];
                            if (chat == null) {
                              continue;
                            }
                            final friendData =
                                friend.data() ?? const <String, dynamic>{};
                            final friendName =
                                (friendData['name'] ??
                                        friendData['username'] ??
                                        '')
                                    .toString();
                            final preview = chat.lastMessage;
                            final unread =
                                (chat.unreadCount[widget.userId] as num?)
                                    ?.toInt() ??
                                0;
                            if (_selectedFilter == 'Groups' ||
                                (_selectedFilter == 'Unread' && unread == 0)) {
                              continue;
                            }
                            if (query.isNotEmpty &&
                                !friendName.toLowerCase().contains(query) &&
                                !preview.toLowerCase().contains(query)) {
                              continue;
                            }
                            final row = MapEntry(
                              chat.lastMessageTime,
                              _buildFriendChatPreview(friend, chat),
                            );
                            if (_pinnedItems.contains('chat:${chat.id}')) {
                              pinnedRows.add(row);
                            } else {
                              recentRows.add(row);
                            }
                          }

                          for (final groupDoc in groupDocs) {
                            final data = groupDoc.data();
                            final groupName = (data['name'] ?? 'Group')
                                .toString();
                            final createdBy = (data['createdBy'] ?? '')
                                .toString();
                            final lastMessage = (data['lastMessage'] ?? '')
                                .toString();
                            final imageUrl = (data['imageUrl'] ?? '')
                                .toString();
                            final lastMessageTime =
                                (data['lastMessageTime'] as Timestamp?)
                                    ?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);

                            final groupId = groupDoc.id;
                            if (_selectedFilter == 'Unread' ||
                                (query.isNotEmpty &&
                                    !groupName.toLowerCase().contains(query) &&
                                    !lastMessage.toLowerCase().contains(
                                      query,
                                    ))) {
                              continue;
                            }
                            final row = MapEntry(
                              lastMessageTime,
                              _buildGroupChatRow(
                                groupId: groupDoc.id,
                                groupName: groupName,
                                createdBy: createdBy,
                                lastMessage: lastMessage,
                                lastMessageTime: lastMessageTime,
                                imageUrl: imageUrl,
                              ),
                            );
                            if (_pinnedItems.contains('group:$groupId')) {
                              pinnedRows.add(row);
                            } else {
                              recentRows.add(row);
                            }
                          }
                          pinnedRows.sort((a, b) => b.key.compareTo(a.key));
                          recentRows.sort((a, b) => b.key.compareTo(a.key));
                          final combinedRows = [...pinnedRows, ...recentRows];
                          final onlineFriends = friends.where((friend) {
                            final data =
                                friend.data() ?? const <String, dynamic>{};
                            return data['activeStatus'] != false &&
                                data['isOnline'] == true;
                          }).toList();

                          return RefreshIndicator(
                            color: accentColor,
                            onRefresh: () async {},
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              children: [
                                if (onlineFriends.isNotEmpty &&
                                    query.isEmpty &&
                                    _selectedFilter != 'Groups')
                                  _buildOnlineFriends(onlineFriends),
                                _buildFilterChips(),
                                if (combinedRows.isEmpty)
                                  _buildNoMatchingChats(friends.isEmpty)
                                else
                                  ...combinedRows.map((entry) => entry.value),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendChatPreview(
    DocumentSnapshot<Map<String, dynamic>> friend,
    ChatModel chat,
  ) {
    return _buildChatRow(chat, friend);
  }

  Widget _buildGroupChatRow({
    required String groupId,
    required String groupName,
    required String createdBy,
    required String lastMessage,
    required DateTime lastMessageTime,
    String imageUrl = '',
  }) {
    final preview = lastMessage.trim().isEmpty
        ? 'No messages yet'
        : lastMessage;
    final isPinned = _pinnedItems.contains('group:$groupId');

    return InkWell(
      onTap: () => _openGroupChat(groupId, groupName),
      onLongPress: () => _showGroupActions(groupId, groupName, createdBy),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Row(
          children: [
            _avatar(imageUrl, fallbackIcon: Icons.groups_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatChatTime(lastMessageTime),
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
                if (isPinned) ...[
                  const SizedBox(height: 5),
                  const Icon(
                    Icons.push_pin_rounded,
                    color: accentColor,
                    size: 14,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGroupActions(
    String groupId,
    String groupName,
    String createdBy,
  ) async {
    bool isLocked;
    try {
      isLocked = await _chatLockService.isEnabled(
        userId: widget.userId,
        conversationId: groupId,
        kind: ChatLockKind.group,
      );
    } catch (error) {
      _showChatLockError(error);
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A4350),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                groupName,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isLocked
                      ? Icons.lock_reset_rounded
                      : Icons.lock_outline_rounded,
                  color: accentColor,
                ),
                title: Text(
                  isLocked ? 'Change chat lock PIN' : 'Enable chat lock',
                  style: const TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _setChatLock(groupId, ChatLockKind.group, groupName);
                },
              ),
              if (isLocked)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    'Disable chat lock',
                    style: TextStyle(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _disableChatLock(groupId, ChatLockKind.group);
                  },
                ),
              const Divider(color: Color(0xFFE8EDF5)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: accentColor,
                ),
                title: const Text(
                  'Hide group',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _hideGroupForUser(groupId);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.exit_to_app_rounded,
                  color: Colors.orange,
                ),
                title: const Text(
                  'Leave group',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeaveGroup(groupId, groupName);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _pinnedItems.contains('group:$groupId')
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: accentColor,
                ),
                title: Text(
                  _pinnedItems.contains('group:$groupId')
                      ? 'Unpin group'
                      : 'Pin group',
                  style: const TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _togglePinnedItem('group:$groupId');
                },
              ),
              if (createdBy == widget.userId)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete group',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteGroup(groupId, groupName);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveGroup(String groupId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Leave $groupName?',
          style: const TextStyle(color: textPrimary, fontSize: 19),
        ),
        content: const Text(
          'You will be removed from this group.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update(
        {
          'members': FieldValue.arrayRemove([widget.userId]),
        },
      );
    } catch (error) {
      _showGroupActionError(error);
    }
  }

  Future<void> _confirmDeleteGroup(String groupId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Delete $groupName?',
          style: const TextStyle(color: textPrimary, fontSize: 19),
        ),
        content: const Text(
          'The group and all its messages will be permanently deleted for everyone.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final messages = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final message in messages.docs) {
        batch.delete(message.reference);
      }
      batch.delete(
        FirebaseFirestore.instance.collection('groups').doc(groupId),
      );
      await batch.commit();
    } catch (error) {
      _showGroupActionError(error);
    }
  }

  void _showGroupActionError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Group action failed: $error')));
  }

  Widget _buildChatRow(
    ChatModel chat,
    DocumentSnapshot<Map<String, dynamic>>? friend,
  ) {
    final data = friend?.data() ?? const <String, dynamic>{};
    final name = (data['name'] ?? data['username'] ?? 'Friend').toString();
    final username = (data['username'] ?? '').toString();
    final image = (data['profileImage'] ?? '').toString();
    final unread = (chat.unreadCount[widget.userId] as num?)?.toInt() ?? 0;
    final formattedUnread = _formatUnreadCount(unread);
    final preview = chat.lastMessage.trim().isEmpty
        ? username
        : chat.lastMessage;
    final isOnline = data['activeStatus'] != false && data['isOnline'] == true;
    final isPinned =
        chat.id.isNotEmpty && _pinnedItems.contains('chat:${chat.id}');

    return InkWell(
      onTap: () {
        final friendId = friend?.id ?? '';
        if (friendId.isEmpty) return;
        _openChat(friendId);
      },
      onLongPress: () => _showFriendActions(friend?.id ?? '', name, chat.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Row(
          children: [
            _avatar(image, isOnline: isOnline),
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
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatChatTime(chat.lastMessageTime),
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
                if (isPinned) ...[
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.push_pin_rounded,
                    color: accentColor,
                    size: 14,
                  ),
                ],
                if (unread > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      formattedUnread,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatChatTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return '';
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${time.day}/${time.month}';
  }

  String _formatUnreadCount(int count) {
    if (count > 99) return '99+';
    if (count > 9) return '9+';
    if (count > 4) return '4+';
    return '$count';
  }

  Widget _avatar(
    String image, {
    double size = 52,
    bool isOnline = false,
    IconData fallbackIcon = Icons.person_rounded,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFDCEBFF), Color(0xFFE9E3FF)],
              ),
            ),
            child: ClipOval(
              child: image.isNotEmpty
                  ? Image.network(image, fit: BoxFit.cover)
                  : Icon(fallbackIcon, color: textSecondary, size: size * .48),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF24B47E),
                  shape: BoxShape.circle,
                  border: Border.all(color: surfaceColor, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOnlineFriends(
    List<DocumentSnapshot<Map<String, dynamic>>> friends,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 10),
          child: Text(
            'Online now',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final friend = friends[index];
              final data = friend.data() ?? const <String, dynamic>{};
              final name = (data['name'] ?? data['username'] ?? 'Friend')
                  .toString();
              return GestureDetector(
                onTap: () => _openChat(friend.id),
                child: SizedBox(
                  width: 58,
                  child: Column(
                    children: [
                      _avatar(
                        (data['profileImage'] ?? '').toString(),
                        size: 48,
                        isOnline: true,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: ['All', 'Unread', 'Groups'].map((filter) {
          final selected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFilter = filter),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Colors.white : textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              selectedColor: accentColor,
              backgroundColor: surfaceColor,
              side: BorderSide(
                color: selected ? accentColor : const Color(0xFFE5EAF2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoMatchingChats(bool hasNoFriends) {
    final title = hasNoFriends ? 'Start a conversation' : 'No chats match';
    final message = hasNoFriends
        ? 'Your conversations with friends and groups will appear here.'
        : 'Try another name or switch the chat filter.';
    return Padding(
      padding: const EdgeInsets.only(top: 56, left: 24, right: 24),
      child: Column(
        children: [
          Icon(
            hasNoFriends ? Icons.forum_outlined : Icons.search_off_rounded,
            color: accentColor,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showNewChatMenu,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New chat'),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
