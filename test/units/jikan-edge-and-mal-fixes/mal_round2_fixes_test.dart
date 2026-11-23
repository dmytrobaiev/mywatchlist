import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/search/search_articles_parser.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/character_page.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/title_clubs.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  group('JikanClient UTF-8 decoding when charset is omitted', () {
    tearDown(() => JikanClient.instance.resetForTest());

    test('decodes em-dashes and Japanese kanji without mojibake', () async {
      final payload = jsonEncode({
        'data': {
          'name': 'Kitou, Akari',
          'nameKanji': '鬼頭 明里',
          'about': 'Three men—killers of her parents—were in her house.',
        },
      });
      final utf8Bytes = utf8.encode(payload);
      JikanClient.instance.resetForTest(
        client: MockClient((_) async => http.Response.bytes(
              utf8Bytes,
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      final res = await JikanClient.instance
          .get(Uri.parse('https://jikan.lucashdo.com/v1/people/49635/full'));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      expect(data['nameKanji'], '鬼頭 明里');
      expect(data['about'], contains('men—killers'));
      expect(data['about'], isNot(contains('â')));
    });
  });

  group('MalCharacterPage spoiler preservation', () {
    test('wraps div.spoiler blocks into [Spoiler]...[/Spoiler]', () {
      const html = '''
<html><head><meta property="og:title" content="Eren Yeager"></head>
<body><div id="content">
<h2 class="normal_header">Eren Yeager <small>(エレン・イェーガー)</small></h2>
Intro paragraph.<br><br>
<div class="spoiler">
  <input type="button" value="Show spoiler">
  <span class="spoiler_content">
    <input type="button" value="Hide spoiler">
    Grisha injected Eren with the titan serum.
  </span>
</div>
<div class="normal_header">Voice Actors</div>
</div></body></html>''';
      final parsed = parseMalCharacterPage(html);
      expect(parsed['name'], 'Eren Yeager');
      final about = parsed['about'] as String;
      expect(about, contains('Intro paragraph.'));
      expect(about, contains('[Spoiler]'));
      expect(about, contains('Grisha injected Eren with the titan serum.'));
      expect(about, contains('[/Spoiler]'));
      expect(about, isNot(contains('Show spoiler')));
      expect(about, isNot(contains('Hide spoiler')));
    });
  });

  group('Character/Person social handle linkification', () {
    test('links multi-handle X/Instagram lists and YouTube handles, strips dangling <div', () {
      const about = '''
X: @kitoakari_1016, @kitoakari_staff
Instagram: @akarikito1016,
@kitoakari_staff
YouTube: @KitoAkari_Official
<div''';
      final tokens = parseAboutLinks(about);
      final links = [for (final t in tokens) if (t.url != null) (t.text, t.url!)];
      expect(links, [
        ('@kitoakari_1016', 'https://x.com/kitoakari_1016'),
        ('@kitoakari_staff', 'https://x.com/kitoakari_staff'),
        ('@akarikito1016', 'https://www.instagram.com/akarikito1016'),
        ('@kitoakari_staff', 'https://www.instagram.com/kitoakari_staff'),
        ('@KitoAkari_Official', 'https://www.youtube.com/@KitoAkari_Official'),
      ]);
      expect(tokens.map((t) => t.text).join(), isNot(contains('<div')));
    });
  });

  group('DataSource label', () {
    test('uses Jikan Edge brand label', () {
      expect(DataSource.jikan.label, 'Jikan Edge');
      expect(DataSource.tenrai.label, 'Tenrai');
    });
  });

  group('SearchFilters.activeCount', () {
    test('counts orderBy + sort pair as 1 filter', () {
      final f = SearchFilters.forAnimeRanking(RankingType.ALL);
      expect(f.activeCount, 1);
    });
  });

  group('parseLatestArticles', () {
    test('parses desktop MAL .news-unit markup as well as .box-unit3', () {
      const desktopHtml = '''
<html><body>
<div class="news-list">
  <div class="news-unit">
    <a class="image-link" href="https://myanimelist.net/news/71234567">
      <img data-src="https://cdn.myanimelist.net/s/common/uploaded_files/thumb.jpg" />
    </a>
    <p class="title"><a href="https://myanimelist.net/news/71234567">Frieren Season 2 Announced</a></p>
    <div class="text">Madhouse returns for season 2.</div>
    <div class="information"><div class="tags"><a class="tag">Anime</a></div></div>
  </div>
</div>
<div class="pagination ac">
  <a class="link current" href="?p=1">1</a>
  <a class="link" href="?p=2">2</a>
</div>
</body></html>''';
      final result = parseLatestArticles(desktopHtml);
      expect(result.newsorfeatured, hasLength(1));
      expect(result.newsorfeatured.first.id, 71234567);
      expect(result.newsorfeatured.first.title, 'Frieren Season 2 Announced');
      expect(result.newsorfeatured.first.tags, 'Anime');
      expect(result.paging?.next, '?p=2');
    });
  });

  group('Review date parsing & sorting', () {
    test('sorts newest, oldest, helpful, highest, and lowest accurately', () {
      final r1 = AnimeReview(
        malId: 1,
        date: 'Mar 24, 2024',
        score: 4,
        reactions: Reactions(overall: 6000),
      );
      final r2 = AnimeReview(
        malId: 2,
        date: 'Oct 13, 2023',
        score: 10,
        reactions: Reactions(overall: 1400),
      );
      final r3 = AnimeReview(
        malId: 3,
        date: '2025-01-10T12:00:00+00:00',
        score: 8,
        reactions: Reactions(overall: 500),
      );
      final r4 = AnimeReview(
        malId: 4,
        date: 'Jan 05, 2024',
        score: null,
        reactions: Reactions(overall: 10),
      );
      final all = [r1, r2, r3, r4];

      expect(parseReviewDate('Mar 24, 2024'), DateTime(2024, 3, 24));
      expect(
        filterReviews(all, sort: ReviewSort.newest).map((r) => r.malId),
        [3, 1, 4, 2],
      );
      expect(
        filterReviews(all, sort: ReviewSort.oldest).map((r) => r.malId),
        [2, 4, 1, 3],
      );
      expect(
        filterReviews(all, sort: ReviewSort.helpful).map((r) => r.malId),
        [1, 2, 3, 4],
      );
      expect(
        filterReviews(all, sort: ReviewSort.highest).map((r) => r.malId),
        [2, 3, 1, 4],
      );
      expect(
        filterReviews(all, sort: ReviewSort.lowest).map((r) => r.malId),
        [1, 3, 2, 4],
      );
    });
  });

  group('TitleClubs.parse on live MAL div.borderClass layout', () {
    test('extracts distinct member counts and does not leak anime cover from outer tr', () {
      const html = '''
<html><body>
<table><tr>
  <td><div class="leftside"><img src="https://cdn.myanimelist.net/images/anime/frieren.jpg"></div></td>
  <td>
    <div class="borderClass"><a href="/clubs.php?cid=101">Anime Guild</a> <small>95 members</small></div>
    <div class="borderClass"><a href="/clubs.php?cid=202">Namine's Club</a> <small>1,420 members</small></div>
  </td>
</tr></table>
</body></html>''';
      final clubs = TitleClubs.parse(html);
      expect(clubs, hasLength(2));
      expect(clubs[0].id, 101);
      expect(clubs[0].members, '95');
      expect(clubs[0].imgUrl, isNull);
      expect(clubs[1].id, 202);
      expect(clubs[1].members, '1,420');
      expect(clubs[1].imgUrl, isNull);
    });
  });

  group('ProfileTabsSource jikan-edge parsers', () {
    test('parses jikan-edge /users/{u}/clubs and /users/{u}/friends', () {
      final clubs = ProfileTabsSource.parseJikanClubsJson(jsonEncode({
        'data': [
          {'malId': 123, 'name': 'Frieren Fans', 'url': 'https://myanimelist.net/clubs.php?cid=123'},
          {'malId': 123, 'name': 'Frieren Fans', 'url': 'https://myanimelist.net/clubs.php?cid=123'},
        ],
        'meta': {'cached': true},
      }));
      expect(clubs, hasLength(1));
      expect(clubs.first.id, 123);
      expect(clubs.first.name, 'Frieren Fans');

      final friends = ProfileTabsSource.parseJikanFriendsJson(jsonEncode({
        'data': [
          {
            'username': 'Himmel',
            'imageUrl': 'https://cdn.myanimelist.net/u/himmel.jpg',
            'lastOnline': '2 hours ago',
            'friendsSince': 'Mar 24, 2024',
          },
        ],
        'meta': {'cached': true},
      }));
      expect(friends.friends, hasLength(1));
      expect(friends.friends.first.username, 'Himmel');
      expect(friends.friends.first.imageUrl, 'https://cdn.myanimelist.net/u/himmel.jpg');
      expect(friends.friends.first.lastOnline, '2 hours ago');
      expect(friends.friends.first.friendsSince, 'Mar 24, 2024');
    });
  });

  group('openInBrowser bypasses internalLinkHandler', () {
    tearDown(WebLauncher.reset);

    testWidgets('launches externally without invoking DeepLinks internalLinkHandler', (tester) async {
      var internalCalled = false;
      Uri? openedUri;
      bool? openedExternal;
      WebLauncher.internalLinkHandler = (context, link) async {
        internalCalled = true;
        return true;
      };
      WebLauncher.opener = (uri, {barColor, onBarColor, external = false}) async {
        openedUri = uri;
        openedExternal = external;
        return true;
      };

      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      ));

      final ok = await openInBrowser(ctx, 'https://myanimelist.net/profile/dmytro');
      expect(ok, isTrue);
      expect(internalCalled, isFalse);
      expect(openedUri, Uri.parse('https://myanimelist.net/profile/dmytro'));
      expect(openedExternal, isTrue);
    });
  });
}
