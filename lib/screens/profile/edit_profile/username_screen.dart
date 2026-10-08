import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsernameScreen extends StatefulWidget {
  final String initialUsername;

  const UsernameScreen({super.key, required this.initialUsername});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  late TextEditingController _usernameController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> saveUsername() async {
    final newUsername = _usernameController.text.trim().toLowerCase();
    if (newUsername.isEmpty) return;

    setState(() {
      isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDocId = prefs.getString('userDocId');

      if (userDocId != null && mounted) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .update({'username': newUsername});

        if (mounted) {
          Navigator.pop(context, newUsername);
        }
      }
    } catch (e) {
      debugPrint("SAVE USERNAME ERROR = $e");
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Change Username",
          style: TextStyle(color: Color(0xFF17213D)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF17213D)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF5A4BFF)),
                  ),
                )
              : TextButton(
                  onPressed: saveUsername,
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: Color(0xFF5A4BFF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Username",
              style: TextStyle(color: Color(0xFF8495B2), fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Color(0xFF17213D)),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixText: "@ ",
                prefixStyle: const TextStyle(color: Color(0xFF8495B2)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
