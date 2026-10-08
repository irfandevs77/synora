import 'package:flutter/material.dart';

import 'username_screen.dart';

class NameScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;

  const NameScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
  });

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController nameController = TextEditingController();

  String errorText = '';

  void continueNext() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        errorText = 'Please enter your full name';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsernameScreen(
          phoneNumber: widget.phoneNumber,
          password: widget.password,
          name: name,
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
    nameController.dispose();
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
                'What is your name?',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'This helps people find you on Synora',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFF17213D)),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => continueNext(),
                decoration: inputDecoration('Full Name'),
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
