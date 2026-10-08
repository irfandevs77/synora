import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'password_screen.dart';

class SignupOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const SignupOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  final otpController = TextEditingController();

  bool isLoading = false;

  Future<void> verifyOTP() async {
    if (otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid 6-digit OTP")));
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordScreen(phoneNumber: widget.phoneNumber),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP. Please try again.")),
      );
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF17213D), size: 40),
          onPressed: () => Navigator.pop(context),
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
                "Verify OTP",
                style: TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.phoneNumber,
                style: const TextStyle(color: Color(0xFF8495B2), fontSize: 15),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Enter OTP",
                  hintStyle: const TextStyle(
                    color: Color(0xFF8495B2),
                    letterSpacing: 1,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : verifyOTP,
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
                          "Verify OTP",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Didn't receive the code?",
                style: TextStyle(color: Color(0xFF8495B2)),
              ),

              TextButton(
                onPressed: () {
                  // TODO: Resend OTP
                },
                child: const Text(
                  "Resend OTP",
                  style: TextStyle(
                    color: Color(0xFF5A4BFF),
                    fontWeight: FontWeight.bold,
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
