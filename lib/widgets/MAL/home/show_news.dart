import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Loads one page of news of a title; replaceable in tests.
typedef NewsPageLoader = Future<AnimeNewsResponse> Function(int id, String category, int page);

/// News about a title (Jikan `news`, raced against MyAnimeList's own news
/// page), as a horizontal list of cards that loads the next page near its
/// end. Always ends within about 12 s in content, an empty state or an error
/// with Retry: Jikan down or slow never leaves the skeleton on screen.
class ShowAnimeNews extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeNews({super.key, required this.animeId, this.category = "anime"});

  /// The source of the news pages (tests replace it with a fake).
  static NewsPageLoader loader = _defaultNews;

  /// Page 1 prefers MyAnimeList's own news page because it always includes
  /// publication dates, comment counts, and 2x thumbnails; falls back to Jikan
  /// if the direct page fails. Subsequent pages come from Jikan.
  static Future<AnimeNewsResponse> _defaultNews(int id, String category, int page) async {
    if (page > 1) return _jikanNews(id, category, page);
    try {
      final items = await JikanFallbacks.news(id, category).timeout(const Duration(seconds: 8));
      return AnimeNewsResponse(
        data: items,
        pagination: Pagination(hasNextPage: false),
      );
    } catch (_) {
      return _jikanNews(id, category, page);
    }
  }

  static Future<AnimeNewsResponse> _jikanNews(int id, String category, int page) =>
      JikanApi().getAnimeNews(id, page: page, category: category);

  /// Restores the default source (tests).
  static void resetLoader() => loader = _defaultNews;

  @override
  State<ShowAnimeNews> createState() => _ShowAnimeNewsState();
}

enum _NewsState { loading, ready, failed }

class _ShowAnimeNewsState extends State<ShowAnimeNews> with AutomaticKeepAliveClientMixin {
  static const double _height = 184;
  static const double _cardWidth = 340;
  static const double _loadMoreDistance = 200;

  final List<AnimeNews> _news = [];
  final ScrollController _scroll = ScrollController();
  _NewsState _state = _NewsState.loading;
  int _page = 1;
  bool _hasNextPage = true;
  bool _loadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasNextPage || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreDistance) _loadMore();
  }

  Future<void> _loadFirstPage() async {
    _news.clear();
    _page = 1;
    _hasNextPage = true;
    if (_state != _NewsState.loading) setState(() => _state = _NewsState.loading);
    try {
      final response = await ShowAnimeNews.loader(widget.animeId, widget.category, _page);
      if (!mounted) return;
      setState(() {
        _news.addAll(response.data);
        _page++;
        _hasNextPage = (response.pagination.hasNextPage ?? false) && response.data.isNotEmpty;
        _state = _NewsState.ready;
      });
    } catch (e) {
      debugPrint('News of ${widget.category} ${widget.animeId} failed: $e');
      if (!mounted) return;
      setState(() => _state = _NewsState.failed);
    }
  }

  /// The next page; a failure keeps what is shown and stops asking.
  Future<void> _loadMore() async {
    // A flag, not setState: the trailing loading card is already in the list.
    _loadingMore = true;
    try {
      final response = await ShowAnimeNews.loader(widget.animeId, widget.category, _page);
      if (!mounted) return;
      setState(() {
        _news.addAll(response.data);
        _page++;
        _hasNextPage = (response.pagination.hasNextPage ?? false) && response.data.isNotEmpty;
      });
    } catch (e) {
      debugPrint('News page $_page of ${widget.animeId} failed: $e');
      if (mounted) setState(() => _hasNextPage = false);
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    switch (_state) {
      case _NewsState.loading:
        return SizedBox(
          height: _height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 3,
            itemBuilder: (_, __) => const _NewsLoadingCard(width: _cardWidth),
          ),
        );
      case _NewsState.failed:
        return SectionMessage.error(message: S.current.Dp_News_Failed, onRetry: _loadFirstPage);
      case _NewsState.ready:
        if (_news.isEmpty) {
          return SectionMessage(icon: Icons.newspaper_outlined, message: S.current.Dp_News_Empty);
        }
        return SizedBox(
          height: _height,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemExtent: _cardWidth + 10,
            itemCount: _news.length + (_hasNextPage ? 1 : 0),
            itemBuilder: (context, index) => index < _news.length
                ? _NewsCard(news: _news[index], width: _cardWidth)
                : const _NewsLoadingCard(width: _cardWidth),
          ),
        );
    }
  }
}

class _NewsCard extends StatelessWidget {
  final AnimeNews news;
  final double width;

  const _NewsCard({required this.news, required this.width});

  String _date(BuildContext context) {
    final raw = news.date?.trim();
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    try {
      return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
    } catch (_) {
      return date.toIso8601String().substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = _date(context);
    final comments = news.comments ?? 0;
    final id = news.malId;
    return Card(
      margin: const EdgeInsetsDirectional.only(end: 10, bottom: 4, top: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: id == null
            ? null
            : () => gotoPage(
                  context: context,
                  newPage: FeaturedScreen(
                    id: id,
                    featureTitle: news.title,
                    imgUrl: news.images?.jpg?.imageUrl,
                    category: 'news',
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppImage(
                url: news.images?.jpg?.imageUrl,
                width: 105,
                height: 156,
                borderRadius: BorderRadius.circular(10),
                placeholderColor: scheme.surfaceContainerHighest,
                errorWidget: (_) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 28,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final style = theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35);
                          final lineHeight = (style?.fontSize ?? 12.0) *
                              (style?.height ?? 1.35) *
                              MediaQuery.textScalerOf(context).scale(1.0);
                          final maxLines = (constraints.maxHeight / lineHeight).floor().clamp(1, 10);
                          return Text(
                            news.excerpt ?? '',
                            maxLines: maxLines,
                            overflow: TextOverflow.ellipsis,
                            style: style,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            news.authorUsername ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 0,
                            child: Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                        if (comments > 0) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: S.current.Dp_News_Comments(comments),
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 12, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(
                                  NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
                                      .format(comments),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsLoadingCard extends StatelessWidget {
  final double width;

  const _NewsLoadingCard({required this.width});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The shimmer paints over the shapes; any opaque theme colour works.
    Widget bar({double? height, double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(4)),
        );
    return SizedBox(
      width: width,
      child: Card(
        margin: const EdgeInsetsDirectional.only(end: 10, bottom: 4, top: 4),
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ShimmerColor(
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 156,
                  width: 105,
                  decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(height: 14, width: double.infinity),
                      const SizedBox(height: 6),
                      bar(height: 14, width: 130),
                      const SizedBox(height: 10),
                      Expanded(child: bar()),
                      const SizedBox(height: 8),
                      bar(height: 11, width: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
