import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountPasswordDialog {
  static Future<bool> verify(BuildContext context) async {
    final userController = TextEditingController();
    final passwordController = TextEditingController();
    var error = '';
    var busy = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> verifyCredentials() async {
            if (busy) return;
            setState(() {
              busy = true;
              error = '';
            });
            try {
              final account = FirebaseAuth.instance.currentUser;
              if (account == null || account.isAnonymous) {
                throw StateError(
                  'Sign in to your account before recovering a lock PIN.',
                );
              }
              final accountEmail = account.email;
              if (accountEmail == null || accountEmail.isEmpty) {
                throw StateError(
                  'This account does not have a password login. '
                  'Sign in with your account password first.',
                );
              }

              final accountId = userController.text.trim().toLowerCase();
              final credentialEmail = accountId == account.uid.toLowerCase()
                  ? accountEmail
                  : accountId.contains('@')
                  ? accountId
                  : '$accountId@synora.app';
              if (credentialEmail.toLowerCase() != accountEmail.toLowerCase()) {
                throw StateError(
                  'Enter the username or user ID for the account currently signed in.',
                );
              }

              await account.reauthenticateWithCredential(
                EmailAuthProvider.credential(
                  email: accountEmail,
                  password: passwordController.text,
                ),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            } on FirebaseAuthException catch (exception) {
              if (!dialogContext.mounted) return;
              setState(() {
                busy = false;
                error = switch (exception.code) {
                  'invalid-credential' ||
                  'wrong-password' => 'Incorrect user ID or account password.',
                  'too-many-requests' =>
                    'Too many attempts. Wait a moment and try again.',
                  'network-request-failed' =>
                    'Could not reach Firebase. Check your connection.',
                  _ => exception.message ?? 'Account verification failed.',
                };
              });
            } catch (exception) {
              if (!dialogContext.mounted) return;
              setState(() {
                busy = false;
                error = exception.toString().replaceFirst('Bad state: ', '');
              });
            }
          }

          return AlertDialog(
            title: const Text('Verify your account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the signed-in account user ID/username and password '
                  'to reset this lock PIN.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'User ID / Username / Email',
                  ),
                ),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => verifyCredentials(),
                  decoration: InputDecoration(
                    labelText: 'Account password',
                    errorText: error.isEmpty ? null : error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy ? null : verifyCredentials,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    );
    userController.dispose();
    passwordController.dispose();
    return result ?? false;
  }

  static Future<String?> requestNewPin(
    BuildContext context, {
    required String title,
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'New 4–8 digit PIN',
                  counterText: '',
                ),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = pinController.text;
                if (pin.length < 4 ||
                    pin.length > 8 ||
                    int.tryParse(pin) == null) {
                  setState(() => error = 'Enter 4–8 digits.');
                  return;
                }
                if (pin != confirmController.text) {
                  setState(() => error = 'PINs do not match.');
                  return;
                }
                Navigator.pop(dialogContext, pin);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
    pinController.dispose();
    confirmController.dispose();
    return result;
  }
}
