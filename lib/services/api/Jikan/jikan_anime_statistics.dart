import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class AnimeStatistics {
  final int? watching;
  final int? completed;
  final int? onHold;
  final int? dropped;
  final int? planToWatch;
  final int? total;
  final List<ScoreStatistics>? scores;

  AnimeStatistics({
    this.watching,
    this.completed,
    this.onHold,
    this.dropped,
    this.planToWatch,
    this.total,
    this.scores,
  });

  factory AnimeStatistics.fromJson(Map<String, dynamic> json) {
    final status = jikanMap(json['status']) ?? json;
    return AnimeStatistics(
      watching: jikanInt(
        status['inProgress'] ?? status['watching'] ?? status['reading'],
      ),
      completed: jikanInt(status['completed']),
      onHold: jikanInt(status['onHold'] ?? status['on_hold']),
      dropped: jikanInt(status['dropped']),
      planToWatch: jikanInt(
        status['planned'] ?? status['plan_to_watch'] ?? status['plan_to_read'],
      ),
      total: jikanInt(status['total']),
      scores: json['scores'] is List
          ? (json['scores'] as List)
              .whereType<Map>()
              .map((e) => ScoreStatistics.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
    );
  }
}

class ScoreStatistics {
  final int? score;
  final int? votes;
  final double? percentage;

  ScoreStatistics({
    this.score,
    this.votes,
    this.percentage,
  });

  factory ScoreStatistics.fromJson(Map<String, dynamic> json) {
    return ScoreStatistics(
      score: jikanInt(json['score']),
      votes: jikanInt(json['votes']),
      percentage: jikanDouble(json['percentage']),
    );
  }
}
