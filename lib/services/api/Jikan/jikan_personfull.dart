// ignore_for_file: library_private_types_in_public_api

import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class PersonFull {
  final int? malId;
  final String? url;
  final String? websiteUrl;
  final Images? images;
  final String? name;
  final String? givenName;
  final String? familyName;
  final List<String>? alternateNames;
  final String? birthday;
  final int? favorites;
  final String? about;
  final List<_AnimeStaff>? anime;
  final List<_MangaStaff>? manga;
  final List<_VoiceRole>? voices;

  PersonFull({
    this.malId,
    this.url,
    this.websiteUrl,
    this.images,
    this.name,
    this.givenName,
    this.familyName,
    this.alternateNames,
    this.birthday,
    this.favorites,
    this.about,
    this.anime,
    this.manga,
    this.voices,
  });

  factory PersonFull.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    final rawAlt = json['alternateNames'] ?? json['alternate_names'];
    return PersonFull(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      websiteUrl: (json['websiteUrl'] ?? json['website_url'] ?? json['website']) as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      name: json['name'] as String?,
      givenName: (json['givenName'] ?? json['given_name']) as String?,
      familyName: (json['familyName'] ?? json['family_name']) as String?,
      alternateNames: rawAlt is List ? rawAlt.map((e) => '$e').toList() : null,
      birthday: (json['birthday'] ?? json['birthDate']) as String?,
      favorites: jikanInt(json['favorites']),
      about: json['about'] as String?,
      anime: json['anime'] is List
          ? (json['anime'] as List)
              .whereType<Map>()
              .map((e) => _AnimeStaff.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      manga: json['manga'] is List
          ? (json['manga'] as List)
              .whereType<Map>()
              .map((e) => _MangaStaff.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      voices: json['voices'] is List
          ? (json['voices'] as List)
              .whereType<Map>()
              .map((e) => _VoiceRole.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
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

class _AnimeStaff {
  final String? position;
  final _Anime? anime;

  _AnimeStaff({this.position, this.anime});

  factory _AnimeStaff.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['anime']);
    String? pos = json['position'] as String?;
    if (pos == null && json['positions'] is List) {
      pos = (json['positions'] as List).join(', ');
    }
    final _Anime? anime = nested != null
        ? _Anime.fromJson(nested)
        : (json['animeId'] != null)
            ? _Anime(
                malId: jikanInt(json['animeId']),
                title: json['animeTitle'] as String?,
                images: json['imageUrl'] != null
                    ? Images.fromAny(null, fallbackImageUrl: json['imageUrl'] as String?)
                    : null,
              )
            : null;
    return _AnimeStaff(position: pos, anime: anime);
  }
}

class _MangaStaff {
  final String? position;
  final _Manga? manga;

  _MangaStaff({this.position, this.manga});

  factory _MangaStaff.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['manga']);
    String? pos = json['position'] as String?;
    if (pos == null && json['positions'] is List) {
      pos = (json['positions'] as List).join(', ');
    }
    final _Manga? manga = nested != null
        ? _Manga.fromJson(nested)
        : (json['mangaId'] != null)
            ? _Manga(
                malId: jikanInt(json['mangaId']),
                title: json['mangaTitle'] as String?,
                images: json['imageUrl'] != null
                    ? Images.fromAny(null, fallbackImageUrl: json['imageUrl'] as String?)
                    : null,
              )
            : null;
    return _MangaStaff(position: pos, manga: manga);
  }
}

class _VoiceRole {
  final String? role;
  final _Anime? anime;
  final _Character? character;

  _VoiceRole({this.role, this.anime, this.character});

  factory _VoiceRole.fromJson(Map<String, dynamic> json) {
    final nestedAnime = jikanMap(json['anime']);
    final nestedChar = jikanMap(json['character']);
    return _VoiceRole(
      role: (json['role'] ?? json['characterRole']) as String?,
      anime: nestedAnime != null
          ? _Anime.fromJson(nestedAnime)
          : (json['animeId'] != null)
              ? _Anime(
                  malId: jikanInt(json['animeId']),
                  title: json['animeTitle'] as String?,
                  images: json['animeImageUrl'] != null
                      ? Images.fromAny(null, fallbackImageUrl: json['animeImageUrl'] as String?)
                      : null,
                )
              : null,
      character: nestedChar != null
          ? _Character.fromJson(nestedChar)
          : (json['characterId'] != null)
              ? _Character(
                  malId: jikanInt(json['characterId']),
                  name: json['characterName'] as String?,
                  images: json['characterImageUrl'] != null
                      ? Images.fromAny(null, fallbackImageUrl: json['characterImageUrl'] as String?)
                      : null,
                )
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

class _Character {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;

  _Character({
    this.malId,
    this.url,
    this.images,
    this.name,
  });

  factory _Character.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return _Character(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      name: json['name'] as String?,
    );
  }
}
