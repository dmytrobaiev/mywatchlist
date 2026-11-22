import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeCharacter {
  final Character character;
  final String? role;
  final int? favorites;
  final List<VoiceActor>? voiceActors;

  AnimeCharacter({
    required this.character,
    this.role,
    this.favorites,
    this.voiceActors,
  });

  factory AnimeCharacter.fromJson(Map<String, dynamic> json) {
    final nestedChar = jikanMap(json['character']);
    final rawVas = json['voiceActors'] ?? json['voice_actors'];
    return AnimeCharacter(
      character: Character.fromJson(nestedChar ?? json),
      role: json['role'] as String?,
      favorites: jikanInt(json['favorites']),
      voiceActors: rawVas is List
          ? rawVas
              .whereType<Map>()
              .map((e) => VoiceActor.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
    );
  }
}

class Character {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;

  Character({
    this.malId,
    this.url,
    this.images,
    this.name,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    final id = jikanInt(json['malId'] ?? json['mal_id']);
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    return Character(
      malId: id,
      url: json['url'] as String? ??
          (id != null ? 'https://myanimelist.net/character/$id' : null),
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
          : null,
      name: json['name'] as String?,
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
      ),
    );
  }
}

class ImageFormat {
  final String? imageUrl;
  final String? smallImageUrl;

  ImageFormat({this.imageUrl, this.smallImageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: jikanStr(json['image_url'] ?? json['imageUrl'] ?? json['medium']),
      smallImageUrl: jikanStr(json['small_image_url'] ?? json['smallImageUrl'] ?? json['small']),
    );
  }
}

class VoiceActor {
  final Person? person;
  final String? language;

  VoiceActor({
    this.person,
    this.language,
  });

  factory VoiceActor.fromJson(Map<String, dynamic> json) {
    final nestedPerson = jikanMap(json['person']);
    final Person? person = nestedPerson != null
        ? Person.fromJson(nestedPerson)
        : (json['malId'] != null || json['mal_id'] != null || json['name'] != null)
            ? Person.fromJson(json)
            : null;
    return VoiceActor(
      person: person,
      language: json['language'] as String?,
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
