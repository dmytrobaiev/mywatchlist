import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';

/// The pages of reviews of one title, for the detail section and the "view
/// all" screen.
///
/// Every page comes from MyAnimeList's own review pages, read through the
/// mwl-api `reviews` route ([JikanFallbacks.reviews]; the backend runs inside
/// the app when no remote server is set). Neither Jikan nor Tenrai is asked
/// (owner, 2026-11-20): Tenrai has no reviews, Jikan is often unreachable. A
/// failed next page keeps what is loaded and stops asking.
class ReviewsFeed extends ChangeNotifier {
  final int id;
  final String category;

  ReviewsFeed({required this.id, this.category = 'anime'});

  final List<AnimeReview> _reviews = [];
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;
  bool _everLoaded = false;
  int _page = 1;
  int _generation = 0;
  bool _disposed = false;
  ReviewSort _sort = ReviewSort.helpful;
  Set<String> _selectedTags = const {};
  Map<int, int> _distribution = const {};

  /// Loaded reviews, in server-returned order.
  List<AnimeReview> get reviews => List.unmodifiable(_reviews);
  bool get loading => _loading;

  /// The first page failed.
  bool get failed => _failed;
  bool get hasMore => _hasMore;
  bool get isEmpty => _reviews.isEmpty;
  bool get everLoaded => _everLoaded;
  ReviewSort get sort => _sort;
  Set<String> get selectedTags => _selectedTags;

  /// Number of loaded reviews per score.
  Map<int, int> get distribution => _distribution;

  /// Every MAL-supported server tag/flag for filtering.
  List<String> get tags => malReviewAllTags;

  /// Updates the server-side sort and MAL tag/flag filters, reloading from page 1.
  Future<void> setQuery({ReviewSort? sort, Set<String>? tags}) {
    final nextSort = sort ?? _sort;
    final nextTags = tags != null ? Set<String>.unmodifiable(tags) : _selectedTags;
    if (nextSort == _sort && setEquals(nextTags, _selectedTags)) {
      return Future<void>.value();
    }
    _sort = nextSort;
    _selectedTags = nextTags;
    return start(reset: true);
  }

  /// Loads the first page (or everything again with [reset]).
  Future<void> start({bool reset = false}) {
    if (reset) {
      _generation++;
      _reviews.clear();
      _page = 1;
      _hasMore = true;
      _loading = false;
      _failed = false;
      _distribution = const {};
    }
    return loadMore();
  }

  /// Loads the next page unless one is loading or none is left.
  Future<void> loadMore() async {
    if (_loading || !_hasMore || (_failed && _reviews.isNotEmpty)) return;
    final gen = _generation;
    _loading = true;
    _failed = false;
    _notify();
    try {
      final (page, hasMore) = await _fetchPage();
      if (_disposed || gen != _generation) return;
      _reviews.addAll(page);
      if (page.isNotEmpty) _everLoaded = true;
      _hasMore = hasMore && page.isNotEmpty;
      _page++;
      _distribution = reviewScoreDistribution(_reviews);
    } catch (e) {
      debugPrint('Reviews of $category $id, page $_page failed: $e');
      if (_disposed || gen != _generation) return;
      if (_reviews.isEmpty) {
        _failed = true;
      } else {
        _hasMore = false;
      }
    }
    _loading = false;
    _notify();
  }

  Future<(List<AnimeReview>, bool)> _fetchPage() => _mwlPage();

  Future<(List<AnimeReview>, bool)> _mwlPage() async {
    final tagParams = malReviewQueryForTags(_selectedTags);
    final list = await JikanFallbacks.reviewsQuery(
      id,
      category,
      _page,
      sort: _sort.malParam,
      filterCheck: tagParams.filterCheck,
      preliminary: tagParams.preliminary,
      spoiler: tagParams.spoiler,
    );
    return (list, list.isNotEmpty);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
