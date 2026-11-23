import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

/// Order of the review list.
enum ReviewSort { helpful, newest, oldest, highest, lowest }

extension ReviewSortLabel on ReviewSort {
  String get label => switch (this) {
        ReviewSort.helpful => S.current.Helpful,
        ReviewSort.newest => S.current.Social_Reviews_Sort_Newest,
        ReviewSort.oldest => S.current.Social_Reviews_Sort_Oldest,
        ReviewSort.highest => S.current.Social_Reviews_Sort_Highest,
        ReviewSort.lowest => S.current.Social_Reviews_Sort_Lowest,
      };

  IconData get icon => switch (this) {
        ReviewSort.helpful || ReviewSort.newest || ReviewSort.highest => Icons.arrow_downward,
        ReviewSort.oldest || ReviewSort.lowest => Icons.arrow_upward,
      };
}

/// Number of reviews per score (reviews without a score are not counted).
Map<int, int> reviewScoreDistribution(Iterable<AnimeReview> reviews) {
  final result = <int, int>{};
  for (final review in reviews) {
    final score = review.score;
    if (score == null || score <= 0) continue;
    result[score] = (result[score] ?? 0) + 1;
  }
  return result;
}

/// Normalizes scraped review tags so `Preliminary (6/28 eps)`, `Preliminary (12/28 eps)`,
/// etc. group into a single `Preliminary` filter chip while cards keep their exact text.
String normalizeReviewTag(String tag) {
  final trimmed = tag.trim();
  if (trimmed.toLowerCase().startsWith('preliminary')) return 'Preliminary';
  return trimmed;
}

/// Every normalized tag used by [reviews], in order of first appearance.
List<String> reviewTags(Iterable<AnimeReview> reviews) {
  final tags = <String>{};
  for (final review in reviews) {
    final own = review.tags;
    if (own != null) {
      for (final tag in own) {
        final normalized = normalizeReviewTag(tag);
        if (normalized.isNotEmpty) tags.add(normalized);
      }
    }
  }
  return tags.toList();
}

/// Parses a review date from either ISO-8601 (`2024-03-24T...`) or MAL/jikan-edge
/// display format (`Mar 24, 2024`).
DateTime? parseReviewDate(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;
  try {
    return DateFormat('MMM d, yyyy', 'en_US').parseLoose(trimmed);
  } catch (_) {
    try {
      return DateFormat('MMMM d, yyyy', 'en_US').parseLoose(trimmed);
    } catch (_) {
      return null;
    }
  }
}

