import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../navigation/bottom_nav_screen.dart';
import '../../../services/saved_accounts_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String errorText = '';

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final password = passwordController.text.trim();
    final confirmation = confirmController.text.trim();

    setState(() => errorText = '');
    if (password.length < 6) {
      setState(() => errorText = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirmation) {
      setState(() => errorText = 'Passwords do not match.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => errorText = 'Your verification session expired.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await user.updatePassword(password);
      final email = user.email;
      if (email != null && email.isNotEmpty) {
        await SavedAccountsService().saveCurrentAccountSession(
          userId: user.uid,
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BottomNavScreen(userId: user.uid)),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.message ?? 'Could not reset password.',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  InputDecoration _decoration(String hint, bool obscure, VoidCallback toggle) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8495B2)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: const Color(0xFF8495B2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Color(0xFF17213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF17213D)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a new password',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use at least six characters to secure your account.',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(color: Color(0xFF17213D)),
                decoration: _decoration('New password', obscurePassword, () {
                  setState(() => obscurePassword = !obscurePassword);
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                style: const TextStyle(color: Color(0xFF17213D)),
                decoration: _decoration('Confirm password', obscureConfirm, () {
                  setState(() => obscureConfirm = !obscureConfirm);
                }),
              ),
              if (errorText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  errorText,
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A4BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save New Password',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
