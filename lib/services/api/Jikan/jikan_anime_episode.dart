import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeEpisode {
  final int? malId;
  final String? url;
  final String? title;
  final String? titleJapanese;
  final String? titleRomanji;
  final int? duration;
  final String? aired;
  final bool? filler;
  final bool? recap;
  final String? forumUrl;

  AnimeEpisode({
    this.malId,
    this.url,
    this.title,
    this.titleJapanese,
    this.titleRomanji,
    this.duration,
    this.aired,
    this.filler,
    this.recap,
    this.forumUrl,
  });

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    return AnimeEpisode(
      malId: jikanInt(json['malId'] ?? json['mal_id'] ?? json['number']),
      url: json['url'] as String?,
      title: json['title'] as String?,
      titleJapanese: (json['titleJapanese'] ?? json['title_japanese']) as String?,
      titleRomanji: (json['titleRomanji'] ?? json['title_romanji']) as String?,
      duration: jikanInt(json['duration']),
      aired: json['aired'] as String?,
      filler: json['filler'] as bool?,
      recap: json['recap'] as bool?,
      forumUrl: (json['forumUrl'] ?? json['forum_url']) as String?,
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

class AnimeEpisodesResponse {
  final List<AnimeEpisode> data;
  final Pagination pagination;

  AnimeEpisodesResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeEpisodesResponse.fromJson(Map<String, dynamic> json) {
    return AnimeEpisodesResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AnimeEpisode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: Pagination.fromJson(jikanPagination(json)),
    );
  }
}
