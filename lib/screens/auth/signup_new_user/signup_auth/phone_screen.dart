import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'otp_screen.dart';
import 'password_screen.dart';

class SignupPhoneScreen extends StatefulWidget {
  const SignupPhoneScreen({super.key});

  @override
  State<SignupPhoneScreen> createState() => _SignupPhoneScreenState();
}

class _SignupPhoneScreenState extends State<SignupPhoneScreen> {
  final phoneController = TextEditingController();

  String countryCode = "+91";
  bool isLoading = false;
  bool _completedAutomatically = false;

  Future<void> _completeAutomaticVerification(
    PhoneAuthCredential credential,
    String phoneNumber,
  ) async {
    if (_completedAutomatically) return;
    _completedAutomatically = true;
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordScreen(phoneNumber: phoneNumber),
        ),
      );
    } catch (e) {
      _completedAutomatically = false;
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Automatic verification failed.')),
        );
      }
    }
  }

  Future<void> sendOTP() async {
    String phoneNumber = countryCode + phoneController.text.trim();

    if (phoneController.text.trim().isEmpty ||
        phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid phone number")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      verificationCompleted: (PhoneAuthCredential credential) {
        _completeAutomaticVerification(credential, phoneNumber);
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? "OTP Failed")));
      },

      codeSent: (String verificationId, int? resendToken) {
        if (_completedAutomatically) return;
        setState(() {
          isLoading = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SignupOtpScreen(
              verificationId: verificationId,
              phoneNumber: phoneNumber,
            ),
          ),
        );
      },

      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF17213D), size: 40),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "SYNORA",
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),

      resizeToAvoidBottomInset: true,

      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),

              Image.asset(
                'assets/images/synora_logo.png',
                width: 110,
                height: 110,
              ),

              const SizedBox(height: 20),

              const Text(
                "Enter Phone Number",
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    CountryCodePicker(
                      initialSelection: 'IN',
                      favorite: const ['+91'],
                      onChanged: (value) {
                        setState(() {
                          countryCode = value.dialCode!;
                        });
                      },
                      textStyle: const TextStyle(color: Color(0xFF17213D)),
                    ),

                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Color(0xFF17213D)),
                        decoration: const InputDecoration(
                          hintText: "Enter 10-digit mobile number",
                          hintStyle: TextStyle(color: Color(0xFF8495B2)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A4BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Send OTP",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
