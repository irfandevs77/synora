import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../navigation/bottom_nav_screen.dart';
import '../../../../services/media_permissions_service.dart';
import '../../../../services/saved_accounts_service.dart';
import '../../../../services/xp_service.dart';

class ProfilePictureScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String name;
  final String username;
  final int age;
  final String gender;
  final String bio;

  const ProfilePictureScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.name,
    required this.username,
    required this.age,
    required this.gender,
    required this.bio,
  });

  @override
  State<ProfilePictureScreen> createState() => _ProfilePictureScreenState();
}

class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
  File? selectedImage;
  bool _isPicking = false;
  bool _isLoading = false;
  final XpService _xpService = XpService();

  Future<void> pickImage() async {
    if (_isPicking) return;
    if (!await MediaPermissionsService.requestGallery()) return;
    setState(() => _isPicking = true);
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> continueNext() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final uid = user.uid;

      final authEmail = '${widget.username}@synora.app';
      try {
        await user.linkWithCredential(
          EmailAuthProvider.credential(
            email: authEmail,
            password: widget.password,
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked' &&
            e.code != 'credential-already-in-use') {
          rethrow;
        }
      }

      await _xpService.completeSignup(
        profile: {
          'phoneNumber': widget.phoneNumber,
          'name': widget.name,
          'username': widget.username,
          'age': widget.age,
          'gender': widget.gender,
          'bio': widget.bio,
          'profileImage': '', // Image upload is TODO placeholder
        },
        referralId: (await SharedPreferences.getInstance()).getString(
          'pendingReferralId',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userDocId', uid);
      await prefs.remove('pendingReferralId');

      String? sessionSaveError;
      try {
        await SavedAccountsService().saveCurrentAccountSession(
          userId: uid,
          email: authEmail,
          password: widget.password,
        );
      } catch (error) {
        debugPrint('Could not save new account session: $error');
        sessionSaveError =
            'Account created, but quick account switching could not be enabled. Sign in again to enable it.';
      }

      if (mounted) {
        if (sessionSaveError != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(sessionSaveError)));
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BottomNavScreen(userId: uid)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final message =
            e is FirebaseAuthException && e.code == 'operation-not-allowed'
            ? 'Enable Email/Password sign-in in Firebase Authentication.'
            : 'Account creation failed: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF17213D),
            size: 40,
          ),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
            children: [
              const SizedBox(height: 40),
              const Text(
                'Add Profile Picture',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a profile photo for your account',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: (_isPicking || _isLoading) ? null : pickImage,
                child: Container(
                  height: 170,
                  width: 170,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3F9),
                    borderRadius: BorderRadius.circular(24),
                    image: selectedImage != null
                        ? DecorationImage(
                            image: FileImage(selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: selectedImage == null
                      ? (_isPicking
                            ? const Center(
                                child: SizedBox(
                                  height: 50,
                                  width: 50,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF5A4BFF),
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo,
                                color: Color(0xFF8495B2),
                                size: 50,
                              ))
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: (_isPicking || _isLoading) ? null : pickImage,
                child: const Text(
                  'Choose From Gallery',
                  style: TextStyle(color: Color(0xFF5A4BFF), fontSize: 16),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : continueNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A4BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
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
