import 'package:mywatchlist/enums.dart';

/// What a `#…` query asks for. Special queries are what the "Anime / Manga categories" chips, the
/// season picker and the home sections type into the search field.
sealed class SpecialQuery {
  const SpecialQuery();

  /// Parses [raw] (the text after the `#`), or null when it is not a special query:
  /// - `airing`, `bypopularity`, `all`… an anime ranking;
  /// - `manga@manga`, `bypopularity@manga`… a manga ranking;
  /// - `winter@2025` a season (four-digit year);
  /// - `suggested@anime`, `suggested@manga` the user's suggestions.
  static SpecialQuery? parse(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;
    final animeRanking = _rankingByName(text);
    if (animeRanking != null) return RankingQuery(animeRanking, 'anime');

    final parts = text.split('@');
    if (parts.length != 2) return null;
    final head = parts[0];
    final tail = parts[1];

    final season = seasonMapInverse[head];
    if (season != null && tail.length == 4) {
      final year = int.tryParse(tail);
      if (year != null) return SeasonQuery(season, year);
    }
    if (head == 'suggested' && (tail == 'anime' || tail == 'manga')) {
      return SuggestedQuery(tail);
    }
    if (tail == 'manga') {
      for (final entry in mangaRankingMap.entries) {
        if (entry.value == head) return MangaRankingQuery(entry.key);
      }
    }
    return null;
  }

  static RankingType? _rankingByName(String name) {
    for (final entry in rankingMap.entries) {
      if (entry.value == name) return entry.key;
    }
    return null;
  }

  /// The query text for an anime ranking chip.
  static String animeRanking(RankingType type) => '#${rankingMap[type]}';

  /// The query text for a manga ranking chip.
  static String mangaRanking(MangaRanking type) => '#${mangaRankingMap[type]}@manga';

  static String season(SeasonType season, int year) => '#${seasonMap[season]}@$year';

  static String suggested(String category) => '#suggested@$category';

  /// Matching `#...` preset suggestions for [raw] (used when tag suggestions
  /// are enabled in Settings).
  static List<({String query, String label})> suggestions(String raw, [DateTime? now]) {
    final trimmed = raw.trim().toLowerCase();
    if (!trimmed.startsWith('#')) return const [];
    final needle = trimmed.substring(1);
    final year = (now ?? DateTime.now()).year;
    final all = <({String query, String label})>[
      (query: '#all', label: 'Top All Anime'),
      (query: '#airing', label: 'Top Airing Anime'),
      (query: '#upcoming', label: 'Top Upcoming Anime'),
      (query: '#tv', label: 'Top Anime TV Series'),
      (query: '#ova', label: 'Top Anime OVA Series'),
      (query: '#movie', label: 'Top Anime Movies'),
      (query: '#special', label: 'Top Anime Specials'),
      (query: '#bypopularity', label: 'Most Popular Anime'),
      (query: '#favorite', label: 'Most Favorited Anime'),
      (query: '#all@manga', label: 'Top All Manga'),
      (query: '#manga@manga', label: 'Top Manga'),
      (query: '#novels@manga', label: 'Top Novels'),
      (query: '#oneshots@manga', label: 'Top One-shots'),
      (query: '#doujin@manga', label: 'Top Doujinshi'),
      (query: '#manhwa@manga', label: 'Top Manhwa'),
      (query: '#manhua@manga', label: 'Top Manhua'),
      (query: '#bypopularity@manga', label: 'Most Popular Manga'),
      (query: '#favorite@manga', label: 'Most Favorited Manga'),
      (query: '#winter@$year', label: 'Winter $year Anime'),
      (query: '#spring@$year', label: 'Spring $year Anime'),
      (query: '#summer@$year', label: 'Summer $year Anime'),
      (query: '#fall@$year', label: 'Fall $year Anime'),
      (query: '#suggested@anime', label: 'Suggested Anime'),
      (query: '#suggested@manga', label: 'Suggested Manga'),
    ];
    if (needle.isEmpty) return all.take(10).toList();
    return [
      for (final item in all)
        if (item.query.substring(1).contains(needle) ||
            item.label.toLowerCase().contains(needle))
          item,
    ];
  }
}

class RankingQuery extends SpecialQuery {
  final RankingType type;
  final String category;
  const RankingQuery(this.type, this.category);
}

class MangaRankingQuery extends SpecialQuery {
  final MangaRanking type;
  const MangaRankingQuery(this.type);
}

class SeasonQuery extends SpecialQuery {
  final SeasonType season;
  final int year;
  const SeasonQuery(this.season, this.year);
}

class SuggestedQuery extends SpecialQuery {
  final String category;
  const SuggestedQuery(this.category);
}

/// A query made only of digits is a MyAnimeList id ("1" is Cowboy Bebop).
bool isIdQuery(String query) => RegExp(r'^\d{1,8}$').hasMatch(query.trim());

/// Whether [query] can be a MyAnimeList user name (2 to 16 letters, digits, `_` or `-`).
bool looksLikeUsername(String query) => RegExp(r'^[A-Za-z0-9_-]{2,16}$').hasMatch(query.trim());

/// First year the season picker offers.
const int firstSeasonYear = 1917;

/// Last year the season picker offers: next year, since MyAnimeList lists announced seasons.
int lastSeasonYear([DateTime? now]) => (now ?? DateTime.now()).year + 1;
