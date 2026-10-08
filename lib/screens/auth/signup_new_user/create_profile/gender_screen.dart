import 'package:flutter/material.dart';

import 'bio_screen.dart';

class GenderScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String name;
  final String username;
  final int age;

  const GenderScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.name,
    required this.username,
    required this.age,
  });

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? selectedGender;

  void continueNext() {
    if (selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a gender')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BioScreen(
          phoneNumber: widget.phoneNumber,
          password: widget.password,
          name: widget.name,
          username: widget.username,
          age: widget.age,
          gender: selectedGender!,
        ),
      ),
    );
  }

  Widget genderCard({required String title, required IconData icon}) {
    bool isSelected = selectedGender == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGender = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5A4BFF) : const Color(0xFFF0F3F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF17213D), size: 28),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF17213D),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
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
                'Select Your Gender',
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'This helps personalize your experience',
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              genderCard(title: 'Male', icon: Icons.male),

              genderCard(title: 'Female', icon: Icons.female),

              genderCard(
                title: 'Prefer not to say',
                icon: Icons.person_outline,
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
