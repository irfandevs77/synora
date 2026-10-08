import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/profile/profile_screen.dart';
import '../screens/upload/upload_screen.dart';
import '../services/friends_service.dart';

class SynoraIdentityHeader extends StatelessWidget {
  final String userId;
  final Widget? trailing;

  const SynoraIdentityHeader({super.key, required this.userId, this.trailing});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17213D);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['username'] ?? data['name'] ?? 'Synora User').toString();
        final image = (data['profileImage'] ?? '').toString();
        return SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserDocId: userId))),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE5EAFF),
                      image: image.isEmpty ? null : DecorationImage(image: NetworkImage(image), fit: BoxFit.cover),
                    ),
                    child: image.isEmpty ? const Icon(Icons.person, color: Color(0xFF8495B2), size: 27) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800))),
                ...?trailing == null ? null : <Widget>[trailing!],
              ],
            ),
          ),
        );
      },
    );
  }
}

class SynoraOwnStoryCircle extends StatelessWidget {
  final String userId;
  final FriendsService _friendsService = FriendsService();

  SynoraOwnStoryCircle({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8FAFC);
    const accent = Color(0xFF5A4BFF);
    const cyan = Color(0xFF30C7D9);
    return SizedBox(
      height: 80,
      child: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _friendsService.getAcceptedFriends(userId),
        builder: (context, friendsSnapshot) {
          final friends = friendsSnapshot.data ?? const [];
          final friendIds = friends.map((friend) => friend.id).take(10).toList();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: friendIds.isEmpty
                ? const Stream.empty()
                : FirebaseFirestore.instance.collection('stories').where('authorId', whereIn: friendIds).snapshots(),
            builder: (context, storiesSnapshot) {
              final activeStories = (storiesSnapshot.data?.docs ?? const []).where((story) {
                final expiresAt = story.data()['expiresAt'];
                return expiresAt is! Timestamp || expiresAt.toDate().isAfter(DateTime.now());
              }).toList();
              return Align(
                alignment: Alignment.centerLeft,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ownCircle(context, background, accent, cyan),
                    ...activeStories.map((story) {
                      final data = story.data();
                      final friend = friends.firstWhere((item) => item.id == data['authorId'], orElse: () => friends.first);
                      final friendData = friend.data() ?? const <String, dynamic>{};
                      return _friendCircle(context, data, friendData, accent, cyan);
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _ownCircle(BuildContext context, Color background, Color accent, Color cyan) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
          builder: (context, snapshot) {
            final image = snapshot.data?.data()?['profileImage']?.toString() ?? '';
            return _circle(image, accent, cyan, background, addButton: true);
          },
        ),
      ),
    );
  }

  Widget _friendCircle(BuildContext context, Map<String, dynamic> story, Map<String, dynamic> friend, Color accent, Color cyan) {
    final image = (story['authorImage'] ?? friend['profileImage'] ?? '').toString();
    return GestureDetector(
      onTap: () => _showStory(context, story),
      child: Padding(padding: const EdgeInsets.only(right: 14), child: _circle(image, accent, cyan, const Color(0xFFF8FAFC))),
    );
  }

  Widget _circle(String image, Color accent, Color cyan, Color background, {bool addButton = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(width: 74, height: 74, padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [accent, cyan])), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE5EAFF), image: image.isEmpty ? null : DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)), child: image.isEmpty ? const Icon(Icons.person, color: Color(0xFF8495B2), size: 32) : null)),
        if (addButton) Positioned(right: -2, bottom: -2, child: Container(width: 27, height: 27, decoration: BoxDecoration(color: accent, shape: BoxShape.circle, border: Border.all(color: background, width: 3)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 17))),
      ],
    );
  }

  void _showStory(BuildContext context, Map<String, dynamic> data) {
    showDialog<void>(context: context, builder: (_) => Dialog(child: AspectRatio(aspectRatio: 9 / 16, child: Container(decoration: BoxDecoration(color: const Color(0xFF17213D), borderRadius: BorderRadius.circular(22), image: data['mediaUrl'] is String && (data['mediaUrl'] as String).isNotEmpty ? DecorationImage(image: NetworkImage(data['mediaUrl'] as String), fit: BoxFit.cover) : null), padding: const EdgeInsets.all(20), alignment: Alignment.bottomLeft, child: Text((data['caption'] ?? 'A moment shared on Synora').toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))))));
  }
}
