import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeNews {
  final int? malId;
  final String? url;
  final String? title;
  final String? date;
  final String? authorUsername;
  final String? authorUrl;
  final String? forumUrl;
  final Images? images;
  final int? comments;
  final String? excerpt;

  AnimeNews({
    this.malId,
    this.url,
    this.title,
    this.date,
    this.authorUsername,
    this.authorUrl,
    this.forumUrl,
    this.images,
    this.comments,
    this.excerpt,
  });

  factory AnimeNews.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return AnimeNews(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      title: json['title'] as String?,
      date: json['date'] as String?,
      authorUsername: (json['author'] ?? json['authorUsername'] ?? json['author_username']) as String?,
      authorUrl: (json['authorUrl'] ?? json['author_url']) as String?,
      forumUrl: (json['forumUrl'] ?? json['forum_url']) as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      comments: jikanInt(json['comments']),
      excerpt: json['excerpt'] as String?,
    );
  }
}

class Images {
  final ImageFormat? jpg;

  Images({this.jpg});

  factory Images.fromJson(Map<String, dynamic> json) => Images.fromAny(json);

  factory Images.fromAny(Object? raw, {String? fallbackImageUrl}) {
    final map = jikanMap(raw);
    if (map != null && map['jpg'] != null) {
      return Images(jpg: ImageFormat.fromJson(jikanMap(map['jpg'])!));
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

class AnimeNewsResponse {
  final List<AnimeNews> data;
  final Pagination pagination;

  AnimeNewsResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeNewsResponse.fromJson(Map<String, dynamic> json) {
    return AnimeNewsResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AnimeNews.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: Pagination.fromJson(jikanPagination(json)),
    );
  }
}
