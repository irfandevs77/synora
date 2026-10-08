import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/friends_service.dart';
import '../profile/user_profile_screen.dart';

class FriendsLeaderboardScreen extends StatelessWidget {
  final String userId;

  const FriendsLeaderboardScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF8FAFC);
    const textPrimary = Color(0xFF17213D);
    const textSecondary = Color(0xFF75819A);
    const accentColor = Color(0xFF5A4BFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Friends Ranking',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: FriendsService().getAcceptedFriends(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Friends ranking unavailable\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textSecondary),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: accentColor));
          }

          final friends = [...snapshot.data!];
          friends.sort((a, b) {
            final aCount = (a.data()?['friendsCount'] as num?)?.toInt() ?? 0;
            final bCount = (b.data()?['friendsCount'] as num?)?.toInt() ?? 0;
            final countComparison = bCount.compareTo(aCount);
            if (countComparison != 0) return countComparison;
            final aName = (a.data()?['name'] ?? a.data()?['username'] ?? '').toString();
            final bName = (b.data()?['name'] ?? b.data()?['username'] ?? '').toString();
            return aName.toLowerCase().compareTo(bName.toLowerCase());
          });

          if (friends.isEmpty) {
            return const Center(
              child: Text('No friends yet', style: TextStyle(color: textSecondary)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = friends[index].data() ?? const <String, dynamic>{};
              final name = (data['name'] ?? data['username'] ?? 'Synora User').toString();
              final image = (data['profileImage'] ?? '').toString();
              final friendCount = (data['friendsCount'] as num?)?.toInt() ?? 0;

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: friends[index].id),
                  ),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7EBF4)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: const Color(0xFFE9EDFF),
                        backgroundImage: image.isEmpty ? null : NetworkImage(image),
                        child: image.isEmpty ? const Icon(Icons.person, color: textSecondary) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '$friendCount friends',
                        style: const TextStyle(color: accentColor, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}