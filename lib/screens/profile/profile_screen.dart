import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile/edit_profile_screen.dart';
import '../settings/setting_page_screen.dart';
import '../../services/friends_service.dart';
import '../../navigation/bottom_nav_screen.dart';
import '../xp/xp_screen.dart';
import '../leaderboard/friends_leaderboard_screen.dart';
import '../../services/saved_accounts_service.dart';
import '../auth/login_exciting_user/login_screen.dart';
import '../auth/signup_new_user/signup_auth/phone_screen.dart' as signup;

class ProfileScreen extends StatefulWidget {
  final String? targetUserDocId;

  const ProfileScreen({super.key, this.targetUserDocId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  bool isOwnProfile = true;

  String name = '';
  String username = '';
  String bio = '';
  String profileImage = '';

  int friendsCount = 0;
  int xp = 0;

  // FRIENDSHIP STATES: "none", "requested", "friends"
  String friendStatus = "none";
  String? currentLoggedId;
  final FriendsService _friendsService = FriendsService();
  final SavedAccountsService _savedAccountsService = SavedAccountsService();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentLoggedId = prefs.getString('userDocId');

      if (widget.targetUserDocId != null &&
          widget.targetUserDocId != currentLoggedId) {
        isOwnProfile = false;
      } else {
        isOwnProfile = true;
      }

      final targetId = isOwnProfile ? currentLoggedId : widget.targetUserDocId;

      if (targetId == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .get();

      if (!doc.exists) {
        setState(() => isLoading = false);
        return;
      }

      final data = doc.data()!;

      setState(() {
        name = data['name'] ?? '';
        username = data['username'] ?? '';
        bio = data['bio'] ?? '';
        profileImage = data['profileImage'] ?? '';
        friendsCount = data['friendsCount'] ?? 0;
        xp = (data['xp'] as num?)?.toInt() ?? 0;
      });

      if (isOwnProfile) {
        try {
          await _savedAccountsService.rememberCurrentAccount(userId: targetId);
        } catch (error) {
          debugPrint('Could not remember current account: $error');
        }
      }

      // Agar padosi (kisi aur) ki profile hai toh relationship check karo
      if (!isOwnProfile) {
        await checkFriendshipStatus();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("PROFILE ERROR = $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _showAccountSwitcher() async {
    if (currentLoggedId == null || currentLoggedId!.isEmpty) return;
    try {
      await _savedAccountsService.rememberCurrentAccount(
        userId: currentLoggedId,
      );
      final accounts = await _savedAccountsService.getAccounts();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEEA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Switch account',
                      style: TextStyle(
                        color: Color(0xFF17213D),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                ...accounts.map((account) {
                  final isActive = account.userId == currentLoggedId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE9EDFF),
                      child: Text(
                        account.title.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF5A4BFF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      account.title,
                      style: const TextStyle(
                        color: Color(0xFF17213D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: account.subtitle.isEmpty
                        ? null
                        : Text(
                            account.subtitle,
                            style: const TextStyle(color: Color(0xFF8495B2)),
                          ),
                    trailing: isActive
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF5A4BFF),
                            size: 20,
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8495B2),
                          ),
                    onTap: isActive
                        ? null
                        : () => _switchToSavedAccount(account, sheetContext),
                  );
                }),
                const Divider(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF5A4BFF),
                  ),
                  title: const Text(
                    'Add new account',
                    style: TextStyle(
                      color: Color(0xFF17213D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showAddAccountOptions();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load accounts: $error')),
      );
    }
  }

  Future<void> _switchToSavedAccount(
    SavedAccount account,
    BuildContext sheetContext,
  ) async {
    Navigator.pop(sheetContext);
    try {
      final userId = await _savedAccountsService.switchToAccount(
        account.userId,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BottomNavScreen(userId: userId)),
        (route) => false,
      );
    } on SavedAccountSessionExpiredException {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            initialUsername: account.username.isNotEmpty
                ? account.username
                : account.email,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not switch account: $error')),
      );
    }
  }

  Future<void> _showAddAccountOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.login_rounded,
                color: Color(0xFF5A4BFF),
              ),
              title: const Text('Login exciting account'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF5A4BFF),
              ),
              title: const Text('Create new account'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const signup.SignupPhoneScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // STATUS CHECK LOGIC
  Future<void> checkFriendshipStatus() async {
    if (currentLoggedId == null || widget.targetUserDocId == null) return;

    try {
      final status = await _friendsService.getStatus(
        currentUserId: currentLoggedId!,
        profileUserId: widget.targetUserDocId!,
      );
      setState(
        () => friendStatus = status == 'accepted'
            ? 'friends'
            : status == 'requested_by_me'
            ? 'requested'
            : status == 'requested_by_them'
            ? 'requested_by_them'
            : 'none',
      );
    } catch (e) {
      debugPrint("Error checking friendship status: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // BUTTON CLICK LOGIC (HANDLE FRIEND REQUESTS / REMOVE)
  Future<void> handleFriendAction() async {
    if (currentLoggedId == null || widget.targetUserDocId == null) return;

    try {
      if (friendStatus == "none") {
        await _friendsService.sendFriendRequest(
          currentUserId: currentLoggedId!,
          profileUserId: widget.targetUserDocId!,
        );
        setState(() => friendStatus = "requested");
      } else if (friendStatus == "requested") {
        await _friendsService.cancelFriendRequest(
          currentUserId: currentLoggedId!,
          profileUserId: widget.targetUserDocId!,
        );
        setState(() => friendStatus = "none");
      } else if (friendStatus == "requested_by_them") {
        await _friendsService.acceptFriendRequest(
          currentUserId: currentLoggedId!,
          senderId: widget.targetUserDocId!,
        );
        setState(() {
          friendStatus = "friends";
          friendsCount++;
        });
      } else if (friendStatus == "friends") {
        await _friendsService.executeRemoveFriendBatch(
          currentUserId: currentLoggedId!,
          profileUserId: widget.targetUserDocId!,
          friendDocId: FriendsService.getDeterministicDocId(
            currentLoggedId!,
            widget.targetUserDocId!,
          ),
        );
        setState(() {
          friendStatus = "none";
          friendsCount = (friendsCount > 0) ? friendsCount - 1 : 0;
        });
      }
    } catch (e) {
      debugPrint("Error handling friend action: $e");
      // Fallback if fails
      loadProfile();
    }
  }

  Widget statItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Color(0xFF17213D),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8495B2), fontSize: 15),
        ),
      ],
    );
  }

  Widget emptyPostWidget() {
    return Column(
      children: [
        const SizedBox(height: 70),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDCE3EE), width: 1.5),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.photo_library_outlined,
            color: Color(0xFFB5C0D2),
            size: 55,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "No Posts Yet",
          style: TextStyle(
            color: Color(0xFF17213D),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOwnProfile
              ? "Create your first post"
              : "This user hasn't posted anything yet",
          style: const TextStyle(color: Color(0xFF8495B2), fontSize: 15),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Button Text & Colors Setup
    String buttonText = "Add Friend";
    Color buttonColor = const Color(0xFF386BF6);

    if (isOwnProfile) {
      buttonText = "Edit Profile";
      buttonColor = const Color(0xFF8B5CF6);
    } else if (friendStatus == "requested") {
      buttonText = "Requested";
      buttonColor = Colors.orange[700]!;
    } else if (friendStatus == "requested_by_them") {
      buttonText = "Accept Request";
      buttonColor = const Color(0xFF22C55E);
    } else if (friendStatus == "friends") {
      buttonText = "Remove";
      buttonColor = Colors.red[700]!;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5A4BFF)),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF17213D),
                            ),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "@${username.isEmpty ? 'synora_user' : username}",
                                    style: const TextStyle(
                                      color: Color(0xFF17213D),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isOwnProfile)
                                    SizedBox(
                                      width: 22,
                                      height: 28,
                                      child: IconButton(
                                        tooltip: 'Switch account',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _showAccountSwitcher,
                                        icon: const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: Color(0xFF8495B2),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (isOwnProfile)
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.menu,
                                color: Color(0xFF17213D),
                                size: 30,
                              ),
                            ),
                          if (!isOwnProfile) const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 95,
                            height: 95,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF2),
                              borderRadius: BorderRadius.circular(22),
                              image: profileImage.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(profileImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: profileImage.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFF8495B2),
                                    size: 50,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  statItem("0", "Posts"),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            FriendsLeaderboardScreen(
                                              userId: isOwnProfile
                                                  ? currentLoggedId ?? ''
                                                  : widget.targetUserDocId ??
                                                        '',
                                            ),
                                      ),
                                    ),
                                    child: statItem(
                                      friendsCount.toString(),
                                      "Friends",
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => XpScreen(
                                          userId: isOwnProfile
                                              ? currentLoggedId
                                              : widget.targetUserDocId,
                                        ),
                                      ),
                                    ),
                                    child: statItem(xp.toString(), "XP"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bio.isNotEmpty)
                              Text(
                                bio,
                                style: const TextStyle(
                                  color: Color(0xFF8495B2),
                                  fontSize: 15,
                                ),
                              ),
                            if (bio.isNotEmpty) const SizedBox(height: 2),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF17213D),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (isOwnProfile) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EditProfileScreen(),
                                    ),
                                  ).then((_) => loadProfile());
                                } else {
                                  handleFriendAction();
                                }
                              },
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: buttonColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    buttonText,
                                    style: const TextStyle(
                                      color: Color(0xFF17213D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!isOwnProfile) {
                                  debugPrint("Opening chat screen...");
                                }
                              },
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE0E6F0),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    isOwnProfile ? "Share Profile" : "Message",
                                    style: const TextStyle(
                                      color: Color(0xFF17213D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(color: Color(0xFFE5EAF2), thickness: 1),
                    ),
                    emptyPostWidget(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
