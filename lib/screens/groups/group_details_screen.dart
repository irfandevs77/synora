import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/friends_service.dart';
import '../../services/media_permissions_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  static const _background = Color(0xFFF8FAFC);
  static const _textPrimary = Color(0xFF17213D);
  static const _textSecondary = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);
  static const _themeColors = ['#F8FAFC', '#E8F5E9', '#FFF3E0', '#E3F2FD', '#FCE4EC', '#EDE7F6'];

  final _firestore = FirebaseFirestore.instance;
  final _friendsService = FriendsService();

  DocumentReference<Map<String, dynamic>> get _groupRef => _firestore.collection('groups').doc(widget.groupId);

  List<String> _members(Map<String, dynamic> data) => List<String>.from(data['members'] ?? const <String>[]);

  List<String> _admins(Map<String, dynamic> data) {
    final admins = List<String>.from(data['adminIds'] ?? const <String>[]);
    final creator = (data['createdBy'] ?? '').toString();
    if (creator.isNotEmpty && !admins.contains(creator)) admins.add(creator);
    return admins;
  }

  bool _isAdmin(Map<String, dynamic> data) => _admins(data).contains(widget.currentUserId);

  Future<void> _editGroupName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change group name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await _saveGroup({'name': name});
  }

  Future<void> _pickGroupImage() async {
    if (!await MediaPermissionsService.requestGallery()) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    try {
      final result = await FirebaseStorage.instance
          .ref('group_images/${widget.groupId}/${DateTime.now().millisecondsSinceEpoch}.jpg')
          .putFile(File(picked.path));
      await _saveGroup({'imageUrl': await result.ref.getDownloadURL()});
    } catch (error) {
      _showError('Could not update group image: $error');
    }
  }

  Future<void> _saveTheme(String color) => _saveGroup({'themeColor': color});

  Future<void> _saveGroup(Map<String, dynamic> values) async {
    try {
      await _groupRef.set(values, SetOptions(merge: true));
    } catch (error) {
      _showError('Could not save group settings: $error');
    }
  }

  Future<void> _showAddMember(List<String> existingMembers) async {
    final friends = await _friendsService.getAcceptedFriends(widget.currentUserId);
    if (!mounted) return;
    final available = friends.where((friend) => !existingMembers.contains(friend.id)).toList();
    if (available.isEmpty) {
      _showError('All your friends are already in this group.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Add members', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ...available.map((friend) {
              final data = friend.data() ?? const <String, dynamic>{};
              final name = (data['name'] ?? data['username'] ?? 'Friend').toString();
              final image = (data['profileImage'] ?? '').toString();
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: image.isEmpty ? null : NetworkImage(image),
                  child: image.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(name),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _groupRef.update({'members': FieldValue.arrayUnion([friend.id])});
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $memberName?'),
        content: const Text('This member will be removed from the group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _groupRef.update({'members': FieldValue.arrayRemove([memberId])});
  }

  Future<void> _makeAdmin(String memberId, String memberName) async {
    await _groupRef.update({'adminIds': FieldValue.arrayUnion([memberId])});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$memberName is now an admin')));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['name'] ?? 'Group').toString();
        final imageUrl = (data['imageUrl'] ?? '').toString();
        final members = _members(data);
        final admins = _admins(data);
        final isAdmin = _isAdmin(data);
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            title: const Text('Group details', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800)),
            backgroundColor: Colors.transparent,
            foregroundColor: _textPrimary,
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _groupHeader(name, imageUrl, isAdmin),
                    const SizedBox(height: 18),
                    _sectionTitle('Group theme'),
                    const SizedBox(height: 8),
                    _themePicker(data['themeColor']?.toString() ?? _themeColors.first, isAdmin),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Members (${members.length})'),
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () => _showAddMember(members),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...members.map((memberId) => _memberTile(memberId, admins, isAdmin)),
                  ],
                ),
        );
      },
    );
  }

  Widget _groupHeader(String name, String imageUrl, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8EDF5))),
      child: Column(
        children: [
          GestureDetector(
            onTap: isAdmin ? _pickGroupImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFFE9EDFF),
                  backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
                  child: imageUrl.isEmpty ? const Icon(Icons.groups_rounded, size: 42, color: _accent) : null,
                ),
                if (isAdmin)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: _accent,
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
              if (isAdmin)
                IconButton(onPressed: () => _editGroupName(name), icon: const Icon(Icons.edit_rounded, color: _accent, size: 19)),
            ],
          ),
          if (isAdmin) const Text('You are an admin', style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _themePicker(String selected, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: _themeColors.map((color) {
          final isSelected = selected == color;
          return GestureDetector(
            onTap: isAdmin ? () => _saveTheme(color) : null,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _hexToColor(color),
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _accent : const Color(0xFFD9E0EC), width: isSelected ? 3 : 1),
              ),
              child: isSelected ? const Icon(Icons.check, color: _textPrimary, size: 18) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _memberTile(String memberId, List<String> admins, bool isAdmin) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('users').doc(memberId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['name'] ?? data['username'] ?? 'Member').toString();
        final image = (data['profileImage'] ?? '').toString();
        final memberIsAdmin = admins.contains(memberId);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(backgroundImage: image.isEmpty ? null : NetworkImage(image), child: image.isEmpty ? const Icon(Icons.person) : null),
            title: Text(name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(memberIsAdmin ? 'Admin' : 'Member', style: const TextStyle(color: _textSecondary, fontSize: 12)),
            trailing: isAdmin && memberId != widget.currentUserId
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'admin') _makeAdmin(memberId, name);
                      if (value == 'remove') _removeMember(memberId, name);
                    },
                    itemBuilder: (_) => [
                      if (!memberIsAdmin) const PopupMenuItem(value: 'admin', child: Text('Make admin')),
                      const PopupMenuItem(value: 'remove', child: Text('Remove member')),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w800));

  Color _hexToColor(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}
