import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../navigation/bottom_nav_screen.dart';
import '../auth/login_exciting_user/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final authUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (authUser != null) {
      await prefs.setString('userDocId', authUser.uid);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BottomNavScreen(userId: authUser.uid),
        ),
      );
    } else {
      await prefs.remove('userDocId');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: const CircularProgressIndicator(color: Color(0xFF5A4BFF)),
        ),
      ),
    );
  }
}
