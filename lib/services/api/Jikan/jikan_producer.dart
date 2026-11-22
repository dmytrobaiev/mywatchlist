import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class Producer {
  final int? malId;
  final String? url;
  final List<Title>? titles;
  final Images? images;
  final int? favorites;
  final int? count;
  final String? established;
  final String? about;

  Producer({
    this.malId,
    this.url,
    this.titles,
    this.images,
    this.favorites,
    this.count,
    this.established,
    this.about,
  });

  factory Producer.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    List<Title>? titles;
    if (json['titles'] is List) {
      titles = (json['titles'] as List)
          .whereType<Map>()
          .map((e) => Title.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (json['name'] is String) {
      titles = [Title(type: 'Default', title: json['name'] as String)];
    }
    return Producer(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      titles: titles,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      favorites: jikanInt(json['favorites']),
      count: jikanInt(json['count']),
      established: json['established'] as String?,
      about: json['about'] as String?,
    );
  }
}

class Title {
  final String? type;
  final String? title;

  Title({this.type, this.title});

  factory Title.fromJson(Map<String, dynamic> json) {
    return Title(
      type: json['type'] as String?,
      title: json['title'] as String?,
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

class ProducersResponse {
  final List<Producer> data;
  final Pagination pagination;

  ProducersResponse({
    required this.data,
    required this.pagination,
  });

  factory ProducersResponse.fromJson(Map<String, dynamic> json) {
    return ProducersResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Producer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: Pagination.fromJson(jikanPagination(json)),
    );
  }
}
