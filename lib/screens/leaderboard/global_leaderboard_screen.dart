import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/synora_identity_header.dart';
import '../profile/user_profile_screen.dart';

class GlobalLeaderboardScreen extends StatelessWidget {
  final String userId;

  const GlobalLeaderboardScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17213D);
    const muted = Color(0xFF75819A);
    const accent = Color(0xFF5A4BFF);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SynoraIdentityHeader(
          userId: userId,
          trailing: const Icon(Icons.emoji_events_outlined, color: accent),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('xp', descending: true).limit(50).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Leaderboard unavailable\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: muted)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: accent));
          final users = snapshot.data!.docs;
          if (users.isEmpty) return const Center(child: Text('No XP rankings yet', style: TextStyle(color: muted)));
          return ListView.separated(padding: const EdgeInsets.all(16), itemCount: users.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (context, index) {
            final data = users[index].data();
            final xp = (data['xp'] as num?)?.toInt() ?? 0;
            final image = data['profileImage']?.toString() ?? '';
            final isCurrentUser = users[index].id == userId;
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: users[index].id))),
              borderRadius: BorderRadius.circular(16),
              child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isCurrentUser ? const Color(0xFFF0EFFF) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isCurrentUser ? accent : const Color(0xFFE7EBF4), width: isCurrentUser ? 2 : 1)), child: Row(children: [Text('${index + 1}', style: const TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(width: 14), CircleAvatar(radius: 23, backgroundImage: image.isEmpty ? null : NetworkImage(image), backgroundColor: const Color(0xFFE9EDFF), child: image.isEmpty ? const Icon(Icons.person, color: muted) : null), const SizedBox(width: 12), Expanded(child: Text('${(data['name'] ?? data['username'] ?? 'Synora User')}${isCurrentUser ? ' (You)' : ''}', style: const TextStyle(color: ink, fontWeight: FontWeight.w800))), Text('$xp XP', style: const TextStyle(color: accent, fontWeight: FontWeight.w800))])),
            );
          });
        },
      ),
    );
  }
}
