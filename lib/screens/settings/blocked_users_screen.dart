import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BlockedUsersScreen extends StatelessWidget {
  final String userId;

  const BlockedUsersScreen({super.key, required this.userId});

  static const _ink = Color(0xFF17213D);
  static const _muted = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);

  Future<void> _unblock(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> blocked,
  ) async {
    final data = blocked.data();
    final blockedUserId = (data['blockedUserId'] ?? '').toString();
    if (blockedUserId.isEmpty) return;
    try {
      await blocked.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User unblocked.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not unblock user: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Blocked',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('blockedUsers')
            .where('blockerId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load blocked users.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          final blockedUsers = snapshot.data!.docs;
          if (blockedUsers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_flipped, size: 42, color: _muted),
                  SizedBox(height: 12),
                  Text(
                    'No blocked users',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUsers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final blocked = blockedUsers[index];
              final blockedId = (blocked.data()['blockedUserId'] ?? '')
                  .toString();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
                child: ListTile(
                  leading:
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(blockedId)
                            .get(),
                        builder: (context, profile) {
                          final profileData =
                              profile.data?.data() ?? const <String, dynamic>{};
                          final image = (profileData['profileImage'] ?? '')
                              .toString();
                          return CircleAvatar(
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
                          );
                        },
                      ),
                  title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(blockedId)
                        .get(),
                    builder: (context, profile) {
                      final data =
                          profile.data?.data() ?? const <String, dynamic>{};
                      return Text(
                        (data['name'] ?? data['username'] ?? 'Synora user')
                            .toString(),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  subtitle: Text(
                    '@$blockedId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _unblock(context, blocked),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
