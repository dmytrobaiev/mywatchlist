import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeReview {
  final User? user;
  final int? malId;
  final String? url;
  final String? type;
  final Reactions? reactions;
  final String? date;
  final String? review;
  final int? score;
  final List<String>? tags;
  final bool? isSpoiler;
  final bool? isPreliminary;
  final int? episodesWatched;

  AnimeReview({
    this.user,
    this.malId,
    this.url,
    this.type,
    this.reactions,
    this.date,
    this.review,
    this.score,
    this.tags,
    this.isSpoiler,
    this.isPreliminary,
    this.episodesWatched,
  });

  factory AnimeReview.fromJson(Map<String, dynamic> json) {
    final nestedUser = jikanMap(json['user']);
    final flatUsername = jikanStr(json['username']);
    final flatAvatar = jikanStr(json['imageUrl'] ?? json['image_url']);
    final User? user = nestedUser != null
        ? User.fromJson(nestedUser)
        : (flatUsername != null
            ? User(
                username: flatUsername,
                url: 'https://myanimelist.net/profile/${Uri.encodeComponent(flatUsername)}',
                images: flatAvatar != null
                    ? Images(jpg: ImageFormat(imageUrl: flatAvatar))
                    : null,
              )
            : null);

    final isSpoiler = (json['isSpoiler'] ?? json['is_spoiler']) as bool?;
    final isPreliminary = (json['isPreliminary'] ?? json['is_preliminary']) as bool?;

    List<String>? tags;
    if (json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => '$e').toList();
    } else {
      final tag = jikanStr(json['tag']);
      final built = <String>[
        if (tag != null) tag,
        if (isPreliminary == true && (tag == null || !tag.toLowerCase().contains('preliminary')))
          'Preliminary',
        if (isSpoiler == true && (tag == null || !tag.toLowerCase().contains('spoiler')))
          'Spoiler',
      ];
      if (built.isNotEmpty) tags = built;
    }

    return AnimeReview(
      user: user,
      malId: jikanInt(json['reviewId'] ?? json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      type: json['type'] as String?,
      reactions: jikanMap(json['reactions']) != null
          ? Reactions.fromJson(jikanMap(json['reactions'])!)
          : null,
      date: json['date'] as String?,
      review: (json['reviewText'] ?? json['review']) as String?,
      score: jikanInt(json['score']),
      tags: tags,
      isSpoiler: isSpoiler,
      isPreliminary: isPreliminary,
      episodesWatched: jikanInt(
        json['episodesWatched'] ??
            json['episodes_watched'] ??
            json['chaptersRead'] ??
            json['chapters_read'],
      ),
    );
  }
}

class User {
  final String? username;
  final String? url;
  final Images? images;

  User({
    this.username,
    this.url,
    this.images,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return User(
      username: json['username'] as String?,
      url: json['url'] as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
    );
  }
}

class Images {
  final ImageFormat? jpg;
  final ImageFormat? webp;

  Images({this.jpg, this.webp});

  factory Images.fromJson(Map<String, dynamic> json) => Images.fromAny(json);

  factory Images.fromAny(Object? raw, {String? fallbackImageUrl}) {
    final map = jikanMap(raw);
    if (map != null && (map['jpg'] != null || map['webp'] != null)) {
      return Images(
        jpg: jikanMap(map['jpg']) != null
            ? ImageFormat.fromJson(jikanMap(map['jpg'])!)
            : null,
        webp: jikanMap(map['webp']) != null
            ? ImageFormat.fromJson(jikanMap(map['webp'])!)
            : null,
      );
    }
    final sizes = jikanImageSizes(raw, fallbackImageUrl: fallbackImageUrl);
    final url = sizes.medium ?? sizes.large ?? sizes.small;
    return Images(jpg: url != null ? ImageFormat(imageUrl: url) : null);
  }
}

class ImageFormat {
  final String? imageUrl;

  ImageFormat({this.imageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: jikanStr(json['image_url'] ?? json['imageUrl'] ?? json['medium']),
    );
  }
}

class Reactions {
  final int? overall;
  final int? nice;
  final int? loveIt;
  final int? funny;
  final int? confusing;
  final int? informative;
  final int? wellWritten;
  final int? creative;

  Reactions({
    this.overall,
    this.nice,
    this.loveIt,
    this.funny,
    this.confusing,
    this.informative,
    this.wellWritten,
    this.creative,
  });

  factory Reactions.fromJson(Map<String, dynamic> json) {
    return Reactions(
      overall: jikanInt(json['overall']),
      nice: jikanInt(json['nice']),
      loveIt: jikanInt(json['loveIt'] ?? json['love_it']),
      funny: jikanInt(json['funny']),
      confusing: jikanInt(json['confusing']),
      informative: jikanInt(json['informative']),
      wellWritten: jikanInt(json['wellWritten'] ?? json['well_written']),
      creative: jikanInt(json['creative']),
    );
  }
}

class Pagination {
  final int? lastVisiblePage;
  final bool? hasNextPage;

  Pagination({
    this.lastVisiblePage,
    this.hasNextPage,
  });

  factory Pagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Pagination(hasNextPage: false);
    return Pagination(
      lastVisiblePage: jikanLastVisiblePage(json),
      hasNextPage: jikanHasNextPage(json),
    );
  }
}

class AnimeReviewsResponse {
  final List<AnimeReview> data;
  final Pagination pagination;

  AnimeReviewsResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeReviewsResponse.fromJson(Map<String, dynamic> json) {
    return AnimeReviewsResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AnimeReview.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: Pagination.fromJson(jikanPagination(json)),
    );
  }
}
