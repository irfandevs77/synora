import '../models/feed_post.dart';

class MockFeedRepository {
  const MockFeedRepository();

  Future<List<FeedPost>> getCandidates() async => const [
    FeedPost(
      id: 'friend-reel-1',
      creatorId: 'friend_1',
      creatorName: 'Aarav',
      caption: 'A quick look at a tiny desk setup upgrade.',
      type: FeedPostType.reel,
      topics: ['tech', 'creativity'],
      ageInHours: 2,
    ),
    FeedPost(
      id: 'friend-image-1',
      creatorId: 'friend_2',
      creatorName: 'Mira',
      caption: 'A quiet evening and a little color study.',
      type: FeedPostType.image,
      topics: ['art', 'lifestyle'],
      ageInHours: 8,
    ),
    FeedPost(
      id: 'recommended-reel-1',
      creatorId: 'creator_1',
      creatorName: 'Dev Notes',
      caption: 'One small coding trick that saves time.',
      type: FeedPostType.reel,
      topics: ['tech', 'education'],
      ageInHours: 1,
    ),
    FeedPost(
      id: 'recommended-reel-2',
      creatorId: 'creator_2',
      creatorName: 'Daily Laughs',
      caption: 'When the weekend plan becomes a nap.',
      type: FeedPostType.reel,
      topics: ['comedy', 'lifestyle'],
      ageInHours: 4,
    ),
    FeedPost(
      id: 'recommended-image-1',
      creatorId: 'creator_3',
      creatorName: 'Frame by Frame',
      caption: 'Finding a new perspective in familiar places.',
      type: FeedPostType.image,
      topics: ['art', 'photography'],
      ageInHours: 12,
    ),
  ];
}
