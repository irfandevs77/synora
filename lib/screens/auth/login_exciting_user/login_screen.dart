import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../navigation/bottom_nav_screen.dart';
import '../../../services/saved_accounts_service.dart';
import '../signup_new_user/signup_auth/phone_screen.dart' as signup;
import 'forgot_password_screen.dart' as forgot;

class LoginScreen extends StatefulWidget {
  final String initialUsername;

  const LoginScreen({super.key, this.initialUsername = ''});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String errorText = '';
  bool obscurePassword = true;
  bool isPressed = false;

  @override
  void initState() {
    super.initState();
    usernameController.text = widget.initialUsername;
  }

  Future<void> login() async {
    setState(() {
      errorText = '';
    });

    final username = usernameController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        errorText = 'Enter username and password';
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _authEmailForUsername(username),
        password: password,
      );
      final userDocId = credential.user?.uid;
      if (userDocId == null || userDocId.isEmpty) {
        throw StateError('Login completed without a user account.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userDocId', userDocId);
      String? sessionSaveError;
      try {
        await SavedAccountsService().rememberCurrentAccount(userId: userDocId);
      } catch (error) {
        debugPrint('Could not remember signed-in account: $error');
        sessionSaveError =
            'Account switching could not be prepared. Try signing in again later.';
      }
      try {
        await SavedAccountsService().saveCurrentAccountSession(
          userId: userDocId,
          email: _authEmailForUsername(username),
          password: password,
        );
      } catch (error) {
        debugPrint('Could not save secure account session: $error');
        sessionSaveError =
            'Account switching could not be prepared. Try signing in again later.';
      }

      debugPrint('LOGIN DOC ID SAVED = $userDocId');

      if (!mounted) return;
      if (sessionSaveError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sessionSaveError)));
      }

      // --- YAHAN PE CHANGES KIYE HAIN ---
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BottomNavScreen(
            userId: userDocId,
          ), // HomeScreen ki jagah BottomNavigationScreen pass kiya
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('LOGIN AUTH ERROR: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        try {
          final legacyUserId = await _legacyFirestoreLogin(username, password);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userDocId', legacyUserId);
          try {
            await SavedAccountsService().rememberCurrentAccount(
              userId: legacyUserId,
            );
            await SavedAccountsService().saveCurrentAccountSession(
              userId: legacyUserId,
              email: _authEmailForUsername(username),
              password: password,
            );
          } catch (rememberError) {
            debugPrint('Could not remember legacy account: $rememberError');
          }
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => BottomNavScreen(userId: legacyUserId),
            ),
            (route) => false,
          );
          return;
        } catch (legacyError) {
          debugPrint('LEGACY LOGIN ERROR: $legacyError');
        }
      }
      setState(() {
        errorText = switch (e.code) {
          'user-not-found' || 'invalid-credential' =>
            'Account not found. Check username and password.',
          'wrong-password' => 'Incorrect password',
          'invalid-email' => 'Enter a valid username or email.',
          'operation-not-allowed' =>
            'Email/password login is not enabled in Firebase.',
          'network-request-failed' =>
            'Could not reach Firebase. Check your internet connection, VPN, or browser blocker and try again.',
          'too-many-requests' =>
            'Too many attempts. Wait a moment and try again.',
          _ => e.message ?? 'Login failed',
        };
      });
    } catch (e) {
      setState(() => errorText = 'Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<String> _legacyFirestoreLogin(String username, String password) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (result.docs.isEmpty) {
      throw StateError('Legacy username not found.');
    }
    final user = result.docs.first;
    final data = user.data();
    if (data['password'] != password) {
      throw StateError('Legacy password is incorrect.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Authentication session was not created.');
    }

    try {
      await authUser.linkWithCredential(
        EmailAuthProvider.credential(
          email: _authEmailForUsername(username),
          password: password,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked' &&
          e.code != 'credential-already-in-use') {
        rethrow;
      }
    }

    final migratedData = Map<String, dynamic>.from(data)
      ..remove('password')
      ..['uid'] = authUser.uid
      ..['migratedFrom'] = user.id;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .set(migratedData);
    return authUser.uid;
  }

  String _authEmailForUsername(String username) {
    return username.contains('@') ? username : '$username@synora.app';
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
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    blurRadius: 180,
                    spreadRadius: 70,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(-20 * (1 - value), 0),
                            child: child,
                          ),
                        );
                      },
                      child: const Text(
                        'SYNORA',
                        style: TextStyle(
                          color: Color(0xFF17213D),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Image.asset(
                    'assets/images/synora_logo.png',
                    width: 110,
                    height: 110,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: Color(0xFF17213D),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 40),

                  TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Color(0xFF17213D)),
                    decoration: inputDecoration('Username'),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Color(0xFF17213D)),
                    decoration: inputDecoration('Password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF8495B2),
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  if (errorText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        errorText,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          isPressed = true;
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          isPressed = false;
                        });
                      },
                      onTapCancel: () {
                        setState(() {
                          isPressed = false;
                        });
                      },
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 100),
                        scale: isPressed ? 0.97 : 1.0,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5A4BFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const forgot.ForgotPasswordPhoneScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF5A4BFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const signup.SignupPhoneScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: "no account? ",
                                  style: TextStyle(
                                    color: Color(0xFF8495B2),
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: "Sign Up",
                                  style: TextStyle(
                                    color: Color(0xFF8B5CF6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const signup.SignupPhoneScreen(),
                          ),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: " ",
                              style: TextStyle(
                                color: Color(0xFF8495B2),
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: "",
                              style: TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
