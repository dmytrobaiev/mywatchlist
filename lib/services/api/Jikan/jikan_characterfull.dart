// ignore_for_file: library_private_types_in_public_api

import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class CharacterFull {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;
  final String? nameKanji;
  final List<String>? nicknames;
  final int? favorites;
  final String? about;
  final List<Animeography>? anime;
  final List<Mangaography>? manga;
  final List<VoiceActor>? voices;

  CharacterFull({
    this.malId,
    this.url,
    this.images,
    this.name,
    this.nameKanji,
    this.nicknames,
    this.favorites,
    this.about,
    this.anime,
    this.manga,
    this.voices,
  });

  factory CharacterFull.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return CharacterFull(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      name: json['name'] as String?,
      nameKanji: (json['nameKanji'] ?? json['name_kanji']) as String?,
      nicknames: json['nicknames'] is List
          ? (json['nicknames'] as List).map((e) => '$e').toList()
          : null,
      favorites: jikanInt(json['favorites']),
      about: json['about'] as String?,
      anime: json['anime'] is List
          ? (json['anime'] as List)
              .whereType<Map>()
              .map((e) => Animeography.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      manga: json['manga'] is List
          ? (json['manga'] as List)
              .whereType<Map>()
              .map((e) => Mangaography.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      voices: json['voices'] is List
          ? (json['voices'] as List)
              .whereType<Map>()
              .map((e) => VoiceActor.fromJson(Map<String, dynamic>.from(e)))
              .toList()
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
    if (sizes.small == null && sizes.medium == null && sizes.large == null) {
      return Images();
    }
    return Images(
      jpg: ImageFormat(
        imageUrl: sizes.medium ?? sizes.large ?? sizes.small,
        smallImageUrl: sizes.small,
        largeImageUrl: sizes.large ?? sizes.medium,
      ),
    );
  }
}

class ImageFormat {
  final String? imageUrl;
  final String? smallImageUrl;
  final String? largeImageUrl;

  ImageFormat({this.imageUrl, this.smallImageUrl, this.largeImageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: jikanStr(json['image_url'] ?? json['imageUrl'] ?? json['medium']),
      smallImageUrl: jikanStr(json['small_image_url'] ?? json['smallImageUrl'] ?? json['small']),
      largeImageUrl: jikanStr(json['large_image_url'] ?? json['largeImageUrl'] ?? json['large']),
    );
  }
}

class Animeography {
  final String? role;
  final _Anime? anime;

  Animeography({this.role, this.anime});

  factory Animeography.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['anime']);
    return Animeography(
      role: json['role'] as String?,
      anime: nested != null
          ? _Anime.fromJson(nested)
          : (json['malId'] != null || json['mal_id'] != null)
              ? _Anime.fromJson(json)
              : null,
    );
  }
}

class Mangaography {
  final String? role;
  final _Manga? manga;

  Mangaography({this.role, this.manga});

  factory Mangaography.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['manga']);
    return Mangaography(
      role: json['role'] as String?,
      manga: nested != null
          ? _Manga.fromJson(nested)
          : (json['malId'] != null || json['mal_id'] != null)
              ? _Manga.fromJson(json)
              : null,
    );
  }
}

class _Anime {
  final int? malId;
  final String? url;
  final Images? images;
  final String? title;

  _Anime({
    this.malId,
    this.url,
    this.images,
    this.title,
  });

  factory _Anime.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return _Anime(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      title: json['title'] as String?,
    );
  }
}

class _Manga {
  final int? malId;
  final String? url;
  final Images? images;
  final String? title;

  _Manga({
    this.malId,
    this.url,
    this.images,
    this.title,
  });

  factory _Manga.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return _Manga(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      title: json['title'] as String?,
    );
  }
}

class VoiceActor {
  final String? language;
  final Person? person;

  VoiceActor({this.language, this.person});

  factory VoiceActor.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['person']);
    return VoiceActor(
      language: json['language'] as String?,
      person: nested != null
          ? Person.fromJson(nested)
          : (json['malId'] != null || json['mal_id'] != null)
              ? Person.fromJson(json)
              : null,
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
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return Person(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      name: json['name'] as String?,
    );
  }
}
