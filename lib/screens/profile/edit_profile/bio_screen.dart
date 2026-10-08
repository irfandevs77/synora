import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BioScreen extends StatefulWidget {
  final String initialBio;

  const BioScreen({super.key, required this.initialBio});

  @override
  State<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<BioScreen> {
  late TextEditingController _bioController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> saveBio() async {
    final newBio = _bioController.text.trim();

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
            .update({'bio': newBio});

        if (mounted) {
          Navigator.pop(context, newBio);
        }
      }
    } catch (e) {
      debugPrint("SAVE BIO ERROR = $e");
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
        title: const Text("Edit Bio", style: TextStyle(color: Color(0xFF17213D))),
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
                  onPressed: saveBio,
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
              "Bio",
              style: TextStyle(color: Color(0xFF8495B2), fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 150,
              style: const TextStyle(color: Color(0xFF17213D)),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                counterStyle: const TextStyle(color: Color(0xFF8495B2)),
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
