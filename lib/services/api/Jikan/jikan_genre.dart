import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class Genre {
  final int? malId;
  final String? name;
  final String? url;
  final int? count;

  Genre({
    this.malId,
    this.name,
    this.url,
    this.count,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      malId: jikanInt(json['malId'] ?? json['mal_id']),
      name: json['name'] as String?,
      url: json['url'] as String?,
      count: jikanInt(json['count']),
    );
  }
}

class GenreResponse {
  final List<Genre> data;

  GenreResponse({required this.data});

  factory GenreResponse.fromJson(Map<String, dynamic> json) {
    return GenreResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Genre.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
