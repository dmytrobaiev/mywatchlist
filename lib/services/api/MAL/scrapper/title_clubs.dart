import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';

/// The clubs related to a title: MAL's `/anime/<id>/_/clubs` and `/manga/<id>/_/clubs`
/// pages, which the official API and Jikan do not expose.
class TitleClubs {
  static const String _base = 'https://myanimelist.net';

  /// Page URL for [id] in [category] (`anime` or `manga`).
  static Uri url(int id, {String category = 'anime'}) =>
      Uri.parse('$_base/${category == 'manga' ? 'manga' : 'anime'}/$id/_/clubs');

  /// Fetches and parses the clubs of a title. Throws when MAL does not answer 200.
  static Future<List<ClubHtml>> fetch(
    int id, {
    String category = 'anime',
    Future<({int status, String body})> Function(Uri url)? get,
  }) async {
    final target = url(id, category: category);
    final response = get != null
        ? await get(target)
        : await MalConnect.retryGet(target.toString(), {})
            .then((r) => (status: r.statusCode, body: r.body));
    if (response.status != 200) {
      debugPrint('TitleClubs error: ${response.status} for $target');
      throw Exception('Failed to load clubs (${response.status})');
    }
    return parse(response.body);
  }

  /// Parses a clubs page: every `clubs.php?cid=` link with a name, once per club, in page
  /// order. Rows give the club image and description when the page has them.
  static List<ClubHtml> parse(String body) {
    final doc = Document.html(body);
    final seen = <int>{};
    final clubs = <ClubHtml>[];
    for (final link in doc.querySelectorAll('a[href*="clubs.php?cid="]')) {
      final id = int.tryParse(
          RegExp(r'cid=(\d+)').firstMatch(link.attributes['href'] ?? '')?.group(1) ?? '');
      final name = link.text.trim();
      if (id == null || name.isEmpty || !seen.add(id)) continue;
      final row = _row(link);
      final img = row?.querySelector('img');
      final imgUrl = img?.attributes['data-src'] ?? img?.attributes['src'];
      final members = RegExp(r'(\d[\d,]*)\s+members?', caseSensitive: false)
          .firstMatch(row?.text ?? '')
          ?.group(1);
      clubs.add(ClubHtml(
        id: id,
        name: name,
        imgUrl: (imgUrl == null || imgUrl.isEmpty) ? null : imgUrl,
        members: members,
      ));
    }
    return clubs;
  }

  /// Finds the individual club's container (`div.borderClass` on live MAL
  /// `/<category>/<id>/_/clubs` pages, or a `tr` that belongs to this single club).
  /// Never walks up to MAL's outer 2-column page layout `<tr>` (which contains
  /// multiple clubs and the title's cover image).
  static Element? _row(Element link) {
    for (Element? e = link.parent; e != null; e = e.parent) {
      if (e.localName == 'div' && e.classes.contains('borderClass')) {
        if (e.querySelectorAll('a[href*="clubs.php?cid="]').length == 1) {
          return e;
        }
      }
      if (e.localName == 'tr') {
        final links = e.querySelectorAll('a[href*="clubs.php?cid="]');
        final uniqueIds = {
          for (final l in links)
            RegExp(r'cid=(\d+)').firstMatch(l.attributes['href'] ?? '')?.group(1),
        }..remove(null);
        if (uniqueIds.length == 1) return e;
        return null;
      }
    }
    return null;
  }
}
