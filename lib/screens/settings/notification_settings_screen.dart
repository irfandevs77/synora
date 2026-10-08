import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/push_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _all = true;
  bool _messages = true;
  bool _friendRequests = true;
  bool _calls = true;
  bool _general = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    PushNotificationService.requestPermission();
  }

  Future<void> _loadPreferences() async {
    final preferences = await PushNotificationService.getNotificationPreferences();
    if (!mounted) return;
    setState(() {
      _all = preferences['all']!;
      _messages = preferences['messages']!;
      _friendRequests = preferences['friendRequests']!;
      _calls = preferences['calls']!;
      _general = preferences['general']!;
    });
  }

  Future<void> _savePreferences() async {
    await PushNotificationService.setNotificationPreferences(
      all: _all,
      messages: _messages,
      friendRequests: _friendRequests,
      calls: _calls,
      general: _general,
    );

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userDocId') ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'notificationPreferences': {
          'all': _all,
          'messages': _messages,
          'friendRequests': _friendRequests,
          'calls': _calls,
          'general': _general,
        },
      }, SetOptions(merge: true));
    }
  }

  Future<void> _setAll(bool value) async {
    setState(() => _all = value);
    await _savePreferences();
  }

  Future<void> _setCategory(String category, bool value) async {
    setState(() {
      switch (category) {
        case 'messages':
          _messages = value;
        case 'friendRequests':
          _friendRequests = value;
        case 'calls':
          _calls = value;
        case 'general':
          _general = value;
      }
    });
    await _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFF7F5);
    const accent = Color(0xFF9B5032);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 30),
          onPressed: Get.back,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        children: [
          const Text('Synora', style: TextStyle(fontSize: 52, color: Colors.black87)),
          const SizedBox(height: 72),
          Center(child: Image.asset('assets/images/synora_logo.png', width: 94, height: 94)),
          const SizedBox(height: 12),
          const Center(child: Text('synora', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700))),
          const SizedBox(height: 64),
          _MasterSwitch(value: _all, onChanged: _setAll),
          const SizedBox(height: 54),
          const Text('Categories', style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _CategorySwitch(title: 'Messages', value: _messages && _all, onChanged: (value) => _setCategory('messages', value)),
          _CategorySwitch(title: 'Friend requests', value: _friendRequests && _all, onChanged: (value) => _setCategory('friendRequests', value)),
          _CategorySwitch(title: 'Calls', value: _calls && _all, onChanged: (value) => _setCategory('calls', value)),
          _CategorySwitch(title: 'System and general', value: _general && _all, onChanged: (value) => _setCategory('general', value)),
        ],
      ),
    );
  }
}

class _MasterSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MasterSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SwitchTile(
        title: 'All Synora notifications',
        value: value,
        onChanged: onChanged,
        large: true,
      );
}

class _CategorySwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CategorySwitch({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SwitchTile(title: title, value: value, onChanged: onChanged);
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool large;
  const _SwitchTile({required this.title, required this.value, required this.onChanged, this.large = false});

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: large ? 0 : 14),
        padding: EdgeInsets.symmetric(horizontal: large ? 20 : 0, vertical: large ? 22 : 10),
        decoration: large
            ? BoxDecoration(color: const Color(0xFFFFD8CA), borderRadius: BorderRadius.circular(38))
            : null,
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: large ? 22 : 18, color: Colors.black87))),
            Switch(value: value, onChanged: onChanged, activeTrackColor: const Color(0xFF9B5032), activeThumbColor: const Color(0xFFFFE2D8)),
          ],
        ),
      );
}