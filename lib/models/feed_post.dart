enum FeedPostType { image, reel }

class FeedPost {
  final String id;
  final String creatorId;
  final String creatorName;
  final String caption;
  final FeedPostType type;
  final List<String> topics;
  final int ageInHours;

  const FeedPost({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.caption,
    required this.type,
    required this.topics,
    required this.ageInHours,
  });
}

enum FeedAction {
  like,
  unlike,
  comment,
  share,
  save,
  unsave,
  rewatch,
  skip,
  notInterested,
}

class FeedPostBehavior {
  final String creatorId;
  final List<String> topics;
  final double watchCompletion;
  final int rewatchCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final int skipCount;
  final bool notInterested;
  final bool seen;

  const FeedPostBehavior({
    this.creatorId = '',
    this.topics = const [],
    this.watchCompletion = 0,
    this.rewatchCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.skipCount = 0,
    this.notInterested = false,
    this.seen = false,
  });

  factory FeedPostBehavior.fromJson(Map<String, dynamic> json) =>
      FeedPostBehavior(
        creatorId: (json['creatorId'] ?? '').toString(),
        topics: (json['topics'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        watchCompletion: (json['watchCompletion'] as num?)?.toDouble() ?? 0,
        rewatchCount: (json['rewatchCount'] as num?)?.toInt() ?? 0,
        likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
        saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
        skipCount: (json['skipCount'] as num?)?.toInt() ?? 0,
        notInterested: json['notInterested'] == true,
        seen: json['seen'] == true,
      );

  Map<String, Object> toJson() => {
    'creatorId': creatorId,
    'topics': topics,
    'watchCompletion': watchCompletion,
    'rewatchCount': rewatchCount,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'shareCount': shareCount,
    'saveCount': saveCount,
    'skipCount': skipCount,
    'notInterested': notInterested,
    'seen': seen,
  };

  FeedPostBehavior copyWith({
    String? creatorId,
    List<String>? topics,
    double? watchCompletion,
    int? rewatchCount,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? saveCount,
    int? skipCount,
    bool? notInterested,
    bool? seen,
  }) => FeedPostBehavior(
    creatorId: creatorId ?? this.creatorId,
    topics: topics ?? this.topics,
    watchCompletion: watchCompletion ?? this.watchCompletion,
    rewatchCount: rewatchCount ?? this.rewatchCount,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    shareCount: shareCount ?? this.shareCount,
    saveCount: saveCount ?? this.saveCount,
    skipCount: skipCount ?? this.skipCount,
    notInterested: notInterested ?? this.notInterested,
    seen: seen ?? this.seen,
  );
}
