import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_lock_settings_screen.dart';

class PrivacySafetyScreen extends StatefulWidget {
  final String userId;

  const PrivacySafetyScreen({super.key, required this.userId});

  @override
  State<PrivacySafetyScreen> createState() => _PrivacySafetyScreenState();
}

class _PrivacySafetyScreenState extends State<PrivacySafetyScreen> {
  static const _ink = Color(0xFF17213D);
  static const _muted = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);

  final Map<String, bool> _values = {
    'onlineStatus': true,
    'lastSeen': true,
    'readReceipts': true,
    'typingIndicator': true,
    'profileVisibility': true,
  };
  bool _loading = true;
  String _messagePrivacy = 'Everyone';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final settings = Map<String, dynamic>.from(
        data['privacySettings'] ?? const <String, dynamic>{},
      );
      if (!mounted) return;
      setState(() {
        _values['onlineStatus'] = data['activeStatus'] != false;
        _values['profileVisibility'] = data['isPublic'] != false;
        for (final key in ['lastSeen', 'readReceipts', 'typingIndicator']) {
          _values[key] = settings[key] != false;
        }
        _messagePrivacy = (settings['messagePrivacy'] ?? 'Everyone').toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setValue(String key, bool value) async {
    setState(() => _values[key] = value);
    final updates = switch (key) {
      'onlineStatus' => {'activeStatus': value},
      'profileVisibility' => {'isPublic': value},
      _ => {
        FieldPath(['privacySettings', key]): value,
      },
    };
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(updates);
    } catch (error) {
      if (!mounted) return;
      setState(() => _values[key] = !value);
      _showMessage('Could not save setting: $error');
    }
  }

  Future<void> _setMessagePrivacy(String value) async {
    setState(() => _messagePrivacy = value);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
          FieldPath(['privacySettings', 'messagePrivacy']): value,
        });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _notAvailable(String feature) {
    _showMessage('$feature protection is not implemented yet.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Privacy & Safety',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _section('Visibility'),
                _switch(
                  'Online status',
                  'Show when you are active',
                  'onlineStatus',
                ),
                _switch(
                  'Last seen',
                  'Allow friends to see your recent activity',
                  'lastSeen',
                ),
                _switch(
                  'Profile visibility',
                  'Make your profile visible to other users',
                  'profileVisibility',
                ),
                _section('Messages'),
                _switch(
                  'Read receipts',
                  'Show when messages have been read',
                  'readReceipts',
                ),
                _switch(
                  'Typing indicator',
                  'Show when you are typing',
                  'typingIndicator',
                ),
                _messagePrivacyTile(),
                _section('Safety tools'),
                _unavailableTile(
                  Icons.lock_outline_rounded,
                  'Chat Lock',
                  'Lock selected conversations',
                ),
                _unavailableTile(
                  Icons.visibility_off_outlined,
                  'Hidden Chats',
                  'Keep selected chats out of the inbox',
                ),
                _appLockTile(),
                _unavailableTile(
                  Icons.screenshot_monitor_outlined,
                  'Screenshot alerts',
                  'Notify you when a screenshot is taken',
                ),
                _unavailableTile(
                  Icons.timer_outlined,
                  'Self-destruct messages',
                  'Set messages to expire automatically',
                ),
                _unavailableTile(
                  Icons.verified_user_outlined,
                  'Security settings',
                  'Review account protection options',
                ),
              ],
            ),
    );
  }

  Widget _switch(String title, String subtitle, String key) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF5)),
    ),
    child: SwitchListTile.adaptive(
      value: _values[key] ?? true,
      onChanged: (value) => _setValue(key, value),
      activeTrackColor: _accent,
      title: Text(
        title,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
    ),
  );

  Widget _messagePrivacyTile() => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF5)),
    ),
    child: ListTile(
      title: const Text(
        'Message privacy',
        style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Preference only; message access rules are not enforced yet. Current: $_messagePrivacy',
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in ['Everyone', 'Friends', 'No one'])
                  ListTile(
                    title: Text(option),
                    trailing: option == _messagePrivacy
                        ? const Icon(Icons.check, color: _accent)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
              ],
            ),
          ),
        );
        if (selected != null) await _setMessagePrivacy(selected);
      },
    ),
  );

  Widget _unavailableTile(IconData icon, String title, String subtitle) =>
      Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: ListTile(
          leading: Icon(icon, color: _muted),
          title: Text(
            title,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          trailing: const Icon(Icons.info_outline_rounded, color: _muted),
          onTap: () => _notAvailable(title),
        ),
      );

  Widget _appLockTile() => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF5)),
    ),
    child: ListTile(
      leading: const Icon(Icons.phonelink_lock_rounded, color: _accent),
      title: const Text(
        'App Lock',
        style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
      subtitle: const Text(
        'Set a PIN and optional fingerprint or face unlock',
        style: TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppLockSettingsScreen()),
      ),
    ),
  );

  static Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 9),
    child: Text(
      title,
      style: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
