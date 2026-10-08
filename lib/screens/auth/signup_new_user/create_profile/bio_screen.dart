import 'package:flutter/material.dart';

import 'profile_picture.dart';

class BioScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String name;
  final String username;
  final int age;
  final String gender;

  const BioScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.name,
    required this.username,
    required this.age,
    required this.gender,
  });

  @override
  State<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<BioScreen> {
  final TextEditingController bioController = TextEditingController();

  void continueNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePictureScreen(
          phoneNumber: widget.phoneNumber,
          password: widget.password,
          name: widget.name,
          username: widget.username,
          age: widget.age,
          gender: widget.gender,
          bio: bioController.text.trim(),
        ),
      ),
    );
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
    bioController.dispose();
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
                'Tell us about yourself',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Add a short bio (optional)',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: bioController,
                maxLines: 5,
                maxLength: 150,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => continueNext(),
                style: const TextStyle(color: Color(0xFF17213D)),
                decoration: inputDecoration('Write something about yourself...')
                    .copyWith(
                      counterStyle: const TextStyle(color: Color(0xFF8495B2)),
                    ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: continueNext,
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
