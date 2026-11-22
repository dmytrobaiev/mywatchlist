import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeStaff {
  final Person person;
  final List<String>? positions;

  AnimeStaff({
    required this.person,
    this.positions,
  });

  factory AnimeStaff.fromJson(Map<String, dynamic> json) {
    final nestedPerson = jikanMap(json['person']);
    List<String>? positions;
    if (json['positions'] is List) {
      positions = (json['positions'] as List).map((e) => '$e').toList();
    } else if (json['role'] is String && (json['role'] as String).trim().isNotEmpty) {
      positions = (json['role'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return AnimeStaff(
      person: Person.fromJson(nestedPerson ?? json),
      positions: positions,
    );
  }
}

class Person {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;

  Person({
    this.malId,
    this.url,
    this.images,
    this.name,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    final id = jikanInt(json['malId'] ?? json['mal_id']);
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return Person(
      malId: id,
      url: json['url'] as String? ??
          (id != null ? 'https://myanimelist.net/people/$id' : null),
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      name: json['name'] as String?,
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
