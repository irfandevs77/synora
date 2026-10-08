import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/home/home_screen.dart';
import '../screens/chats/chat_list_screen.dart';
import '../screens/leaderboard/global_leaderboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';

class BottomNavScreen extends StatefulWidget {
  final String userId;

  const BottomNavScreen({super.key, required this.userId});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int selectedIndex = 0;
  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();

    // Verification engine fallback validation
    final verifiedId = widget.userId.isEmpty
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : widget.userId;

    screens = [
      HomeScreen(userId: verifiedId),
      ChatListScreen(userId: verifiedId),
      const SearchScreen(),
      GlobalLeaderboardScreen(userId: verifiedId),
      ProfileScreen(targetUserDocId: verifiedId),
    ];
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5A4BFF);
    const Color backgroundColor = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      // IndexedStack screens ki state ko memory me preserve rakhta hai bina unhe rebuild kiye
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(color: const Color(0xFFE8EDF5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildNavItem(
                0,
                Icons.home_outlined,
                'Home',
                primaryColor,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                1,
                Icons.chat_bubble_outline_rounded,
                'Chats',
                primaryColor,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                2,
                Icons.people_outline_rounded,
                'Friends',
                primaryColor,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                3,
                Icons.emoji_events_outlined,
                'Leaderboard',
                primaryColor,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                4,
                Icons.person_outline_rounded,
                'Profile',
                primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color activeColor,
  ) {
    final bool isSelected = selectedIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () => onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : const Color(0xFF8495B2),
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? activeColor : const Color(0xFF8495B2),
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
