import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeUserUpdate {
  final User? user;
  final int? score;
  final String? status;
  final int? episodesSeen;
  final int? episodesTotal;
  final int? volumesRead;
  final int? volumesTotal;
  final int? chaptersRead;
  final int? chaptersTotal;
  final String? date;

  AnimeUserUpdate({
    this.user,
    this.score,
    this.status,
    this.episodesSeen,
    this.episodesTotal,
    this.volumesRead,
    this.volumesTotal,
    this.chaptersRead,
    this.chaptersTotal,
    this.date,
  });

  factory AnimeUserUpdate.fromJson(Map<String, dynamic> json) {
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

    final progress = jikanInt(json['progress']);
    final total = jikanInt(json['total']);

    return AnimeUserUpdate(
      user: user,
      score: jikanInt(json['score']),
      status: json['status'] as String?,
      episodesSeen: jikanInt(json['episodesSeen'] ?? json['episodes_seen']) ?? progress,
      episodesTotal: jikanInt(json['episodesTotal'] ?? json['episodes_total']) ?? total,
      volumesRead: jikanInt(json['volumesRead'] ?? json['volumes_read']),
      volumesTotal: jikanInt(json['volumesTotal'] ?? json['volumes_total']),
      chaptersRead: jikanInt(json['chaptersRead'] ?? json['chapters_read']) ?? progress,
      chaptersTotal: jikanInt(json['chaptersTotal'] ?? json['chapters_total']) ?? total,
      date: json['date'] as String?,
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

class AnimeUserUpdatesResponse {
  final List<AnimeUserUpdate> data;
  final Pagination pagination;

  AnimeUserUpdatesResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeUserUpdatesResponse.fromJson(Map<String, dynamic> json) {
    return AnimeUserUpdatesResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AnimeUserUpdate.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: Pagination.fromJson(jikanPagination(json)),
    );
  }
}
