import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'settings_list/log_out.dart';
import 'notification_settings_screen.dart';
import '../../services/xp_service.dart';
import '../xp/xp_screen.dart';
import '../auth/login_exciting_user/login_screen.dart';
import 'account_center_screen.dart';
import 'privacy_safety_screen.dart';
import 'blocked_users_screen.dart';
import 'close_friends_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final XpService _xpService = XpService();
  bool _isTransferring = false;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _shareInvite() async {
    if (_userId.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join me on Synora: https://synora.app/invite?ref=$_userId',
        subject: 'Join me on Synora',
      ),
    );
  }

  Future<void> _showTransferDialog(int availableXp) async {
    final receiverController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gift XP'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: receiverController,
                decoration: const InputDecoration(labelText: 'Friend user ID'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a friend user ID'
                    : null,
              ),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'XP amount (you have $availableXp)',
                ),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter a whole number'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isTransferring
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    final amount = int.parse(amountController.text.trim());
                    if (amount < 1) return;
                    setState(() => _isTransferring = true);
                    try {
                      await _xpService.transferXp(
                        receiverId: receiverController.text.trim(),
                        amount: amount,
                        transferId:
                            '${_userId}_${DateTime.now().microsecondsSinceEpoch}',
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) _message('XP sent successfully.');
                    } catch (error) {
                      if (mounted) _message('XP transfer failed: $error');
                    } finally {
                      if (mounted) setState(() => _isTransferring = false);
                    }
                  },
            child: const Text('Send XP'),
          ),
        ],
      ),
    );
    receiverController.dispose();
    amountController.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showComingSoonSnackbar() {
    Get.snackbar(
      "Coming Soon",
      "This feature will be available soon.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF17213D),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
    );
  }

  void _openSettingsPage(String destination) {
    final page = switch (destination) {
      'account' => AccountCenterScreen(userId: _userId),
      'privacy' => PrivacySafetyScreen(userId: _userId),
      'blocked' => BlockedUsersScreen(userId: _userId),
      'close-friends' => CloseFriendsScreen(userId: _userId),
      'add-account' => const LoginScreen(),
      'logout' => const LogoutScreen(),
      _ => null,
    };
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }
  }

  void _openSettingsSearch() {
    showSearch<void>(
      context: context,
      delegate: _SettingsSearchDelegate((destination) {
        _openSettingsPage(destination);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Search settings',
            onPressed: _openSettingsSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          _buildSettingsCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Account Centre',
            subtitle: 'Personal information and account security',
            onTap: () => _openSettingsPage('account'),
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(
            icon: Icons.shield_outlined,
            title: 'Privacy & Safety',
            subtitle: 'Presence, visibility and message privacy',
            onTap: () => _openSettingsPage('privacy'),
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(
            icon: Icons.block_outlined,
            title: 'Blocked',
            subtitle: 'Review and unblock accounts',
            onTap: () => _openSettingsPage('blocked'),
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(
            icon: Icons.star_outline_rounded,
            title: 'Close Friends',
            subtitle: 'Choose who belongs to your close-friends list',
            onTap: () => _openSettingsPage('close-friends'),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader("Preferences"),
          _buildSettingsCard(
            icon: Icons.bolt_outlined,
            title: "XP & Rewards",
            subtitle: "Progress, invites and gifts",
            onTap: () => Get.to(() => const XpScreen()),
          ),
          const SizedBox(height: 8),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userId.isEmpty
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(_userId)
                      .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final ads = (data['xpAdsWatched'] as num?)?.toInt() ?? 0;
              final xp = (data['xp'] as num?)?.toInt() ?? 0;
              return Column(
                children: [
                  _buildSettingsCard(
                    icon: Icons.share_outlined,
                    title: 'Invite a friend',
                    subtitle: '+2 XP when they complete signup',
                    onTap: _shareInvite,
                  ),
                  const SizedBox(height: 8),
                  _buildSettingsCard(
                    icon: Icons.card_giftcard_outlined,
                    title: 'Gift XP to a friend',
                    subtitle: 'Mutual friends only; 100 XP daily limit',
                    onTap: () => _showTransferDialog(xp),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingsCard(
                    icon: Icons.ondemand_video_outlined,
                    title: 'Earn XP',
                    subtitle: 'Watch ads: $ads / 25 this week',
                    onTap: () =>
                        _message('Rewarded ads are not configured yet.'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            icon: Icons.notifications_none,
            title: "Notifications",
            onTap: () => Get.to(() => const NotificationSettingsScreen()),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader("Support & Info"),
          _buildSettingsCard(
            icon: Icons.help_outline,
            title: "Help & Support",
            onTap: _showComingSoonSnackbar,
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(
            icon: Icons.info_outline,
            title: "About",
            subtitle: "Version 1.0.0",
            onTap: _showComingSoonSnackbar,
          ),
          const SizedBox(height: 24),

          _buildSettingsCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Add Account',
            subtitle: 'Sign in to another Synora account',
            onTap: () => _openSettingsPage('add-account'),
          ),
          const SizedBox(height: 8),
          _buildLogoutCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF8495B2),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EDF5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: const Color(0xFF5A4BFF), size: 24),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Color(0xFF17213D)),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8495B2)),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFFD4D4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
        title: const Text(
          "Logout",
          style: TextStyle(
            fontSize: 16,
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          Get.to(() => const LogoutScreen());
        },
      ),
    );
  }
}

class _SettingsSearchDelegate extends SearchDelegate<void> {
  final ValueChanged<String> onSelect;

  _SettingsSearchDelegate(this.onSelect);

  static const destinations = <({String key, String label, String detail})>[
    (
      key: 'account',
      label: 'Account Centre',
      detail: 'Personal information, email, password',
    ),
    (
      key: 'account',
      label: 'Username / Display name',
      detail: 'Personal information',
    ),
    (key: 'account', label: 'Email / Phone', detail: 'Personal information'),
    (key: 'account', label: 'Password', detail: 'Login & security'),
    (key: 'account', label: 'Connected accounts', detail: 'Login & security'),
    (key: 'account', label: 'Account activity', detail: 'Login & security'),
    (
      key: 'account',
      label: 'Deactivate / Delete account',
      detail: 'Account status',
    ),
    (
      key: 'privacy',
      label: 'Privacy & Safety',
      detail: 'Online status, receipts, profile visibility',
    ),
    (key: 'privacy', label: 'Online status', detail: 'Privacy & Safety'),
    (key: 'privacy', label: 'Last seen', detail: 'Privacy & Safety'),
    (key: 'privacy', label: 'Read receipts', detail: 'Privacy & Safety'),
    (key: 'privacy', label: 'Typing indicator', detail: 'Privacy & Safety'),
    (key: 'privacy', label: 'Profile visibility', detail: 'Privacy & Safety'),
    (key: 'privacy', label: 'Message privacy', detail: 'Privacy & Safety'),
    (
      key: 'privacy',
      label: 'Chat Lock / Hidden Chats',
      detail: 'Privacy & Safety',
    ),
    (
      key: 'privacy',
      label: 'App Lock / Screenshot alerts',
      detail: 'Privacy & Safety',
    ),
    (
      key: 'privacy',
      label: 'Self-destruct messages',
      detail: 'Privacy & Safety',
    ),
    (key: 'privacy', label: 'Security settings', detail: 'Privacy & Safety'),
    (key: 'blocked', label: 'Blocked', detail: 'Blocked users and unblock'),
    (key: 'blocked', label: 'Unblock', detail: 'Blocked users'),
    (
      key: 'close-friends',
      label: 'Close Friends',
      detail: 'Manage your close-friends list',
    ),
    (
      key: 'add-account',
      label: 'Add Account',
      detail: 'Sign in and switch accounts',
    ),
    (key: 'logout', label: 'Log Out', detail: 'Sign out of Synora'),
  ];

  @override
  String get searchFieldLabel => 'Search settings';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = destinations.where(
      (item) =>
          normalized.isEmpty ||
          item.label.toLowerCase().contains(normalized) ||
          item.detail.toLowerCase().contains(normalized),
    );
    return ListView(
      children: matches
          .map(
            (item) => ListTile(
              leading: const Icon(Icons.tune_rounded, color: Color(0xFF5A4BFF)),
              title: Text(item.label),
              subtitle: Text(item.detail),
              onTap: () {
                close(context, null);
                onSelect(item.key);
              },
            ),
          )
          .toList(),
    );
  }
}
