import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class XpScreen extends StatefulWidget {
  final String? userId;

  const XpScreen({super.key, this.userId});

  @override
  State<XpScreen> createState() => _XpScreenState();
}

class _XpScreenState extends State<XpScreen> {
  String get _userId => widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isOwnProfile => _userId == FirebaseAuth.instance.currentUser?.uid;

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Color(0xFF17213D), fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF8495B2), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _activityRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .14),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF17213D), fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF8495B2), fontSize: 10)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(color: Color(0xFF12BFA3), fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) return const Scaffold(body: Center(child: Text('Sign in required.')));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        title: Text(_isOwnProfile ? 'XP' : 'Profile XP', style: const TextStyle(color: Color(0xFF17213D), fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _isOwnProfile ? 'XP settings' : 'More options',
            icon: Icon(_isOwnProfile ? Icons.settings_outlined : Icons.more_horiz, color: const Color(0xFF17213D)),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(_userId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final xp = (data['xp'] as num?)?.toInt() ?? 0;
          final usage = (data['xpUsageSeconds'] as num?)?.toInt() ?? 0;
          final ads = (data['xpAdsWatched'] as num?)?.toInt() ?? 0;
          final name = (data['name'] ?? data['username'] ?? 'Synora User').toString();
          final username = (data['username'] ?? '').toString();
          final image = (data['profileImage'] ?? '').toString();
          final friends = (data['friendsCount'] as num?)?.toInt() ?? 0;
          final signupAwarded = data['xpSignupAwarded'] == true;
          final level = xp ~/ 500 + 1;
          final nextLevelXp = level * 500;
          final progress = (xp / nextLevelXp).clamp(0.0, 1.0).toDouble();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAE5FF), Color(0xFFDDF5FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6857F4).withValues(alpha: .16),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFF5A4BFF), size: 29),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Color(0xFF17213D), fontSize: 16, fontWeight: FontWeight.w800)),
                              Text(
                                username.isNotEmpty
                                    ? '@$username  •  Level $level'
                                    : 'Level $level  •  ${_isOwnProfile ? 'Explorer' : 'Synora member'}',
                                style: const TextStyle(color: Color(0xFF8495B2), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (image.isNotEmpty)
                          CircleAvatar(radius: 20, backgroundImage: NetworkImage(image)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('$xp XP', style: const TextStyle(color: Color(0xFF17213D), fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(minHeight: 9, value: progress, backgroundColor: Colors.white70, color: const Color(0xFF5A4BFF)),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('$xp / $nextLevelXp', style: const TextStyle(color: Color(0xFF8495B2), fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7EBF4)),
                ),
                child: Row(
                  children: [
                    _statTile(icon: Icons.local_fire_department_rounded, value: '0', label: 'Day Streak', color: Colors.orange),
                    _statTile(icon: Icons.people_alt_rounded, value: '$friends', label: 'Friends', color: const Color(0xFF5A4BFF)),
                    _statTile(icon: Icons.star_rounded, value: '0', label: 'Achievements', color: Colors.amber),
                    _statTile(icon: Icons.shield_rounded, value: 'Level $level', label: 'Current Level', color: const Color(0xFF6557E8)),
                  ],
                ),
              ),
              if (_isOwnProfile) ...[
                const SizedBox(height: 16),
                const Text('XP Activity', style: TextStyle(color: Color(0xFF17213D), fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7EBF4))),
                  child: Column(
                    children: [
                      if (signupAwarded) _activityRow(icon: Icons.person_add_alt_1, color: const Color(0xFF21C5AE), title: 'First-time Signup Bonus', subtitle: 'Account created', amount: '+20 XP'),
                      if (usage > 0) _activityRow(icon: Icons.access_time_rounded, color: Colors.orange, title: 'Weekly Active Usage', subtitle: '${(usage / 3600).toStringAsFixed(1)} hours this week', amount: '+2 XP'),
                      if (ads > 0) _activityRow(icon: Icons.play_circle_fill_rounded, color: Colors.pink, title: 'Ad Rewards', subtitle: '$ads ads watched this week', amount: '+$ads XP'),
                      if (!signupAwarded && usage == 0 && ads == 0) const Padding(padding: EdgeInsets.all(16), child: Text('No XP activity yet', style: TextStyle(color: Color(0xFF8495B2), fontSize: 12))),
                    ],
                  ),
                ),
              ],
              if (!_isOwnProfile) ...[
                const SizedBox(height: 16),
                const Text('XP History', style: TextStyle(color: Color(0xFF17213D), fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7EBF4))),
                  child: _activityRow(icon: Icons.auto_awesome, color: const Color(0xFF6557E8), title: 'Total XP earned', subtitle: 'Current public XP', amount: '$xp XP'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
