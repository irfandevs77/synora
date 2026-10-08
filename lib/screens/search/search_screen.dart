import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/friends_service.dart';
import '../profile/user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  List<QueryDocumentSnapshot> users = [];
  bool isLoading = false;
  String currentUserId = '';
  final FriendsService _friendsService = FriendsService();
  final Map<String, String> _localStatuses = {};
  final Set<String> _busyUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      currentUserId =
          prefs.getString('userDocId') ??
          FirebaseAuth.instance.currentUser?.uid ??
          '';
    });
  }

  // Optimized Server-side Search Logic
  Future<void> searchUsers(String query) async {
    final cleanQuery = query.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      setState(() {
        users = [];
      });
      return;
    }

    if (currentUserId.isEmpty) await _loadCurrentUserId();

    setState(() {
      isLoading = true;
    });

    try {
      // Direct Query optimization: Poore database ko download nahi karega
      final result = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .startAt([cleanQuery])
          .endAt(['$cleanQuery\uf8ff'])
          .limit(20) // Ek baar mein max 20 users fetch honge (Cost friendly)
          .get();

      setState(() {
        users = result.docs.where((doc) => doc.id != currentUserId).toList();
      });
    } catch (e) {
      debugPrint("OPTIMIZED SEARCH ERROR = $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _handleFriendAction(String profileUserId, String status) async {
    if (currentUserId.isEmpty || _busyUserIds.contains(profileUserId)) return;

    setState(() => _busyUserIds.add(profileUserId));
    try {
      if (status == 'none') {
        setState(() => _localStatuses[profileUserId] = 'requested_by_me');
        await _friendsService.sendFriendRequest(
          currentUserId: currentUserId,
          profileUserId: profileUserId,
        );
      } else if (status == 'requested_by_me') {
        await _friendsService.cancelFriendRequest(
          currentUserId: currentUserId,
          profileUserId: profileUserId,
        );
        if (mounted) setState(() => _localStatuses[profileUserId] = 'none');
      } else if (status == 'requested_by_them') {
        await _friendsService.acceptFriendRequest(
          currentUserId: currentUserId,
          senderId: profileUserId,
        );
        if (mounted) setState(() => _localStatuses[profileUserId] = 'accepted');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localStatuses.remove(profileUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(profileUserId));
    }
  }

  Widget buildUserTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final username = data['username'] ?? '';
    final name = data['name'] ?? '';
    final profileImage = data['profileImage'] ?? '';

    return StreamBuilder<String>(
      stream: currentUserId.isEmpty || currentUserId == doc.id
          ? null
          : _friendsService.watchFriendStatus(
              currentUserId: currentUserId,
              profileUserId: doc.id,
            ),
      builder: (context, statusSnapshot) {
        final status = _localStatuses[doc.id] ??
            statusSnapshot.data ??
            (currentUserId == doc.id ? 'self' : 'none');
        final isBusy = _busyUserIds.contains(doc.id);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: doc.id)),
          ),
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EDF5)),
          ),
          child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: profileImage.toString().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(profileImage),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: const Color(0xFFE8EAF2),
              ),
              child: profileImage.toString().isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF8495B2))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      color: Color(0xFF17213D),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style: TextStyle(color: Color(0xFF8495B2), fontSize: 13),
                  ),
                ],
              ),
            ),
            _buildFriendButton(doc.id, status, isBusy),
          ],
        ),
          ),
        );
      },
    );
  }

  Widget _buildFriendButton(String userId, String status, bool isBusy) {
    if (status == 'self') return const SizedBox.shrink();

    final isAccepted = status == 'accepted';
    final isRequested = status == 'requested_by_me';
    final isIncoming = status == 'requested_by_them';
    final label = isAccepted
        ? 'Friends'
        : isIncoming
            ? 'Accept'
            : isRequested
                ? 'Requested'
                : 'Add Friend';

    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: isBusy || isAccepted
            ? null
            : () => _handleFriendAction(userId, status),
        style: OutlinedButton.styleFrom(
          foregroundColor: isAccepted ? const Color(0xFF16C79A) : const Color(0xFF5A4BFF),
          side: BorderSide(
            color: isAccepted ? const Color(0xFF16C79A) : const Color(0xFF5A4BFF),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Search",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17213D)),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: searchUsers,
              style: const TextStyle(color: Color(0xFF17213D)),
              decoration: InputDecoration(
                hintText: "Search users by username...",
                hintStyle: const TextStyle(color: Color(0xFF8495B2)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8495B2)),
                filled: true,
                fillColor: const Color(0xFFF0F3F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: LinearProgressIndicator(
                color: Color(0xFF5A4BFF),
                backgroundColor: Color(0xFFE8EAF2),
              ),
            ),
          Expanded(
            child: users.isEmpty && !isLoading
                ? Center(
                    child: Text(
                      searchController.text.isEmpty
                          ? "Type to search users"
                          : "No users found",
                      style: const TextStyle(
                        color: Color(0xFF8495B2),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return buildUserTile(users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
