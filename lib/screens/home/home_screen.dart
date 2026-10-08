import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/feed_algorithm_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../models/feed_post.dart';
import '../../services/friends_service.dart';
import '../../widgets/synora_identity_header.dart';
import '../notification/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const background = Color(0xFFF8FAFC);
  static const ink = Color(0xFF17213D);
  static const muted = Color(0xFF75819A);
  static const accent = Color(0xFF5A4BFF);

  late final NotificationController _notificationController;
  late final FeedAlgorithmController _feedController;
  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  late Future<List<FeedPost>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _notificationController = Get.put(NotificationController());
    _notificationController.initNotificationEngine(widget.userId);
    _feedController = FeedAlgorithmController(
      userId: widget.userId,
      friendIdsLoader: FriendsService().getAcceptedFriendIds,
    );
    _profileFuture = _loadProfile();
    _feedFuture = _feedController.loadFeed();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadProfile() =>
      FirebaseFirestore.instance.collection('users').doc(widget.userId).get();

  Future<void> _refresh() async {
    final profileFuture = _loadProfile();
    final feedFuture = _feedController.loadFeed();
    setState(() {
      _profileFuture = profileFuture;
      _feedFuture = feedFuture;
    });
    await Future.wait([profileFuture, feedFuture]);
  }

  Future<void> _recordAction(String postId, FeedAction action) async {
    try {
      await _feedController.recordAction(postId, action);
      if (mounted) setState(() => _feedFuture = _feedController.loadFeed());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save feed preference: $error')),
      );
    }
  }

  Future<void> _recordWatch(FeedPost post) async {
    try {
      final previous = _feedController.behaviors[post.id];
      if (post.type == FeedPostType.reel) {
        await _feedController.recordWatchProgress(
          post.id,
          1,
          rewatched: (previous?.watchCompletion ?? 0) > 0,
        );
      } else {
        await _feedController.recordImpression(post.id);
      }
      if (mounted) setState(() => _feedFuture = _feedController.loadFeed());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save watch progress: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: accent),
              );
            }
            if (snapshot.hasError ||
                snapshot.data == null ||
                !snapshot.data!.exists) {
              return _errorState(
                snapshot.error?.toString() ??
                    'Your profile is not available yet.',
              );
            }
            return RefreshIndicator(
              color: accent,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HomeHeaderDelegate(child: _buildHeader(context)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: SynoraOwnStoryCircle(userId: widget.userId),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                      child: Row(
                        children: [
                          Text(
                            'Your feed',
                            style: TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'DEMO PREVIEW',
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFeedSliver(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedSliver() {
    return FutureBuilder<List<FeedPost>>(
      future: _feedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: accent)),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your feed.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              ),
            ),
          );
        }
        final posts = snapshot.data ?? const <FeedPost>[];
        if (posts.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No posts yet. Your friends\' posts and recommendations will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 15),
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverList.separated(
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return FeedPostCard(
                post: post,
                behavior: _feedController.behaviors[post.id],
                isFriendPost: _feedController.friendIds.contains(
                  post.creatorId,
                ),
                onAction: (action) => _recordAction(post.id, action),
                onWatched: () => _recordWatch(post),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SynoraIdentityHeader(
      userId: widget.userId,
      trailing: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NotificationScreen(currentUserId: widget.userId),
              ),
            ),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: ink,
              size: 26,
            ),
          ),
          Obx(() {
            final count = _notificationController.unreadCount.value;
            if (count == 0) return const SizedBox.shrink();
            return Positioned(
              right: 4,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4842),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _errorState(String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        'Could not load Home.\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 15),
      ),
    ),
  );
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    required this.post,
    required this.behavior,
    required this.isFriendPost,
    required this.onAction,
    required this.onWatched,
    super.key,
  });

  final FeedPost post;
  final FeedPostBehavior? behavior;
  final bool isFriendPost;
  final ValueChanged<FeedAction> onAction;
  final VoidCallback onWatched;

  static const ink = Color(0xFF17213D);

  @override
  Widget build(BuildContext context) {
    final isLiked = (behavior?.likeCount ?? 0) > 0;
    final isSaved = (behavior?.saveCount ?? 0) > 0;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE8EDF5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE9EDFF),
              child: Text(
                post.creatorName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF5A4BFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              post.creatorName,
              style: const TextStyle(
                color: Color(0xFF17213D),
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${isFriendPost ? 'Friend' : 'Recommended'} · ${post.ageInHours}h ago',
              style: const TextStyle(color: Color(0xFF8495B2), fontSize: 12),
            ),
            trailing: IconButton(
              tooltip: 'Not interested',
              onPressed: () => onAction(FeedAction.notInterested),
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF8495B2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.caption,
              style: const TextStyle(color: Color(0xFF34415E), height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onWatched,
            child: Container(
              height: 250,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: post.type == FeedPostType.reel
                      ? const [Color(0xFF27264F), Color(0xFF6758FF)]
                      : const [Color(0xFFFFE6D8), Color(0xFFFFC7B7)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    post.type == FeedPostType.reel
                        ? Icons.play_circle_fill_rounded
                        : Icons.auto_awesome_rounded,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 60,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _PostTag(
                      label: post.type == FeedPostType.reel ? 'REEL' : 'POST',
                    ),
                  ),
                  if (post.type == FeedPostType.reel)
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: _PostTag(label: 'Tap to mark watched'),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _PostTag(label: post.topics.join(' · ')),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Like',
                  onPressed: () =>
                      onAction(isLiked ? FeedAction.unlike : FeedAction.like),
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border,
                    color: isLiked ? const Color(0xFFE84969) : ink,
                  ),
                ),
                IconButton(
                  tooltip: 'Comment',
                  onPressed: () => onAction(FeedAction.comment),
                  icon: const Icon(Icons.mode_comment_outlined, color: ink),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => onAction(FeedAction.share),
                  icon: const Icon(Icons.send_outlined, color: ink),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Save',
                  onPressed: () =>
                      onAction(isSaved ? FeedAction.unsave : FeedAction.save),
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Preview only · actions tune this demo feed',
              style: TextStyle(color: Color(0xFF8495B2), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTag extends StatelessWidget {
  const _PostTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.27),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _HomeHeaderDelegate({required this.child});

  @override
  double get minExtent => 70;

  @override
  double get maxExtent => 70;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}
