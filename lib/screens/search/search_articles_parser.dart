import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mwl_commons/mwl_commons.dart' show Paging;
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';

/// Reads the latest articles from MyAnimeList's own `/news` and `/featured` pages.
///
/// Handles both MAL's `.box-unit3` markup and desktop `.news-unit` markup inside the
/// first `.news-list` (subsequent lists repeat the same articles grouped by tag).
AnimeNewsOrFeaturedResult parseLatestArticles(String body) {
  final document = html_parser.parse(body);
  final list = document.querySelector('.news-list');
  final items = <AnimeNewsOrFeaturedItem>[];
  final seen = <int>{};

  for (final unit in list?.querySelectorAll('.box-unit3') ?? const <Element>[]) {
    final url = unit.querySelector('a.box-unit3-btn')?.attributes['href']?.trim() ?? '';
    final id = int.tryParse(RegExp(r'/(?:news|featured)/(\d+)').firstMatch(url)?.group(1) ?? '');
    final title = unit.querySelector('.title')?.text.trim() ?? '';
    if (id == null || title.isEmpty || !seen.add(id)) continue;
    final image = unit.querySelector('img');
    items.add(AnimeNewsOrFeaturedItem(
      id: id,
      title: title,
      text: _squash(unit.querySelector('.update')?.text ?? ''),
      tags: unit.querySelectorAll('.tags .tag').map((e) => e.text.trim()).join(', '),
      imageUrl: image?.attributes['data-src'] ?? image?.attributes['src'] ?? '',
      url: url,
    ));
  }

  if (items.isEmpty) {
    final units = list?.querySelectorAll('.news-unit') ?? document.querySelectorAll('.news-unit');
    for (final unit in units) {
      final link = unit.querySelector('.title a') ?? unit.querySelector('a[href*="/news/"], a[href*="/featured/"]');
      final url = link?.attributes['href']?.trim() ?? '';
      final id = int.tryParse(RegExp(r'/(?:news|featured)/(\d+)').firstMatch(url)?.group(1) ?? '');
      final title = link?.text.trim() ?? unit.querySelector('.title')?.text.trim() ?? '';
      if (id == null || title.isEmpty || !seen.add(id)) continue;
      final image = unit.querySelector('.image-link img') ?? unit.querySelector('img');
      var tagEls = unit.querySelectorAll('.information .tags a');
      if (tagEls.isEmpty) tagEls = unit.querySelectorAll('.information .tags .tag, .tags .tag');
      final text = _squash(
        unit.querySelector('.text')?.text ?? unit.querySelector('.information .info')?.text ?? '',
      );
      items.add(AnimeNewsOrFeaturedItem(
        id: id,
        title: title,
        text: text,
        tags: tagEls.map((e) => e.text.trim()).where((t) => t.isNotEmpty).join(', '),
        imageUrl: image?.attributes['data-src'] ?? image?.attributes['src'] ?? '',
        url: url,
      ));
    }
  }

  var next = document.querySelector('a.btn-next')?.attributes['href']?.trim();
  if (next == null || next.isEmpty) {
    final current = document.querySelector('.pagination.ac .link.current');
    next = current?.nextElementSibling?.attributes['href']?.trim();
  }
  return AnimeNewsOrFeaturedResult(
    newsorfeatured: items,
    paging: Paging(previous: '', next: next),
  );
}

String _squash(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
