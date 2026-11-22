import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class JikanAnime {
  final int? malId;
  final String? url;
  final Images? images;
  final Trailer? trailer;
  final bool? approved;
  final List<Title>? titles;
  final String? title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String>? titleSynonyms;
  final String? type;
  final String? source;
  final int? episodes;
  final int? volumes;
  final int? chapters;
  final String? status;
  final bool? airing;
  final Aired? aired;
  final String? duration;
  final String? rating;
  final double? score;
  final int? scoredBy;
  final int? rank;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? synopsis;
  final String? background;
  final String? season;
  final int? year;
  final Broadcast? broadcast;
  final List<Producer>? producers;
  final List<Producer>? licensors;
  final List<Producer>? studios;
  final List<Producer>? authors;
  final List<Producer>? serializations;
  final List<Genre>? genres;
  final List<Genre>? explicitGenres;
  final List<Genre>? themes;
  final List<Genre>? demographics;
  final List<Relation>? relations;
  final Theme? theme;
  final List<External>? external;
  final List<Streaming>? streaming;

  JikanAnime({
    this.malId,
    this.url,
    this.images,
    this.trailer,
    this.approved,
    this.titles,
    this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.titleSynonyms,
    this.type,
    this.source,
    this.episodes,
    this.volumes,
    this.chapters,
    this.status,
    this.airing,
    this.aired,
    this.duration,
    this.rating,
    this.score,
    this.scoredBy,
    this.rank,
    this.popularity,
    this.members,
    this.favorites,
    this.synopsis,
    this.background,
    this.season,
    this.year,
    this.broadcast,
    this.producers,
    this.licensors,
    this.studios,
    this.authors,
    this.serializations,
    this.genres,
    this.explicitGenres,
    this.themes,
    this.demographics,
    this.relations,
    this.theme,
    this.external,
    this.streaming,
  });

  factory JikanAnime.fromJson(Map<String, dynamic> json) {
    final imagesRaw = json['images'];
    final imageUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    final Images? images = (imagesRaw != null || imageUrl != null)
        ? Images.fromAny(imagesRaw, fallbackImageUrl: imageUrl)
        : null;

    final airedRaw = jikanMap(json['aired'] ?? json['published']);
    final Aired? aired = airedRaw != null
        ? Aired.fromJson(airedRaw)
        : (json['startDate'] != null || json['endDate'] != null)
            ? Aired(
                from: json['startDate'] as String?,
                to: json['endDate'] as String?,
              )
            : null;

    final rawSerials = json['serializations'] ?? json['serialization'];
    List<Producer>? serializations;
    if (rawSerials is List) {
      serializations = rawSerials
          .whereType<Map>()
          .map((e) => Producer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (rawSerials is Map) {
      serializations = [Producer.fromJson(Map<String, dynamic>.from(rawSerials))];
    }

    final rawSynonyms = json['titleSynonyms'] ?? json['title_synonyms'];
    final rawExplicit = json['explicitGenres'] ?? json['explicit_genres'];
    final rawExternal = json['externalLinks'] ?? json['external'];
    final rawTheme = jikanMap(json['themeSongs'] ?? json['theme']);

    return JikanAnime(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      url: json['url'] as String?,
      images: images,
      trailer: jikanMap(json['trailer']) != null
          ? Trailer.fromJson(jikanMap(json['trailer'])!)
          : null,
      approved: json['approved'] as bool?,
      titles: json['titles'] is List
          ? (json['titles'] as List)
              .whereType<Map>()
              .map((e) => Title.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      title: json['title'] as String?,
      titleEnglish: (json['titleEnglish'] ?? json['title_english']) as String?,
      titleJapanese: (json['titleJapanese'] ?? json['title_japanese']) as String?,
      titleSynonyms: rawSynonyms is List ? rawSynonyms.map((e) => '$e').toList() : null,
      type: json['type'] as String?,
      source: json['source'] as String?,
      episodes: jikanInt(json['episodes']),
      volumes: jikanInt(json['volumes']),
      chapters: jikanInt(json['chapters']),
      status: json['status'] as String?,
      airing: (json['airing'] ?? json['publishing']) as bool?,
      aired: aired,
      duration: json['duration'] as String?,
      rating: json['rating'] as String?,
      score: jikanDouble(json['score']),
      scoredBy: jikanInt(json['scoredBy'] ?? json['scored_by']),
      rank: jikanInt(json['rank']),
      popularity: jikanInt(json['popularity']),
      members: jikanInt(json['members']),
      favorites: jikanInt(json['favorites']),
      synopsis: json['synopsis'] as String?,
      background: json['background'] as String?,
      season: json['season'] as String?,
      year: jikanInt(json['year']),
      broadcast: jikanMap(json['broadcast']) != null
          ? Broadcast.fromJson(jikanMap(json['broadcast'])!)
          : null,
      producers: _parseProducers(json['producers']),
      licensors: _parseProducers(json['licensors']),
      studios: _parseProducers(json['studios']),
      authors: _parseProducers(json['authors']),
      serializations: serializations,
      genres: _parseGenres(json['genres']),
      explicitGenres: _parseGenres(rawExplicit),
      themes: _parseGenres(json['themes']),
      demographics: _parseGenres(json['demographics']),
      relations: json['relations'] is List
          ? (json['relations'] as List)
              .whereType<Map>()
              .map((e) => Relation.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      theme: rawTheme != null ? Theme.fromJson(rawTheme) : null,
      external: rawExternal is List
          ? rawExternal
              .whereType<Map>()
              .map((e) => External.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      streaming: json['streaming'] is List
          ? (json['streaming'] as List)
              .whereType<Map>()
              .map((e) => Streaming.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
    );
  }

  static List<Producer>? _parseProducers(Object? raw) {
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => Producer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<Genre>? _parseGenres(Object? raw) {
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => Genre.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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

class Trailer {
  final String? youtubeId;
  final String? url;
  final String? embedUrl;

  Trailer({this.youtubeId, this.url, this.embedUrl});

  factory Trailer.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    final embedUrl = (json['embedUrl'] ?? json['embed_url']) as String?;
    return Trailer(
      youtubeId: (json['youtubeId'] ?? json['youtube_id']) as String? ??
          jikanYoutubeId(embedUrl ?? url),
      url: url,
      embedUrl: embedUrl,
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

class Aired {
  final String? from;
  final String? to;
  final String? string;
  final Prop? prop;

  Aired({this.from, this.to, this.string, this.prop});

  factory Aired.fromJson(Map<String, dynamic> json) {
    return Aired(
      from: json['from'] as String?,
      to: json['to'] as String?,
      string: json['string'] as String?,
      prop: jikanMap(json['prop']) != null ? Prop.fromJson(jikanMap(json['prop'])!) : null,
    );
  }
}

class Prop {
  final Date? from;
  final Date? to;

  Prop({this.from, this.to});

  factory Prop.fromJson(Map<String, dynamic> json) {
    return Prop(
      from: jikanMap(json['from']) != null ? Date.fromJson(jikanMap(json['from'])!) : null,
      to: jikanMap(json['to']) != null ? Date.fromJson(jikanMap(json['to'])!) : null,
    );
  }
}

class Date {
  final int? day;
  final int? month;
  final int? year;

  Date({this.day, this.month, this.year});

  factory Date.fromJson(Map<String, dynamic> json) {
    return Date(
      day: jikanInt(json['day']),
      month: jikanInt(json['month']),
      year: jikanInt(json['year']),
    );
  }
}

class Broadcast {
  final String? day;
  final String? time;
  final String? timezone;
  final String? string;

  Broadcast({this.day, this.time, this.timezone, this.string});

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      day: json['day'] as String?,
      time: json['time'] as String?,
      timezone: json['timezone'] as String?,
      string: json['string'] as String?,
    );
  }
}

class Producer {
  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  Producer({this.malId, this.type, this.name, this.url});

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      type: json['type'] as String?,
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}

class Genre {
  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  Genre({this.malId, this.type, this.name, this.url});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      type: json['type'] as String?,
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}

class Relation {
  final String? relation;
  final List<Entry>? entry;

  Relation({this.relation, this.entry});

  factory Relation.fromJson(Map<String, dynamic> json) {
    List<Entry>? entries;
    if (json['entry'] is List) {
      entries = (json['entry'] as List)
          .whereType<Map>()
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (json['malId'] != null || json['mal_id'] != null) {
      entries = [Entry.fromJson(json)];
    }
    return Relation(
      relation: json['relation'] as String?,
      entry: entries,
    );
  }
}

class Entry {
  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  Entry({this.malId, this.type, this.name, this.url});

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      type: json['type'] as String?,
      name: (json['name'] ?? json['title']) as String?,
      url: json['url'] as String?,
    );
  }
}

class Theme {
  final List<String>? openings;
  final List<String>? endings;

  Theme({this.openings, this.endings});

  factory Theme.fromJson(Map<String, dynamic> json) {
    return Theme(
      openings: _parseSongs(json['openings']),
      endings: _parseSongs(json['endings']),
    );
  }

  static List<String>? _parseSongs(Object? raw) {
    if (raw is! List) return null;
    final out = <String>[];
    for (final item in raw) {
      if (item is String) {
        out.add(item);
      } else if (item is Map) {
        final title = item['title'] as String? ?? '';
        final artist = item['artist'] as String?;
        final episodes = item['episodes'] as String?;
        final parts = [
          if (title.isNotEmpty) '"$title"',
          if (artist != null && artist.isNotEmpty) 'by $artist',
          if (episodes != null && episodes.isNotEmpty) '($episodes)',
        ];
        if (parts.isNotEmpty) out.add(parts.join(' '));
      }
    }
    return out;
  }
}

class External {
  final String? name;
  final String? url;

  External({this.name, this.url});

  factory External.fromJson(Map<String, dynamic> json) {
    return External(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}

class Streaming {
  final String? name;
  final String? url;

  Streaming({this.name, this.url});

  factory Streaming.fromJson(Map<String, dynamic> json) {
    return Streaming(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}
