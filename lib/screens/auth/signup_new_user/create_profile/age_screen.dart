import 'package:flutter/material.dart';

import 'gender_screen.dart';

class AgeScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String name;
  final String username;

  const AgeScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.name,
    required this.username,
  });

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  final TextEditingController ageController = TextEditingController();

  String errorText = '';

  void continueNext() {
    final ageText = ageController.text.trim();

    setState(() {
      errorText = '';
    });

    if (ageText.isEmpty) {
      setState(() {
        errorText = 'Please enter your age';
      });
      return;
    }

    final int? age = int.tryParse(ageText);

    if (age == null) {
      setState(() {
        errorText = 'Enter a valid age';
      });
      return;
    }

    if (age < 13) {
      setState(() {
        errorText = 'You must be at least 13 years old';
      });
      return;
    }

    if (age > 100) {
      setState(() {
        errorText = 'Enter a valid age';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenderScreen(
          phoneNumber: widget.phoneNumber,
          password: widget.password,
          name: widget.name,
          username: widget.username,
          age: age,
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
    ageController.dispose();
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
                'How old are you?',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your age helps personalize your experience',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => continueNext(),
                style: const TextStyle(color: Color(0xFF17213D)),
                decoration: inputDecoration('Enter Age'),
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
