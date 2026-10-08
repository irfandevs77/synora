import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'age_screen.dart';

class UsernameScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String name;

  const UsernameScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.name,
  });

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController usernameController = TextEditingController();

  bool isLoading = false;
  String errorText = '';

  Future<void> continueNext() async {
    final username = usernameController.text.trim().toLowerCase();

    setState(() {
      errorText = '';
    });

    if (username.isEmpty) {
      setState(() {
        errorText = 'Please enter a username';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        errorText = 'Username must be at least 3 characters';
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final usernameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        setState(() {
          errorText = 'Username already taken';
          isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgeScreen(
            phoneNumber: widget.phoneNumber,
            password: widget.password,
            name: widget.name,
            username: username,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8495B2)),
      filled: true,
      fillColor: const Color(0xFFF0F3F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
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
                'Choose Username',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your username is unique on Synora',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: usernameController,
                style: const TextStyle(color: Color(0xFF17213D)),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => continueNext(),
                decoration: inputDecoration('@username'),
              ),

              if (errorText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorText,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : continueNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A4BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
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
