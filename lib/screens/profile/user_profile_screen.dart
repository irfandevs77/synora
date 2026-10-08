import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';
import '../../services/friends_service.dart';
import '../leaderboard/friends_leaderboard_screen.dart';
import '../xp/xp_screen.dart';

// ==========================================
// 1. STATE CONTROLLER (BUSINESS LOGIC)
// ==========================================
class ProfileController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final String profileUserId;
  ProfileController({required this.profileUserId});

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendsService _friendsService = FriendsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController tabController;

  final isLoading = true.obs;
  final isLoadingChat = false.obs;

  // Loading state observable for toggle lock protection
  final isLoadingFriend = false.obs;
  String _loggedInUserId = '';
  StreamSubscription<String>? _friendStatusSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  // New Friend Request Status Mechanism
  // States: 'none' | 'requested_by_me' | 'requested_by_them' | 'accepted'
  final friendStatus = 'none'.obs;

  final username = ''.obs;
  final name = ''.obs;
  final bio = ''.obs;
  final profileImage = ''.obs;

  final postsCount = 0.obs;
  final friendsCount = 0.obs;
  final xp = 0.obs;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this);
    fetchProfileData();
    _loadCurrentUserAndCheckFriendStatus();
  }

  @override
  void onClose() {
    _friendStatusSubscription?.cancel();
    _profileSubscription?.cancel();
    tabController.dispose();
    super.onClose();
  }

  String get currentUserId => _loggedInUserId;

  Future<void> _loadCurrentUserAndCheckFriendStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedInUserId = prefs.getString('userDocId') ?? _auth.currentUser?.uid ?? '';
    await checkFriendStatus();
    _watchFriendStatus();
  }

  Future<void> _ensureCurrentUserId() async {
    if (_loggedInUserId.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _loggedInUserId = prefs.getString('userDocId') ?? _auth.currentUser?.uid ?? '';
  }

  void _watchFriendStatus() {
    if (_loggedInUserId.isEmpty || _loggedInUserId == profileUserId) return;
    _friendStatusSubscription?.cancel();
    _friendStatusSubscription = _friendsService
        .watchFriendStatus(
          currentUserId: _loggedInUserId,
          profileUserId: profileUserId,
        )
        .listen(
          (status) {
            debugPrint('Friend status updated to: $status');
            friendStatus.value = status;
          },
          onError: (e) {
            debugPrint('Error in friend status stream: $e');
          },
        );
  }

  Future<void> fetchProfileData() async {
    try {
      isLoading(true);

      // Fetch User Meta Details
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(profileUserId)
          .get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        username.value = data['username'] ?? '';
        name.value = data['name'] ?? '';
        bio.value = data['bio'] ?? '';
        profileImage.value = data['profileImage'] ?? '';
        friendsCount.value = data['friendsCount'] ?? 0;
        xp.value = (data['xp'] as num?)?.toInt() ?? 0;
      }

      // Fetch Real-time Live Posts Count
      QuerySnapshot postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: profileUserId)
          .get();
      postsCount.value = postsSnapshot.docs.length;
      _watchProfileData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load profile details: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  void _watchProfileData() {
    _profileSubscription?.cancel();
    _profileSubscription = _firestore
        .collection('users')
        .doc(profileUserId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;
          friendsCount.value = data['friendsCount'] ?? 0;
        });
  }

  // Fast status check using direct deterministic path lookup
  Future<void> checkFriendStatus() async {
    if (currentUserId.isEmpty) return;
    try {
      friendStatus.value = await _friendsService.getStatus(
        currentUserId: currentUserId,
        profileUserId: profileUserId,
      );
    } catch (e) {
      friendStatus.value = 'none';
    }
  }

  // Dynamic Action Handler based on Relationship State Flow
  Future<void> handleFriendAction() async {
    if (isLoadingFriend.value) {
      return;
    }

    await _ensureCurrentUserId();
    if (currentUserId.isEmpty) {
      Get.snackbar(
        'Login required',
        'Your user session could not be found. Please log in again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (currentUserId == profileUserId) {
      Get.snackbar(
        'Unavailable',
        'You cannot add yourself as a friend.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoadingFriend.value = true;

    final String previousStatus = friendStatus.value;
    final int previousFriendsCount = friendsCount.value;

    // Instant Optimistic updates to UI layer
    try {
      if (previousStatus == 'none') {
        // Send friend request
        await _friendsService.sendFriendRequest(
          currentUserId: currentUserId,
          profileUserId: profileUserId,
        );
        friendStatus.value = 'requested_by_me';
      } else if (previousStatus == 'accepted') {
        // Remove friend
        await _friendsService.executeRemoveFriendBatch(
          currentUserId: currentUserId,
          profileUserId: profileUserId,
          friendDocId: FriendsService.getDeterministicDocId(
            currentUserId,
            profileUserId,
          ),
        );
        friendStatus.value = 'none';
        if (friendsCount.value > 0) friendsCount.value--;
      } else if (previousStatus == 'requested_by_me') {
        // Cancel sent request
        await _friendsService.cancelFriendRequest(
          currentUserId: currentUserId,
          profileUserId: profileUserId,
        );
        friendStatus.value = 'none';
      } else if (previousStatus == 'requested_by_them') {
        // Accept incoming friend request
        await _friendsService.acceptFriendRequest(
          currentUserId: currentUserId,
          senderId: profileUserId,
        );
        friendStatus.value = 'accepted';
        friendsCount.value++;
      }
    } catch (e) {
      // Reset changes completely upon failure
      friendStatus.value = previousStatus;
      friendsCount.value = previousFriendsCount;

      Get.snackbar(
        'Error',
        'Action failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoadingFriend.value = false;
    }
  }

  Future<void> declineFriendRequest() async {
    await _ensureCurrentUserId();
    if (currentUserId.isEmpty) {
      Get.snackbar(
        'Login required',
        'Your user session could not be found. Please log in again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoadingFriend.value = true;

    final String previousStatus = friendStatus.value;

    try {
      if (previousStatus == 'requested_by_them') {
        // Decline incoming friend request
        await _friendsService.rejectFriendRequest(
          currentUserId: currentUserId,
          senderId: profileUserId,
        );
        friendStatus.value = 'none';
      }
    } catch (e) {
      // Reset changes completely upon failure
      friendStatus.value = previousStatus;

      Get.snackbar(
        'Error',
        'Action failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoadingFriend.value = false;
    }
  }

  Future<void> initializeAndNavigateChat() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userDocId') ?? '';
    if (currentUserId.isEmpty || profileUserId.isEmpty) {
      return;
    }

    isLoadingChat(true);

    try {
      List<String> ids = [currentUserId, profileUserId];
      ids.sort();

      String deterministicChatId = ids.join('_');

      DocumentReference chatDocRef = _firestore
          .collection('chats')
          .doc(deterministicChatId);
      DocumentSnapshot chatSnapshot = await chatDocRef.get();

      if (!chatSnapshot.exists) {
        await chatDocRef.set({
          'id': deterministicChatId,
          'participants': [currentUserId, profileUserId],
          'lastMessage': '',
          'lastMessageSenderId': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {currentUserId: 0, profileUserId: 0},
        });
      }
      Get.to(
        () => ChatScreen(
          chatId: deterministicChatId,
          receiverId: profileUserId,
          currentUserId: currentUserId,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Chat Error',
        'Could not open conversation: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingChat(false);
    }
  }

  void copyUsername() {
    Clipboard.setData(ClipboardData(text: username.value));
    Get.snackbar(
      'Copied',
      'Username copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void copyProfileLink() {
    final url = "https://synora.app/u/${username.value}";
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar(
      'Copied',
      'Profile link copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

// ==========================================
// 2. USER PROFILE PRESENTATION LAYER (UI)
// ==========================================
class UserProfileScreen extends StatelessWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ProfileController(profileUserId: userId),
      tag: userId,
    );

    const Color backgroundColor = Color(0xFFF8FAFC);
    const Color surfaceColor = Colors.white;
    const Color accentColor = Color(0xFF5A4BFF);
    const Color textPrimary = Color(0xFF17213D);
    const Color textSecondary = Color(0xFF8495B2);

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          surface: surfaceColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: textPrimary,
              size: 20,
            ),
            onPressed: () => Get.back(),
          ),
          centerTitle: true,
          title: Obx(
            () => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.isLoading.value
                      ? 'Loading...'
                      : controller.username.value,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: textPrimary,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: textPrimary),
              onPressed: () => _showMoreMenu(context, controller),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(26),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFF0ABFC),
                                    Color(0xFF38BDF8),
                                    Color(0xFF6366F1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Hero(
                                tag:
                                    'profile_pic_hero_${controller.profileUserId}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    width: 104,
                                    height: 104,
                                    color: surfaceColor,
                                    child:
                                        controller.profileImage.value.isNotEmpty
                                        ? Image.network(
                                            controller.profileImage.value,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: textPrimary,
                                            size: 42,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(
                                    controller.postsCount.value.toString(),
                                    'Posts',
                                  ),
                                  GestureDetector(
                                    onTap: () => Get.to(
                                      () => FriendsLeaderboardScreen(userId: userId),
                                    ),
                                    child: _buildStatItem(
                                      controller.friendsCount.value.toString(),
                                      'Friends',
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Get.to(() => XpScreen(userId: userId)),
                                    child: _buildStatItem(
                                      controller.xp.value.toString(),
                                      'XP',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 14.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.name.value,
                              style: const TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, color: accentColor, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'synora.app',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      controller.friendStatus.value ==
                                              'accepted' ||
                                          controller.friendStatus.value ==
                                              'requested_by_me'
                                      ? surfaceColor
                                      : accentColor,
                                  foregroundColor:
                                      controller.friendStatus.value ==
                                              'accepted' ||
                                          controller.friendStatus.value ==
                                              'requested_by_me'
                                      ? textPrimary
                                      : backgroundColor,
                                  elevation: 0,
                                  minimumSize: const Size(0, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: controller.isLoadingFriend.value
                                    ? null // Lock action interaction while loading
                                    : () => controller.handleFriendAction(),
                                child: controller.isLoadingFriend.value
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: textPrimary,
                                        ),
                                      )
                                    : Text(
                                        // Custom Multi-State String Labels Handling
                                        controller.friendStatus.value ==
                                                'requested_by_me'
                                            ? 'Requested'
                                            : controller.friendStatus.value ==
                                                  'requested_by_them'
                                            ? 'Accept Request'
                                            : controller.friendStatus.value ==
                                                  'accepted'
                                            ? 'Remove Friend'
                                            : 'Add Friend',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: surfaceColor,
                                  side: BorderSide.none,
                                  foregroundColor: textPrimary,
                                  minimumSize: const Size(0, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: controller.isLoadingFriend.value ||
                                        controller.isLoadingChat.value
                                    ? null
                                    : controller.friendStatus.value ==
                                            'requested_by_them'
                                    ? () => controller.declineFriendRequest()
                                    : controller.friendStatus.value ==
                                            'accepted'
                                    ? () =>
                                          controller.initializeAndNavigateChat()
                                    : null,
                                child: controller.isLoadingFriend.value ||
                                        controller.isLoadingChat.value
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: textPrimary,
                                        ),
                                      )
                                    : Text(
                                        controller.friendStatus.value ==
                                                'requested_by_them'
                                            ? 'Decline'
                                            : controller.friendStatus.value ==
                                                  'accepted'
                                            ? 'Message'
                                            : 'Message',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 20,
                                  color: textPrimary,
                                ),
                                onPressed: () => controller.copyProfileLink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: controller.tabController,
                      indicatorColor: textPrimary,
                      indicatorWeight: 2,
                      labelColor: textPrimary,
                      unselectedLabelColor: textSecondary,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                        Tab(icon: Icon(Icons.video_library_rounded, size: 22)),
                        Tab(
                          icon: Icon(Icons.assignment_ind_outlined, size: 22),
                        ),
                      ],
                    ),
                    backgroundColor,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: controller.tabController,
              children: [
                _buildPostsGrid(controller.profileUserId, textSecondary),
                _buildEmptyState(
                  Icons.video_library_outlined,
                  'No Reels Yet',
                  textSecondary,
                ),
                _buildEmptyState(
                  Icons.assignment_ind_outlined,
                  'No Tagged Posts',
                  textSecondary,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsGrid(String targetUserId, Color textSecondary) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: targetUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            Icons.camera_alt_outlined,
            'No Posts Yet',
            textSecondary,
          );
        }

        final docs = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.only(top: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var postData = docs[index].data() as Map<String, dynamic>;
            String postImage = postData['postImageUrl'] ?? '';
            return Container(
              color: const Color(0xFF1E293B),
              child: postImage.isNotEmpty
                  ? Image.network(postImage, fit: BoxFit.cover)
                  : const Icon(Icons.image, color: Colors.white30),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message, Color secondaryText) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: secondaryText.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context, ProfileController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.link, color: Colors.white),
            title: const Text(
              'Copy Profile Link',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Get.back();
              controller.copyProfileLink();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white),
            title: const Text(
              'Copy Username',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Get.back();
              controller.copyUsername();
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. PERSISTENT HEADER DELEGATE
// ==========================================
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _bgColor;

  _SliverAppBarDelegate(this._tabBar, this._bgColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: _bgColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
