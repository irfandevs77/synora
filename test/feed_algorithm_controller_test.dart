import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synora/controllers/feed_algorithm_controller.dart';
import 'package:synora/models/feed_post.dart';
import 'package:synora/repositories/mock_feed_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const friendPost = FeedPost(
    id: 'friend-post',
    creatorId: 'friend',
    creatorName: 'Friend',
    caption: 'A friend post',
    type: FeedPostType.reel,
    topics: ['tech'],
    ageInHours: 4,
  );
  const recommendation = FeedPost(
    id: 'recommendation',
    creatorId: 'creator',
    creatorName: 'Creator',
    caption: 'A tech recommendation',
    type: FeedPostType.reel,
    topics: ['tech'],
    ageInHours: 1,
  );
  const unrelatedRecommendation = FeedPost(
    id: 'unrelated',
    creatorId: 'other',
    creatorName: 'Other',
    caption: 'An unrelated post',
    type: FeedPostType.image,
    topics: ['art'],
    ageInHours: 1,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('unseen friend posts rank before recommendations', () {
    final controller = FeedAlgorithmController(userId: 'user');

    final ranked = controller.rankPosts(
      [recommendation, friendPost],
      friendIds: {'friend'},
    );

    expect(ranked.map((post) => post.id), ['friend-post', 'recommendation']);
  });

  test(
    'all friend posts rank before recommendations, unseen friends first',
    () {
      const unseenFriendPost = FeedPost(
        id: 'unseen-friend-post',
        creatorId: 'another-friend',
        creatorName: 'Another Friend',
        caption: 'An unseen friend post',
        type: FeedPostType.image,
        topics: ['art'],
        ageInHours: 8,
      );
      final controller = FeedAlgorithmController(userId: 'user');

      final ranked = controller.rankPosts(
        [recommendation, friendPost, unseenFriendPost],
        friendIds: {'friend', 'another-friend'},
        behaviors: const {'friend-post': FeedPostBehavior(seen: true)},
      );

      expect(ranked.map((post) => post.id), [
        'unseen-friend-post',
        'friend-post',
        'recommendation',
      ]);
    },
  );

  test('loadFeed uses accepted friend IDs from its loader', () async {
    final controller = FeedAlgorithmController(
      userId: 'user',
      repository: _TestFeedRepository([recommendation, friendPost]),
      friendIdsLoader: (_) async => {'friend'},
    );

    final ranked = await controller.loadFeed();

    expect(ranked.map((post) => post.id), ['friend-post', 'recommendation']);
    expect(controller.friendIds, {'friend'});
  });

  test('watched topics raise similar recommendations after friends', () async {
    final controller = FeedAlgorithmController(userId: 'user');
    controller.rankPosts(
      [friendPost, recommendation, unrelatedRecommendation],
      friendIds: {'friend'},
    );
    await controller.recordWatchProgress(friendPost.id, 1);

    final ranked = controller.rankPosts(
      [unrelatedRecommendation, recommendation],
      friendIds: {'friend'},
      behaviors: controller.behaviors,
    );

    expect(ranked.map((post) => post.id), ['recommendation', 'unrelated']);
  });

  test('not interested removes a post from the ranked feed', () {
    final controller = FeedAlgorithmController(userId: 'user');

    final ranked = controller.rankPosts(
      [recommendation, unrelatedRecommendation],
      friendIds: const {},
      behaviors: const {
        'recommendation': FeedPostBehavior(notInterested: true),
      },
    );

    expect(ranked.map((post) => post.id), ['unrelated']);
  });

  test('interaction signals persist per account and can be toggled', () async {
    final controller = FeedAlgorithmController(userId: 'user');
    await controller.loadFeed();
    await controller.recordAction('recommended-reel-1', FeedAction.like);
    await controller.recordAction('recommended-reel-1', FeedAction.save);

    final reloaded = FeedAlgorithmController(userId: 'user');
    await reloaded.loadFeed();
    expect(reloaded.behaviors['recommended-reel-1']?.likeCount, 1);
    expect(reloaded.behaviors['recommended-reel-1']?.saveCount, 1);
    expect(reloaded.behaviors['recommended-reel-1']?.seen, isTrue);

    await reloaded.recordAction('recommended-reel-1', FeedAction.unlike);
    await reloaded.recordAction('recommended-reel-1', FeedAction.unsave);
    expect(reloaded.behaviors['recommended-reel-1']?.likeCount, 0);
    expect(reloaded.behaviors['recommended-reel-1']?.saveCount, 0);

    final otherAccount = FeedAlgorithmController(userId: 'other');
    await otherAccount.loadFeed();
    expect(otherAccount.behaviors['recommended-reel-1'], isNull);
  });
}

class _TestFeedRepository extends MockFeedRepository {
  _TestFeedRepository(this.posts);

  final List<FeedPost> posts;

  @override
  Future<List<FeedPost>> getCandidates() async => posts;
}
