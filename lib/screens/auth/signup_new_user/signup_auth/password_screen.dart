import 'package:flutter/material.dart';

import '../create_profile/name_screen.dart';

class PasswordScreen extends StatefulWidget {
  final String phoneNumber;

  const PasswordScreen({super.key, required this.phoneNumber});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String passwordError = '';
  String confirmPasswordError = '';

  Future<void> continueSignup() async {
    setState(() {
      passwordError = '';
      confirmPasswordError = '';
    });

    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        passwordError = 'Please enter a password';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        passwordError = 'Password must be at least 6 characters';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NameScreen(phoneNumber: widget.phoneNumber, password: password),
      ),
    );

    setState(() {
      isLoading = false;
    });
  }

  InputDecoration inputDecoration(
    String hint,
    bool obscure,
    VoidCallback onToggle,
  ) {
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
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: Color(0xFF8495B2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF17213D),
            size: 40,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 22),
            child: Center(
              child: Text(
                'SYNORA',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Create Password',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose a secure password for your account',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(color: Color(0xFF17213D)),
                decoration: inputDecoration('Password', obscurePassword, () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                }),
              ),

              if (passwordError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    passwordError,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 20),

              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                style: const TextStyle(color: Color(0xFF17213D)),
                decoration: inputDecoration(
                  'Confirm Password',
                  obscureConfirmPassword,
                  () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
              ),

              if (confirmPasswordError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    confirmPasswordError,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : continueSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A4BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