/// Reviews matching [score] and any of [tags] (both optional), sorted by [sort].
List<AnimeReview> filterReviews(
  List<AnimeReview> reviews, {
  ReviewSort sort = ReviewSort.newest,
  int? score,
  Set<String> tags = const {},
}) {
  final normalizedFilterTags = tags.map(normalizeReviewTag).toSet();
  final filtered = reviews.where((review) {
    if (score != null && review.score != score) return false;
    if (normalizedFilterTags.isNotEmpty) {
      final own = review.tags;
      if (own == null || !own.any((t) => normalizedFilterTags.contains(normalizeReviewTag(t)))) {
        return false;
      }
    }
    return true;
  }).toList();

  final indexed = [for (var i = 0; i < filtered.length; i++) (i, filtered[i])];
  switch (sort) {
    case ReviewSort.helpful:
      indexed.sort((a, b) {
        final byReactions = (b.$2.reactions?.overall ?? 0).compareTo(a.$2.reactions?.overall ?? 0);
        return byReactions != 0 ? byReactions : a.$1.compareTo(b.$1);
      });
    case ReviewSort.newest:
      indexed.sort((a, b) {
        final da = parseReviewDate(a.$2.date);
        final db = parseReviewDate(b.$2.date);
        if (da != null && db != null) {
          final cmp = db.compareTo(da);
          if (cmp != 0) return cmp;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        final idCmp = (b.$2.malId ?? 0).compareTo(a.$2.malId ?? 0);
        return idCmp != 0 ? idCmp : a.$1.compareTo(b.$1);
      });
    case ReviewSort.oldest:
      indexed.sort((a, b) {
        final da = parseReviewDate(a.$2.date);
        final db = parseReviewDate(b.$2.date);
        if (da != null && db != null) {
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        final idCmp = (a.$2.malId ?? 0).compareTo(b.$2.malId ?? 0);
        return idCmp != 0 ? idCmp : a.$1.compareTo(b.$1);
      });
    case ReviewSort.highest:
      indexed.sort((a, b) {
        final sa = a.$2.score;
        final sb = b.$2.score;
        if (sa != null && sb != null) {
          final cmp = sb.compareTo(sa);
          if (cmp != 0) return cmp;
        } else if (sa != null) {
          return -1;
        } else if (sb != null) {
          return 1;
        }
        return a.$1.compareTo(b.$1);
      });
    case ReviewSort.lowest:
      indexed.sort((a, b) {
        final sa = a.$2.score;
        final sb = b.$2.score;
        if (sa != null && sb != null) {
          final cmp = sa.compareTo(sb);
          if (cmp != 0) return cmp;
        } else if (sa != null) {
          return -1;
        } else if (sb != null) {
          return 1;
        }
        return a.$1.compareTo(b.$1);
      });
  }
  return [for (final entry in indexed) entry.$2];
}

/// Texts sent to the summary service: non-empty, at most [maxReviews] reviews of at most
/// [maxChars] characters each, so the request stays small whatever was loaded.
List<String> reviewTextsForSummary(
  Iterable<AnimeReview> reviews, {
  int maxReviews = 12,
  int maxChars = 1500,
}) {
  final texts = <String>[];
  for (final review in reviews) {
    final text = review.review?.trim() ?? '';
    if (text.isEmpty) continue;
    texts.add(text.length > maxChars ? text.substring(0, maxChars) : text);
    if (texts.length >= maxReviews) break;
  }
  return texts;
}

/// "Jan 5, 2024" in [locale]; the raw string when the date cannot be formatted.
String formatReviewDate(String? iso, String locale) {
  final date = parseReviewDate(iso);
  if (date == null) return '';
  try {
    return DateFormat.yMMMd(locale).format(date);
  } catch (_) {
    return date.toIso8601String().substring(0, 10);
  }
}

/// The fields offered by the share builder for [review]: link, reviewer, score, text.
List<ShareField> reviewShareFields(AnimeReview review) {
  final url = review.url;
  final user = review.user?.username;
  final score = review.score;
  final text = review.review?.trim();
  return [
    if (url != null && url.isNotEmpty) ShareField(label: S.current.Url, value: url, labelled: false),
    if (user != null && user.isNotEmpty) ShareField(label: S.current.Social_Review_Reviewer, value: user),
    if (score != null && score > 0) ShareField(label: S.current.Score, value: '$score/10'),
    if (text != null && text.isNotEmpty)
      ShareField(label: S.current.Social_Review_Text, value: text, selected: url == null || url.isEmpty),
  ];
}

/// The AI verdict of a set of reviews: [verdict] plus short pros and cons.
class ReviewSummary {
  final String verdict;
  final List<SummaryPoint> pros;
  final List<SummaryPoint> cons;

  const ReviewSummary({required this.verdict, this.pros = const [], this.cons = const []});

  /// Reads the service answer (`{verdict, pros, cons}`, also tolerated inside a `data`
  /// object). Null when there is no verdict to show.
  static ReviewSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final root = json['data'] is Map ? json['data'] as Map : json;
    final verdict = root['verdict'];
    if (verdict is! String || verdict.trim().isEmpty) return null;
    return ReviewSummary(
      verdict: verdict.trim(),
      pros: _points(root['pros']),
      cons: _points(root['cons']),
    );
  }

  static List<SummaryPoint> _points(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['title'] is String && (item['title'] as String).trim().isNotEmpty)
          SummaryPoint(
            title: (item['title'] as String).trim(),
            description: (item['description'] as String?)?.trim() ?? '',
          ),
    ];
  }
}

class SummaryPoint {
  final String title;
  final String description;

  const SummaryPoint({required this.title, required this.description});
}
