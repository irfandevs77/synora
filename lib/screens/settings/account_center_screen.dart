import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../profile/edit_profile/edit_profile_screen.dart';

class AccountCenterScreen extends StatelessWidget {
  final String userId;

  const AccountCenterScreen({super.key, required this.userId});

  static const _ink = Color(0xFF17213D);
  static const _muted = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);

  Future<void> _changePassword(BuildContext context) async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your current password'
                    : null,
              ),
              TextFormField(
                controller: nextController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) => (value?.length ?? 0) < 6
                    ? 'Use at least 6 characters'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final email = user?.email;
        if (user == null || email == null) {
          throw StateError(
            'Password sign-in is not available for this account.',
          );
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(nextController.text);
        if (context.mounted) _message(context, 'Password updated.');
      } on FirebaseAuthException catch (error) {
        if (context.mounted) {
          _message(context, error.message ?? 'Could not update password.');
        }
      } catch (error) {
        if (context.mounted) _message(context, error.toString());
      }
    }
    currentController.dispose();
    nextController.dispose();
  }

  Future<void> _changeEmail(BuildContext context) async {
    final controller = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    final nextEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send verification'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nextEmail == null || nextEmail.isEmpty) return;
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(
        nextEmail,
      );
      if (context.mounted) {
        _message(context, 'Check your new address to verify the change.');
      }
    } on FirebaseAuthException catch (error) {
      if (context.mounted) {
        _message(context, error.message ?? 'Could not update email.');
      }
    }
  }

  static void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _unavailable(BuildContext context, String feature) {
    _message(context, '$feature is not available in this app version.');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providers =
        user?.providerData
            .map((provider) => provider.providerId)
            .toSet()
            .join(', ') ??
        'None';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Account Centre',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _section('Personal information'),
          _tile(
            icon: Icons.alternate_email_rounded,
            title: 'Username / Display name',
            subtitle: 'Edit your profile name and username',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          _tile(
            icon: Icons.contact_mail_outlined,
            title: 'Email / Phone',
            subtitle:
                '${user?.email ?? 'No email'}  ·  ${user?.phoneNumber ?? 'No phone'}',
            onTap: () => _changeEmail(context),
          ),
          _tile(
            icon: Icons.password_rounded,
            title: 'Password',
            subtitle: 'Update your sign-in password',
            onTap: () => _changePassword(context),
          ),
          _tile(
            icon: Icons.security_rounded,
            title: 'Login & security',
            subtitle: 'Sign-in method: $providers',
            onTap: () => _unavailable(context, 'Advanced login security'),
          ),
          _tile(
            icon: Icons.link_rounded,
            title: 'Connected accounts',
            subtitle: providers,
            onTap: () => _unavailable(context, 'Account linking'),
          ),
          _tile(
            icon: Icons.history_rounded,
            title: 'Account activity',
            subtitle:
                'Created ${_formatDate(user?.metadata.creationTime)} · Last sign-in ${_formatDate(user?.metadata.lastSignInTime)}',
            onTap: () => _unavailable(context, 'Detailed account activity'),
          ),
          const SizedBox(height: 14),
          _section('Account status'),
          _tile(
            icon: Icons.pause_circle_outline_rounded,
            title: 'Deactivate account',
            subtitle: 'Temporarily disable your account',
            onTap: () => _unavailable(context, 'Account deactivation'),
          ),
          _tile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete account',
            subtitle: 'Permanently remove your account and data',
            destructive: true,
            onTap: () => _unavailable(context, 'Account deletion'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value) => value == null
      ? 'Unavailable'
      : '${value.day}/${value.month}/${value.year}';

  static Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 9),
    child: Text(
      title,
      style: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF5)),
    ),
    child: ListTile(
      leading: Icon(icon, color: destructive ? Colors.redAccent : _accent),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? Colors.redAccent : _ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      onTap: onTap,
    ),
  );
}
