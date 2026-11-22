import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeForum {
  final int? malId;
  final String? url;
  final String? title;
  final String? date;
  final String? authorUsername;
  final String? authorUrl;
  final int? comments;
  final LastComment? lastComment;

  AnimeForum({
    this.malId,
    this.url,
    this.title,
    this.date,
    this.authorUsername,
    this.authorUrl,
    this.comments,
    this.lastComment,
  });

  factory AnimeForum.fromJson(Map<String, dynamic> json) {
    final id = jikanInt(json['topicId'] ?? json['malId'] ?? json['mal_id']);
    final lastCommentMap = jikanMap(json['lastComment'] ?? json['last_comment']);
    final lastPostBy = jikanStr(json['lastPostBy']);
    final LastComment? lastComment = lastCommentMap != null
        ? LastComment.fromJson(lastCommentMap)
        : (lastPostBy != null ? LastComment(authorUsername: lastPostBy) : null);

    return AnimeForum(
      malId: id,
      url: json['url'] as String? ??
          (id != null ? 'https://myanimelist.net/forum/?topicid=$id' : null),
      title: json['title'] as String?,
      date: (json['startedDate'] ?? json['date']) as String?,
      authorUsername: (json['startedBy'] ?? json['authorUsername'] ?? json['author_username']) as String?,
      authorUrl: (json['authorUrl'] ?? json['author_url']) as String?,
      comments: jikanInt(json['replies'] ?? json['comments']),
      lastComment: lastComment,
    );
  }
}

class LastComment {
  final String? url;
  final String? authorUsername;
  final String? authorUrl;
  final String? date;

  LastComment({
    this.url,
    this.authorUsername,
    this.authorUrl,
    this.date,
  });

  factory LastComment.fromJson(Map<String, dynamic> json) {
    return LastComment(
      url: json['url'] as String?,
      authorUsername: (json['authorUsername'] ?? json['author_username']) as String?,
      authorUrl: (json['authorUrl'] ?? json['author_url']) as String?,
      date: json['date'] as String?,
    );
  }
}

class AnimeForumResponse {
  final List<AnimeForum> data;

  AnimeForumResponse({required this.data});

  factory AnimeForumResponse.fromJson(Map<String, dynamic> json) {
    return AnimeForumResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AnimeForum.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
