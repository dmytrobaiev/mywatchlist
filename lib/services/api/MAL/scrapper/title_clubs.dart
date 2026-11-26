import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:mywatchlist/constants/constants.dart' show Constants;
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
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

/// In-memory cached club icon resolver for Anime/Manga Details club cards
/// (MAL's `/<category>/<id>/_/clubs` HTML omits club images).
///
/// Tries `jikan-edge` (`/v1/clubs/<id>`) first and falls back to
/// [MalClubsApi.getClubData], bounded to at most 3 concurrent lookups.
class ClubPictures extends ChangeNotifier {
  ClubPictures._();

  static final ClubPictures instance = ClubPictures._();

  static const int _maxConcurrent = 3;

  final Map<int, String?> _cache = {};
  final Set<int> _inFlight = {};
  final Queue<int> _queue = Queue<int>();
  int _active = 0;

  /// Optional test hook overriding the network lookup for a club id.
  @visibleForTesting
  Future<String?> Function(int clubId)? fetcher;

  /// Cached club picture URL, or null if unknown / not yet fetched.
  String? pictureOf(int clubId) => _cache[clubId];

  /// Schedules a fetch for [clubId] if not already cached or queued.
  void ensure(int clubId) {
    if (clubId <= 0 || _cache.containsKey(clubId) || _inFlight.contains(clubId)) {
      return;
    }
    _inFlight.add(clubId);
    _queue.add(clubId);
    _pump();
  }

  void _pump() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final id = _queue.removeFirst();
      _active++;
      unawaited(_loadOne(id));
    }
  }

  Future<void> _loadOne(int id) async {
    String? url;
    try {
      url = await (fetcher?.call(id) ?? _defaultFetch(id));
    } catch (_) {
      url = null;
    } finally {
      _active--;
      _inFlight.remove(id);
      _cache[id] = (url != null && url.isNotEmpty) ? url : null;
      notifyListeners();
      _pump();
    }
  }

  static Future<String?> _defaultFetch(int clubId) async {
    try {
      final res = await JikanClient.instance
          .get(Uri.parse('${Constants.jikanV4}/clubs/$clubId'));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jikanMap(jikanMap(json.decode(res.body))?['data']);
        final sizes = jikanImageSizes(data?['images'],
            fallbackImageUrl: jikanStr(data?['image_url'] ?? data?['imageUrl']));
        final url = sizes.medium ?? sizes.large ?? sizes.small;
        if (url != null && url.isNotEmpty) return url;
      }
    } catch (_) {}
    final page = await MalClubsApi().getClubData(clubId);
    final url = page?.details?.pictureUrl;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  @visibleForTesting
  void reset() {
    _cache.clear();
    _inFlight.clear();
    _queue.clear();
    _active = 0;
    fetcher = null;
  }
}
