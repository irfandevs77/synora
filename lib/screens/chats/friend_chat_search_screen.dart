import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/chat_controllers.dart';
import '../../screens/chat/chat_screen.dart';
import '../../services/friends_service.dart';

class FriendChatSearchScreen extends StatefulWidget {
  final String userId;

  const FriendChatSearchScreen({super.key, required this.userId});

  @override
  State<FriendChatSearchScreen> createState() => _FriendChatSearchScreenState();
}

class _FriendChatSearchScreenState extends State<FriendChatSearchScreen> {
  static const backgroundColor = Color(0xFFF8FAFC);
  static const surfaceColor = Colors.white;
  static const textPrimary = Color(0xFF17213D);
  static const textSecondary = Color(0xFF8495B2);
  static const accentColor = Color(0xFF5A4BFF);

  final FriendsService _friendsService = FriendsService();
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot<Map<String, dynamic>>> _friends = [];
  List<String> _historyIds = [];
  bool _isLoading = true;

  String get _historyKey => 'friend_chat_search_history_${widget.userId}';

  @override
  void initState() {
    super.initState();
    _loadFriendsAndHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendsAndHistory() async {
    try {
      final results = await Future.wait([
        _friendsService.getAcceptedFriends(widget.userId),
        SharedPreferences.getInstance(),
      ]);
      final friends = results[0] as List<DocumentSnapshot<Map<String, dynamic>>>;
      final prefs = results[1] as SharedPreferences;
      final friendIds = friends.map((friend) => friend.id).toSet();
      final storedHistory = prefs.getStringList(_historyKey) ?? [];
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _historyIds = storedHistory.where(friendIds.contains).toList();
        _isLoading = false;
      });
      if (_historyIds.length != storedHistory.length) {
        await prefs.setStringList(_historyKey, _historyIds);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DocumentSnapshot<Map<String, dynamic>>> get _visibleFriends {
    final query = _searchController.text.trim().toLowerCase();
    final source = query.isEmpty
        ? _historyIds
            .map((id) => _friends.where((friend) => friend.id == id).firstOrNull)
            .whereType<DocumentSnapshot<Map<String, dynamic>>>()
            .toList()
        : _friends;

    if (query.isEmpty) return source;
    return source.where((friend) {
      final data = friend.data() ?? const <String, dynamic>{};
      final name = (data['name'] ?? '').toString().toLowerCase();
      final username = (data['username'] ?? '').toString().toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  Future<void> _rememberAndOpen(DocumentSnapshot<Map<String, dynamic>> friend) async {
    final nextHistory = [friend.id, ..._historyIds.where((id) => id != friend.id)];
    setState(() => _historyIds = nextHistory);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, nextHistory);
    if (!mounted) return;

    final controller = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController());
    final chatId = await controller.getOrCreateChatRoom(widget.userId, friend.id);
    if (!mounted) return;
    Get.to(() => ChatScreen(
          chatId: chatId,
          receiverId: friend.id,
          currentUserId: widget.userId,
        ));
  }

  Future<void> _removeHistory(String friendId) async {
    final nextHistory = _historyIds.where((id) => id != friendId).toList();
    setState(() => _historyIds = nextHistory);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, nextHistory);
  }

  Future<void> _clearHistory() async {
    setState(() => _historyIds = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  @override
  Widget build(BuildContext context) {
    final visibleFriends = _visibleFriends;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Search chats', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          if (_historyIds.isNotEmpty && !hasQuery)
            TextButton(onPressed: _clearHistory, child: const Text('Clear all', style: TextStyle(color: accentColor))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search your friends',
                      hintStyle: const TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: textSecondary),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, color: textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                if (!hasQuery && _historyIds.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Recent chats', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                Expanded(
                  child: visibleFriends.isEmpty
                      ? Center(child: Text(hasQuery ? 'No friends found' : 'No chat history yet', style: const TextStyle(color: textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: visibleFriends.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final friend = visibleFriends[index];
                            final data = friend.data() ?? const <String, dynamic>{};
                            final name = (data['name'] ?? data['username'] ?? 'Friend').toString();
                            final username = (data['username'] ?? '').toString();
                            final image = (data['profileImage'] ?? '').toString();
                            final isHistory = _historyIds.contains(friend.id);
                            return ListTile(
                              tileColor: surfaceColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE9EDFF),
                                backgroundImage: image.isEmpty ? null : NetworkImage(image),
                                child: image.isEmpty ? const Icon(Icons.person, color: textSecondary) : null,
                              ),
                              title: Text(name, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                              subtitle: username.isEmpty ? null : Text('@$username', style: const TextStyle(color: textSecondary)),
                              trailing: isHistory
                                  ? IconButton(
                                      tooltip: 'Remove from history',
                                      icon: const Icon(Icons.close_rounded, color: textSecondary, size: 18),
                                      onPressed: () => _removeHistory(friend.id),
                                    )
                                  : const Icon(Icons.chat_bubble_outline_rounded, color: accentColor),
                              onTap: () => _rememberAndOpen(friend),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
