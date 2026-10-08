import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_post.dart';
import '../repositories/mock_feed_repository.dart';

class FeedAlgorithmController {
  FeedAlgorithmController({
    required this.userId,
    MockFeedRepository repository = const MockFeedRepository(),
    Future<Set<String>> Function(String userId)? friendIdsLoader,
    SharedPreferences? preferences,
  }) : _repository = repository,
       _friendIdsLoader = friendIdsLoader ?? _emptyFriendIds,
       _preferences = preferences;

  final String userId;
  final MockFeedRepository _repository;
  final Future<Set<String>> Function(String userId) _friendIdsLoader;
  SharedPreferences? _preferences;
  final Map<String, FeedPostBehavior> _behaviors = {};
  Set<String> _friendIds = const {};
  String get _storageKey => 'feed_behavior_$userId';

  Map<String, FeedPostBehavior> get behaviors => Map.unmodifiable(_behaviors);
  Set<String> get friendIds => Set.unmodifiable(_friendIds);

  Future<List<FeedPost>> loadFeed() async {
    await _loadBehaviors();
    _friendIds = await _friendIdsLoader(userId);
    final candidates = await _repository.getCandidates();
    _candidateCache
      ..clear()
      ..addEntries(candidates.map((post) => MapEntry(post.id, post)));
    return rankPosts(candidates, friendIds: _friendIds, behaviors: _behaviors);
  }

  List<FeedPost> rankPosts(
    List<FeedPost> candidates, {
    required Set<String> friendIds,
    Map<String, FeedPostBehavior> behaviors = const {},
  }) {
    _candidateCache
      ..clear()
      ..addEntries(candidates.map((post) => MapEntry(post.id, post)));
    final eligible = candidates.where(
      (post) => !(behaviors[post.id]?.notInterested ?? false),
    );
    final ranked = eligible.toList()
      ..sort((first, second) {
        final firstRank = _priority(first, friendIds, behaviors);
        final secondRank = _priority(second, friendIds, behaviors);
        if (firstRank != secondRank) return firstRank.compareTo(secondRank);

        final firstScore = _score(first, behaviors);
        final secondScore = _score(second, behaviors);
        if (firstScore != secondScore) return secondScore.compareTo(firstScore);
        return first.ageInHours.compareTo(second.ageInHours);
      });
    return ranked;
  }

  Future<void> recordWatchProgress(
    String postId,
    double completion, {
    bool rewatched = false,
  }) async {
    final current = _behaviorForPost(postId);
    _behaviors[postId] = current.copyWith(
      watchCompletion: completion.clamp(0, 1).toDouble(),
      rewatchCount: current.rewatchCount + (rewatched ? 1 : 0),
      seen: true,
    );
    await _saveBehaviors();
  }

  Future<void> recordAction(String postId, FeedAction action) async {
    final current = _behaviorForPost(postId);
    _behaviors[postId] = switch (action) {
      FeedAction.like => current.copyWith(likeCount: 1, seen: true),
      FeedAction.unlike => current.copyWith(likeCount: 0, seen: true),
      FeedAction.comment => current.copyWith(
        commentCount: current.commentCount + 1,
        seen: true,
      ),
      FeedAction.share => current.copyWith(
        shareCount: current.shareCount + 1,
        seen: true,
      ),
      FeedAction.save => current.copyWith(saveCount: 1, seen: true),
      FeedAction.unsave => current.copyWith(saveCount: 0, seen: true),
      FeedAction.rewatch => current.copyWith(
        rewatchCount: current.rewatchCount + 1,
        seen: true,
      ),
      FeedAction.skip => current.copyWith(
        skipCount: current.skipCount + 1,
        seen: true,
      ),
      FeedAction.notInterested => current.copyWith(
        notInterested: true,
        seen: true,
      ),
    };
    await _saveBehaviors();
  }

  Future<void> recordImpression(String postId) async {
    final current = _behaviorForPost(postId);
    _behaviors[postId] = current.copyWith(seen: true);
    await _saveBehaviors();
  }

  FeedPostBehavior _behaviorForPost(String postId) {
    final behavior = _behaviors[postId] ?? const FeedPostBehavior();
    final post = _candidateCache[postId];
    if (post == null) return behavior;
    return behavior.copyWith(creatorId: post.creatorId, topics: post.topics);
  }

  int _priority(
    FeedPost post,
    Set<String> friendIds,
    Map<String, FeedPostBehavior> behaviors,
  ) {
    final isFriendPost = friendIds.contains(post.creatorId);
    final hasSeen = behaviors[post.id]?.seen ?? false;
    if (isFriendPost && !hasSeen) return 0;
    if (isFriendPost) return 1;
    if (!hasSeen) return 2;
    return 3;
  }

  double _score(FeedPost post, Map<String, FeedPostBehavior> behaviors) {
    var score = -post.ageInHours.toDouble();
    for (final entry in behaviors.entries) {
      final behavior = entry.value;
      if (behavior.notInterested) continue;
      if (behavior.creatorId == post.creatorId) score += 20;
      if (behavior.topics.any(post.topics.contains)) {
        score += 30 * behavior.watchCompletion;
        score += 35 * behavior.shareCount;
        score += 30 * behavior.saveCount;
        score += 25 * behavior.likeCount;
        score += 12 * behavior.commentCount;
        score += 10 * behavior.rewatchCount;
        score -= 25 * behavior.skipCount;
      }
    }
    return score;
  }

  final Map<String, FeedPost> _candidateCache = {};

  Future<void> _loadBehaviors() async {
    _preferences ??= await SharedPreferences.getInstance();
    final stored = _preferences!.getString(_storageKey);
    if (stored == null) return;

    final decoded = Map<String, dynamic>.from(jsonDecode(stored) as Map);
    for (final entry in decoded.entries) {
      if (entry.value is Map) {
        _behaviors[entry.key] = FeedPostBehavior.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
  }

  Future<void> _saveBehaviors() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(
      _storageKey,
      jsonEncode(_behaviors.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  static Future<Set<String>> _emptyFriendIds(String _) async => const {};
}
