import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeVideos {
  final List<PromoVideo>? promo;
  final List<EpisodeVideo>? episodes;
  final List<MusicVideo>? musicVideos;

  AnimeVideos({
    this.promo,
    this.episodes,
    this.musicVideos,
  });

  factory AnimeVideos.fromJson(Map<String, dynamic> json) {
    final rawPromo = json['promos'] ?? json['promo'];
    final rawMusic = json['musicVideos'] ?? json['music_videos'];
    return AnimeVideos(
      promo: rawPromo is List
          ? rawPromo
              .whereType<Map>()
              .map((e) => PromoVideo.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      episodes: json['episodes'] is List
          ? (json['episodes'] as List)
              .whereType<Map>()
              .map((e) => EpisodeVideo.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      musicVideos: rawMusic is List
          ? rawMusic
              .whereType<Map>()
              .map((e) => MusicVideo.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
    );
  }
}

class PromoVideo {
  final String? title;
  final Trailer? trailer;

  PromoVideo({
    this.title,
    this.trailer,
  });

  factory PromoVideo.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['trailer']);
    final Trailer? trailer = nested != null
        ? Trailer.fromJson(nested)
        : (json['videoUrl'] != null || json['imageUrl'] != null)
            ? Trailer.fromFlat(
                videoUrl: json['videoUrl'] as String?,
                imageUrl: json['imageUrl'] as String?,
              )
            : null;
    return PromoVideo(
      title: json['title'] as String?,
      trailer: trailer,
    );
  }
}

class Trailer {
  final String? youtubeId;
  final String? url;
  final String? embedUrl;
  final TrailerImages? images;

  Trailer({
    this.youtubeId,
    this.url,
    this.embedUrl,
    this.images,
  });

  factory Trailer.fromFlat({String? videoUrl, String? imageUrl}) {
    final ytId = jikanYoutubeId(videoUrl);
    return Trailer(
      youtubeId: ytId,
      url: ytId != null ? 'https://www.youtube.com/watch?v=$ytId' : videoUrl,
      embedUrl: videoUrl,
      images: imageUrl != null
          ? TrailerImages(
              imageUrl: imageUrl,
              smallImageUrl: imageUrl,
              mediumImageUrl: imageUrl,
              largeImageUrl: imageUrl,
              maximumImageUrl: imageUrl,
            )
          : null,
    );
  }

  factory Trailer.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    final embedUrl = (json['embedUrl'] ?? json['embed_url']) as String?;
    return Trailer(
      youtubeId: (json['youtubeId'] ?? json['youtube_id']) as String? ??
          jikanYoutubeId(embedUrl ?? url),
      url: url,
      embedUrl: embedUrl,
      images: jikanMap(json['images']) != null
          ? TrailerImages.fromJson(jikanMap(json['images'])!)
          : null,
    );
  }
}

class TrailerImages {
  final String? imageUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;
  final String? maximumImageUrl;

  TrailerImages({
    this.imageUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
    this.maximumImageUrl,
  });

  factory TrailerImages.fromJson(Map<String, dynamic> json) {
    return TrailerImages(
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      smallImageUrl: (json['smallImageUrl'] ?? json['small_image_url']) as String?,
      mediumImageUrl: (json['mediumImageUrl'] ?? json['medium_image_url']) as String?,
      largeImageUrl: (json['largeImageUrl'] ?? json['large_image_url']) as String?,
      maximumImageUrl: (json['maximumImageUrl'] ?? json['maximum_image_url']) as String?,
    );
  }
}

class EpisodeVideo {
  final int? malId;
  final String? url;
  final String? title;
  final String? episode;
  final Images? images;

  EpisodeVideo({
    this.malId,
    this.url,
    this.title,
    this.episode,
    this.images,
  });

  factory EpisodeVideo.fromJson(Map<String, dynamic> json) {
    final imgUrl = jikanStr(json['imageUrl'] ?? json['image_url']);
    final rawEp = json['episode'];
    return EpisodeVideo(
      malId: jikanInt(json['malId'] ?? json['mal_id'] ?? rawEp),
      url: json['url'] as String?,
      title: json['title'] as String?,
      episode: rawEp == null ? null : (rawEp is int ? 'Episode $rawEp' : '$rawEp'),
      images: (json['images'] != null || imgUrl != null)
          ? Images.fromAny(json['images'], fallbackImageUrl: imgUrl)
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

class MusicVideo {
  final String? title;
  final Trailer? video;
  final Meta? meta;

  MusicVideo({
    this.title,
    this.video,
    this.meta,
  });

  factory MusicVideo.fromJson(Map<String, dynamic> json) {
    final nested = jikanMap(json['video']);
    final Trailer? video = nested != null
        ? Trailer.fromJson(nested)
        : (json['videoUrl'] != null || json['imageUrl'] != null)
            ? Trailer.fromFlat(
                videoUrl: json['videoUrl'] as String?,
                imageUrl: json['imageUrl'] as String?,
              )
            : null;
    return MusicVideo(
      title: json['title'] as String?,
      video: video,
      meta: jikanMap(json['meta']) != null ? Meta.fromJson(jikanMap(json['meta'])!) : null,
    );
  }
}

class Meta {
  final String? title;
  final String? author;

  Meta({
    this.title,
    this.author,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      title: json['title'] as String?,
      author: json['author'] as String?,
    );
  }
}
