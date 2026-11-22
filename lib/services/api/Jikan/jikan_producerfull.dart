import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class ProducerFull {
  final int? malId;
  final String? url;
  final List<Title>? titles;
  final Images? images;
  final int? favorites;
  final int? count;
  final String? established;
  final String? about;
  final List<ExternalLink>? external;

  ProducerFull({
    this.malId,
    this.url,
    this.titles,
    this.images,
    this.favorites,
    this.count,
    this.established,
    this.about,
    this.external,
  });

  factory ProducerFull.fromJson(Map<String, dynamic> json) {
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
    return ProducerFull(
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
      external: json['external'] is List
          ? (json['external'] as List)
              .whereType<Map>()
              .map((e) => ExternalLink.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
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

class ExternalLink {
  final String? name;
  final String? url;

  ExternalLink({this.name, this.url});

  factory ExternalLink.fromJson(Map<String, dynamic> json) {
    return ExternalLink(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}
