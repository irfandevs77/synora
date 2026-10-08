import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NameScreen extends StatefulWidget {
  final String initialName;

  const NameScreen({super.key, required this.initialName});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late TextEditingController _nameController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

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
            .update({'name': newName});

        if (mounted) {
          Navigator.pop(context, newName);
        }
      }
    } catch (e) {
      debugPrint("SAVE NAME ERROR = $e");
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
        title: const Text("Change Name", style: TextStyle(color: Color(0xFF17213D))),
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
                  onPressed: saveName,
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
              "Your Name",
              style: TextStyle(color: Color(0xFF8495B2), fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Color(0xFF17213D)),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
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
