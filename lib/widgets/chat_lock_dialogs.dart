import 'package:flutter/material.dart';

import '../services/chat_lock_service.dart';
import 'account_password_dialog.dart';

class ChatLockDialogs {
  static Future<bool> setPin(
    BuildContext context, {
    required ChatLockService service,
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
  }) async {
    final firstPin = TextEditingController();
    final secondPin = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Set chat lock PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose a separate 4–8 digit PIN for this chat.'),
                const SizedBox(height: 16),
                TextField(
                  controller: firstPin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: secondPin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
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
                  final pin = firstPin.text;
                  if (pin.length < 4 ||
                      pin.length > 8 ||
                      int.tryParse(pin) == null) {
                    setState(() => error = 'Enter 4–8 digits.');
                    return;
                  }
                  if (pin != secondPin.text) {
                    setState(() => error = 'PINs do not match.');
                    return;
                  }
                  Navigator.pop(dialogContext, pin);
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );
    firstPin.dispose();
    secondPin.dispose();
    if (result == null) return false;
    await service.enable(
      userId: userId,
      conversationId: conversationId,
      kind: kind,
      pin: result,
    );
    return true;
  }

  static Future<bool> authenticate(
    BuildContext context, {
    required ChatLockService service,
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
    bool disableOnVerify = false,
  }) async {
    final pinController = TextEditingController();
    var error = '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> verifyPin() async {
            try {
              final valid = await service.verify(
                userId: userId,
                conversationId: conversationId,
                kind: kind,
                pin: pinController.text,
              );
              if (!dialogContext.mounted) return;
              if (valid) {
                if (disableOnVerify) {
                  await service.disable(
                    userId: userId,
                    conversationId: conversationId,
                    kind: kind,
                  );
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } else {
                setState(() => error = 'Incorrect PIN.');
              }
            } catch (exception) {
              if (dialogContext.mounted) {
                setState(() => error = 'Chat lock failed: $exception');
              }
            }
          }

          return AlertDialog(
            title: Text(disableOnVerify ? 'Disable chat lock' : 'Chat locked'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disableOnVerify
                      ? 'Enter this chat’s PIN to disable its lock.'
                      : 'Enter this chat’s PIN to continue.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Chat PIN',
                    counterText: '',
                    errorText: error.isEmpty ? null : error,
                  ),
                  onSubmitted: (_) => verifyPin(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final verified = await AccountPasswordDialog.verify(
                    dialogContext,
                  );
                  if (!verified || !dialogContext.mounted) return;
                  try {
                    final reset = await setPin(
                      dialogContext,
                      service: service,
                      userId: userId,
                      conversationId: conversationId,
                      kind: kind,
                    );
                    if (!reset) return;
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (exception) {
                    if (dialogContext.mounted) {
                      setState(
                        () => error = 'Could not disable lock: $exception',
                      );
                    }
                  }
                },
                child: const Text('Forgot PIN?'),
              ),
              FilledButton(
                onPressed: verifyPin,
                child: Text(disableOnVerify ? 'Disable' : 'Unlock'),
              ),
            ],
          );
        },
      ),
    );
    pinController.dispose();
    return result ?? false;
  }

  static Future<bool> disable(
    BuildContext context, {
    required ChatLockService service,
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
  }) {
    return authenticate(
      context,
      service: service,
      userId: userId,
      conversationId: conversationId,
      kind: kind,
      disableOnVerify: true,
    );
  }
}
