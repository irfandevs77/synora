import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/media_permissions_service.dart';
import '../profile/user_profile_screen.dart';

class ChatDetailsScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String currentUserId;

  const ChatDetailsScreen({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.currentUserId,
  });

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  bool _isSavingTheme = false;
  String _selectedColor = '#F8FAFC';
  String _selectedImageUrl = '';
  String _nickname = '';
  bool _activeStatus = true;
  bool _readReceipts = true;
  bool _muted = false;
  final TextEditingController _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChatTheme();
  }

  Future<void> _loadChatTheme() async {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? const <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedColor = (data['chatThemeColor'] ?? '#F8FAFC').toString();
      _selectedImageUrl = (data['chatThemeImageUrl'] ?? '').toString();
      _nickname = prefs.getString('chat_nickname_${widget.chatId}') ?? '';
      _nicknameController.text = _nickname;
      final settings = Map<String, dynamic>.from(data['chatSettings'] ?? const <String, dynamic>{});
      final currentSettings = Map<String, dynamic>.from(settings[widget.currentUserId] ?? const <String, dynamic>{});
      _activeStatus = currentSettings['activeStatus'] != false;
      _readReceipts = currentSettings['readReceipts'] != false;
      _muted = currentSettings['muted'] == true;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _editNickname() async {
    _nicknameController.text = _nickname;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit nickname'),
        content: TextField(
          controller: _nicknameController,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nickname for this chat'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true) return;
    final nickname = _nicknameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_nickname_${widget.chatId}', nickname);
    if (mounted) setState(() => _nickname = nickname);
  }

  Future<void> _saveChatSetting(String key, bool value) async {
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'chatSettings': {
        widget.currentUserId: {key: value},
      },
    }, SetOptions(merge: true));
    if (key == 'activeStatus') {
      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).set({
        'activeStatus': value,
      }, SetOptions(merge: true));
    }
    if (!mounted) return;
    setState(() {
      if (key == 'activeStatus') _activeStatus = value;
      if (key == 'readReceipts') _readReceipts = value;
      if (key == 'muted') _muted = value;
    });
  }

  Future<void> _saveTheme() async {
    setState(() => _isSavingTheme = true);

    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'chatThemeColor': _selectedColor,
        'chatThemeImageUrl': _selectedImageUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat theme saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save theme: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingTheme = false);
    }
  }

  Future<void> _pickThemeImage() async {
    if (!await MediaPermissionsService.requestGallery()) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chat_themes/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      final result = await storageRef.putFile(file);
      final url = await result.ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _selectedImageUrl = url;
        _selectedColor = '#F8FAFC';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image theme failed: $e')),
      );
    }
  }

  Widget _colorOption(String hex) {
    final color = _hexToColor(hex);
    final selected = _selectedColor == hex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = hex;
          _selectedImageUrl = '';
        });
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceAll('#', '').trim();
    if (sanitized.length == 6) {
      return Color(int.parse('FF$sanitized', radix: 16));
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Chat details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: widget.receiverId),
                    ),
                  );
                },
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE9EDFF),
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Icon(Icons.person, size: 52, color: Color(0xFF5A4BFF)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chat theme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17213D),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _colorOption('#F8FAFC'),
                const SizedBox(width: 10),
                _colorOption('#E7E3FF'),
                const SizedBox(width: 10),
                _colorOption('#DFF6E8'),
                const SizedBox(width: 10),
                _colorOption('#FFE8D6'),
                const SizedBox(width: 10),
                _colorOption('#FDE2E2'),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickThemeImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Use gallery image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A4BFF),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            if (_selectedImageUrl.isNotEmpty)
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  image: DecorationImage(
                    image: NetworkImage(_selectedImageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: _hexToColor(_selectedColor),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingTheme ? null : _saveTheme,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A4BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSavingTheme
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save theme'),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF5A4BFF)),
              title: const Text('View profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: widget.receiverId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFF5A4BFF)),
              title: const Text('Nickname'),
              subtitle: Text(_nickname.isEmpty ? 'Only visible to you' : _nickname),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editNickname,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.circle_outlined, color: Color(0xFF5A4BFF)),
              title: const Text('Active status'),
              subtitle: const Text('Allow this friend to see when you are active'),
              value: _activeStatus,
              onChanged: (value) => _saveChatSetting('activeStatus', value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.done_all_rounded, color: Color(0xFF5A4BFF)),
              title: const Text('Read receipts'),
              subtitle: const Text('Allow read status in this chat'),
              value: _readReceipts,
              onChanged: (value) => _saveChatSetting('readReceipts', value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5A4BFF)),
              title: const Text('Mute notifications'),
              value: _muted,
              onChanged: (value) => _saveChatSetting('muted', value),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF5A4BFF)),
              title: const Text('Disappearing messages'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Disappearing messages coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.search_rounded, color: Color(0xFF5A4BFF)),
              title: const Text('Search in chat'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search in chat coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
