import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/friends_service.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  final String userId;

  const CreateGroupScreen({super.key, required this.userId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final FriendsService friendsService = FriendsService();
  final Set<String> selectedFriendIds = <String>{};
  final TextEditingController groupNameController = TextEditingController();
  List<DocumentSnapshot<Map<String, dynamic>>> friends = const [];
  bool isLoadingFriends = true;
  bool isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final loadedFriends = await friendsService.getAcceptedFriends(widget.userId);
      if (!mounted) return;
      setState(() {
        friends = loadedFriends;
        isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingFriends = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load friends: $e')),
      );
    }
  }

  Future<String?> _promptForGroupName() async {
    groupNameController.clear();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Group name', style: TextStyle(color: Color(0xFF17213D))),
        content: TextField(
          controller: groupNameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter group name',
            filled: true,
            fillColor: const Color(0xFFF3F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = groupNameController.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a group name')),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> createGroup() async {
    if (selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend')),
      );
      return;
    }

    final groupName = await _promptForGroupName();
    if (groupName == null || groupName.trim().isEmpty) return;

    setState(() => isCreating = true);

    try {
      final members = <String>{widget.userId, ...selectedFriendIds}.toList();
      final groupRef = await FirebaseFirestore.instance.collection('groups').add({
        'name': groupName.trim(),
        'createdBy': widget.userId,
        'adminIds': [widget.userId],
        'members': members,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: groupRef.id,
            groupName: groupName.trim(),
            currentUserId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group creation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => isCreating = false);
    }
  }

  @override
  void dispose() {
    groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17213D);
    const accent = Color(0xFF5A4BFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create group', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: isLoadingFriends
          ? const Center(child: CircularProgressIndicator(color: accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group_add_rounded, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${selectedFriendIds.length} friends selected',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('Add friends before creating a group'),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final data = friend.data() ?? const <String, dynamic>{};
                      final image = data['profileImage']?.toString() ?? '';
                      final name = (data['name'] ?? data['username'] ?? 'Friend').toString();
                      final isSelected = selectedFriendIds.contains(friend.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? accent : const Color(0xFFE7EBF4),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedFriendIds.remove(friend.id);
                              } else {
                                selectedFriendIds.add(friend.id);
                              }
                            });
                          },
                          leading: CircleAvatar(
                            backgroundImage: image.isEmpty ? null : NetworkImage(image),
                            backgroundColor: const Color(0xFFE9EDFF),
                            child: image.isEmpty ? const Icon(Icons.person, color: Color(0xFF75819A)) : null,
                          ),
                          title: Text(name, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: accent)
                              : const Icon(Icons.radio_button_unchecked, color: Color(0xFFB6C1D1)),
                        ),
                      );
                    },
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isCreating || selectedFriendIds.isEmpty ? null : createGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
