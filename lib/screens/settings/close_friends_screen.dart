import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/friends_service.dart';

class CloseFriendsScreen extends StatefulWidget {
  final String userId;

  const CloseFriendsScreen({super.key, required this.userId});

  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen> {
  static const _ink = Color(0xFF17213D);
  static const _muted = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);

  final FriendsService _friendsService = FriendsService();
  List<DocumentSnapshot<Map<String, dynamic>>> _friends = [];
  Set<String> _closeFriendIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _friendsService.getAcceptedFriends(widget.userId),
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
      ]);
      final friends =
          results[0] as List<DocumentSnapshot<Map<String, dynamic>>>;
      final profile = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final stored = List<String>.from(
        profile.data()?['closeFriends'] ?? const <String>[],
      );
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _closeFriendIds = stored
            .where((id) => friends.any((friend) => friend.id == id))
            .toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load friends: $error')));
    }
  }

  Future<void> _toggle(String friendId, bool selected) async {
    setState(() {
      if (selected) {
        _closeFriendIds.add(friendId);
      } else {
        _closeFriendIds.remove(friendId);
      }
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'closeFriends': selected
                ? FieldValue.arrayUnion([friendId])
                : FieldValue.arrayRemove([friendId]),
          });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (selected) {
          _closeFriendIds.remove(friendId);
        } else {
          _closeFriendIds.add(friendId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update Close Friends: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Close Friends',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _friends.isEmpty
          ? const Center(
              child: Text(
                'Add friends to choose your Close Friends.',
                style: TextStyle(color: _muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _friends.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                final data = friend.data() ?? const <String, dynamic>{};
                final name = (data['name'] ?? data['username'] ?? 'Friend')
                    .toString();
                final image = (data['profileImage'] ?? '').toString();
                final selected = _closeFriendIds.contains(friend.id);
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8EDF5)),
                  ),
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: (value) => _toggle(friend.id, value ?? false),
                    activeColor: _accent,
                    controlAffinity: ListTileControlAffinity.trailing,
                    secondary: CircleAvatar(
                      backgroundColor: const Color(0xFFE9EDFF),
                      backgroundImage: image.isEmpty
                          ? null
                          : NetworkImage(image),
                      child: image.isEmpty
                          ? const Icon(
                              Icons.person_outline_rounded,
                              color: _muted,
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '@${data['username'] ?? friend.id}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
