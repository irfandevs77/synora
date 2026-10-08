import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'name_screen.dart';
import 'username_screen.dart';
import 'bio_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool isLoading = true;

  String name = "";
  String username = "";
  String bio = "";
  bool isPublic = true;
  String userDocId = "";

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString('userDocId');

      if (savedUid == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      userDocId = savedUid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          name = data['name'] ?? 'No Name';
          username = data['username'] ?? 'no_username';
          bio = data['bio'] ?? 'No Bio...';
          isPublic = data['isPublic'] ?? true;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("FETCH USER ERROR = $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updatePrivacy(bool value) async {
    try {
      if (userDocId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .update({'isPublic': value});
    } catch (e) {
      debugPrint("PRIVACY UPDATE ERROR = $e");
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8495B2),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget settingTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF17213D),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8495B2), fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF8495B2)),
        onTap: onTap,
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                "SYNORA",
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5A4BFF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 75,
                            color: Color(0xFF8495B2),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A4BFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF17213D),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@$username",
                    style: const TextStyle(color: Color(0xFF8495B2), fontSize: 15),
                  ),
                  const SizedBox(height: 30),
                  sectionTitle("Basic Info"),
                  settingTile(
                    title: "Name",
                    value: name,
                    onTap: () async {
                      final updatedName = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NameScreen(initialName: name),
                        ),
                      );
                      if (updatedName != null && updatedName.isNotEmpty) {
                        setState(() {
                          name = updatedName;
                        });
                      }
                    },
                  ),
                  settingTile(
                    title: "Username",
                    value: username,
                    onTap: () async {
                      final updatedUsername = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UsernameScreen(initialUsername: username),
                        ),
                      );
                      if (updatedUsername != null &&
                          updatedUsername.isNotEmpty) {
                        setState(() {
                          username = updatedUsername;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  sectionTitle("About"),
                  settingTile(
                    title: "Bio",
                    value: bio,
                    onTap: () async {
                      final updatedBio = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BioScreen(initialBio: bio),
                        ),
                      );
                      if (updatedBio != null) {
                        setState(() {
                          bio = updatedBio;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  sectionTitle("Privacy"),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Public Account",
                            style: TextStyle(
                              color: Color(0xFF17213D),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: isPublic,
                          activeThumbColor: const Color(0xFF5A4BFF),
                          onChanged: (value) {
                            setState(() {
                              isPublic = value;
                            });
                            updatePrivacy(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
