import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final captionController = TextEditingController();
  bool isPosting = false;

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || captionController.text.trim().isEmpty) return;
    setState(() => isPosting = true);
    await FirebaseFirestore.instance.collection('posts').add({
      'authorId': userId,
      'caption': captionController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() => isPosting = false);
    captionController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post shared with your circle')));
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17213D);
    const accent = Color(0xFF5A4BFF);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Create', style: TextStyle(color: ink, fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(height: 220, decoration: BoxDecoration(color: const Color(0xFFE9EDFF), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.add_photo_alternate_outlined, color: accent, size: 48)),
        const SizedBox(height: 18),
        TextField(controller: captionController, maxLines: 5, decoration: InputDecoration(hintText: 'Share something meaningful...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: isPosting ? null : _publish, icon: const Icon(Icons.send_rounded), label: Text(isPosting ? 'Sharing...' : 'Share with friends'), style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 16))),
      ]),
    );
  }
}
